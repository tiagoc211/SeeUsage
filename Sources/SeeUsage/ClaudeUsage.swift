import Foundation

public struct ClaudeUsageSnapshot: Codable, Equatable, Sendable {
    public let updatedAt: Date
    public let windows: [UsageWindow]

    public init(updatedAt: Date = Date(), windows: [UsageWindow]) {
        self.updatedAt = updatedAt
        self.windows = windows
    }
}

@MainActor
public enum ClaudeStatusLineIntegration {
    private struct IntegrationState: Codable {
        let command: String
        let originalStatusLine: Data?
    }

    public enum IntegrationError: LocalizedError {
        case invalidSettings
        case invalidStatusLine
        case executableUnavailable
        case statusLineChanged

        public var errorDescription: String? {
            switch self {
            case .invalidSettings: return "Claude settings could not be read, so SeeUsage left them unchanged."
            case .invalidStatusLine: return "Claude's existing status line could not be preserved."
            case .executableUnavailable: return "The SeeUsage app executable could not be found."
            case .statusLineChanged: return "Claude's status line changed. SeeUsage left it unchanged."
            }
        }
    }

    public static var cacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/seeusage/claude-usage.json")
    }

    private static var settingsURL: URL {
        let environment = ProcessInfo.processInfo.environment
        let configPath = environment["CLAUDE_CONFIG_DIR"]
            .flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        return URL(fileURLWithPath: configPath, isDirectory: true).appendingPathComponent("settings.json")
    }

    private static var stateURL: URL {
        settingsURL.deletingLastPathComponent().appendingPathComponent(".seeusage-statusline.json")
    }

    public static func isEnabled() -> Bool {
        guard let state = try? readState(),
              let settings = try? readSettings(),
              let statusLine = settings["statusLine"] as? [String: Any]
        else { return false }
        return statusLine["command"] as? String == state.command
    }

    public static func enable() throws {
        var settings = try readSettings(allowMissing: true)
        if FileManager.default.fileExists(atPath: stateURL.path) {
            guard isEnabled() else { throw IntegrationError.statusLineChanged }
            return
        }

        let originalStatusLine = settings["statusLine"]
        let originalData: Data?
        var statusLine: [String: Any]
        if let originalStatusLine {
            guard let original = originalStatusLine as? [String: Any],
                  original["command"] is String,
                  JSONSerialization.isValidJSONObject(original)
            else { throw IntegrationError.invalidStatusLine }
            statusLine = original
            originalData = try JSONSerialization.data(withJSONObject: original)
        } else {
            statusLine = [:]
            originalData = nil
        }

        guard let executable = Bundle.main.executableURL?.path
                ?? ProcessInfo.processInfo.arguments.first
        else { throw IntegrationError.executableUnavailable }

        let command = "\(shellQuote(executable)) claude-statusline"
        statusLine["type"] = "command"
        statusLine["command"] = command
        settings["statusLine"] = statusLine

        let state = IntegrationState(command: command, originalStatusLine: originalData)
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        do {
            try encoder.encode(state).write(to: stateURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
            try writeSettings(settings)
        } catch {
            try? FileManager.default.removeItem(at: stateURL)
            throw error
        }
    }

    public static func disable() throws {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        let state = try readState()
        var settings = try readSettings()
        guard let statusLine = settings["statusLine"] as? [String: Any],
              statusLine["command"] as? String == state.command
        else {
            try? FileManager.default.removeItem(at: stateURL)
            clearCachedUsage()
            throw IntegrationError.statusLineChanged
        }

        if let originalData = state.originalStatusLine {
            settings["statusLine"] = try JSONSerialization.jsonObject(
                with: originalData,
                options: [.fragmentsAllowed]
            )
        } else {
            settings.removeValue(forKey: "statusLine")
        }
        try writeSettings(settings)
        try FileManager.default.removeItem(at: stateURL)
        clearCachedUsage()
    }

    private static func clearCachedUsage() {
        SharedFileLock.withExclusiveLock(for: cacheURL) {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("app.seeusage.claudeUsageChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func loadCachedUsage() -> ClaudeUsageSnapshot? {
        let data = SharedFileLock.withExclusiveLock(for: cacheURL) {
            try? Data(contentsOf: cacheURL)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data, let snapshot = try? decoder.decode(ClaudeUsageSnapshot.self, from: data) else {
            return nil
        }
        let currentWindows = snapshot.windows.filter { ($0.resetsAt ?? .distantFuture) > Date() }
        guard !currentWindows.isEmpty else { return nil }
        return ClaudeUsageSnapshot(updatedAt: snapshot.updatedAt, windows: currentWindows)
    }

    public static func capture(_ input: Data) async {
        guard isEnabled() else {
            await forwardExistingStatusLine(input)
            return
        }

        guard let payload = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else {
            await forwardExistingStatusLine(input)
            return
        }
        guard let limits = payload["rate_limits"] as? [String: Any] else {
            if payload["session_id"] != nil { clearCachedUsage() }
            await forwardExistingStatusLine(input)
            return
        }

        let windows = [
            makeWindow(limits["five_hour"], id: "claude-5h", label: "5 hours", duration: 300),
            makeWindow(limits["seven_day"], id: "claude-7d", label: "7 days", duration: 10_080)
        ].compactMap { $0 }

        if windows.isEmpty {
            clearCachedUsage()
        } else {
            let snapshot = ClaudeUsageSnapshot(windows: windows)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            SharedFileLock.withExclusiveLock(for: cacheURL) {
                try? FileManager.default.createDirectory(
                    at: cacheURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if let data = try? encoder.encode(snapshot) {
                    try? data.write(to: cacheURL, options: .atomic)
                }
            }
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.claudeUsageChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }

        await forwardExistingStatusLine(input)
    }

    private static func makeWindow(
        _ rawValue: Any?,
        id: String,
        label: String,
        duration: Int
    ) -> UsageWindow? {
        guard let value = rawValue as? [String: Any],
              let used = value["used_percentage"] as? NSNumber,
              let reset = value["resets_at"] as? NSNumber,
              used.doubleValue.isFinite,
              reset.doubleValue.isFinite
        else { return nil }
        let resetsAt = Date(timeIntervalSince1970: reset.doubleValue)
        guard resetsAt > Date() else { return nil }
        return UsageWindow(
            id: id,
            label: label,
            remainingPercent: 100 - min(100, max(0, used.doubleValue)),
            durationMinutes: duration,
            resetsAt: resetsAt
        )
    }

    private static func forwardExistingStatusLine(_ input: Data) async {
        let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap {
            FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil
        } ?? "/bin/sh"
        guard let state = try? readState(),
              let originalData = state.originalStatusLine,
              let original = try? JSONSerialization.jsonObject(with: originalData) as? [String: Any],
              let command = original["command"] as? String
        else { return }
        guard let output = try? await ProcessRunner.run(
            executable: shell,
            arguments: ["-c", command],
            input: input,
            timeout: 3,
            suppressColor: false
        ) else { return }
        try? FileHandle.standardOutput.write(contentsOf: output.standardOutput)
    }

    private static func readSettings(allowMissing: Bool = false) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            if allowMissing { return [:] }
            throw IntegrationError.invalidSettings
        }
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw IntegrationError.invalidSettings }
        return settings
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func readState() throws -> IntegrationState {
        let data = try Data(contentsOf: stateURL)
        return try JSONDecoder().decode(IntegrationState.self, from: data)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
