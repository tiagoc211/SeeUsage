import Foundation

public enum AntigravityClient {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static func fetch(
        profileID: UUID,
        executable: String,
        timeout: TimeInterval = 35
    ) async -> UsageSnapshot {
        do {
            let result = try await ProcessRunner.run(
                executable: executable,
                arguments: ["-p", "/usage", "--output-format", "text", "--print-timeout", "30s"],
                timeout: timeout
            )

            guard result.terminationStatus == 0 else {
                let err = result.errorString
                if err.localizedCaseInsensitiveContains("auth") || err.localizedCaseInsensitiveContains("sign in") || err.localizedCaseInsensitiveContains("login") {
                    return UsageSnapshot(profileID: profileID, error: "Inicia sessão no Antigravity CLI.")
                }
                return UsageSnapshot(profileID: profileID, error: "Inicia sessão no Antigravity CLI.")
            }

            return parse(output: result.outputString, profileID: profileID)
        } catch {
            return UsageSnapshot(profileID: profileID, error: error.localizedDescription)
        }
    }

    public static func parse(output: String, profileID: UUID) -> UsageSnapshot {
        let lines = output.components(separatedBy: .newlines)
        var windows: [UsageWindow] = []

        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 4 else { continue }

            let rawScope = parts[0].trimmingCharacters(in: .whitespaces)
            guard !rawScope.isEmpty else { continue }

            let scope = rawScope
                .replacingOccurrences(of: " Models", with: "")
                .replacingOccurrences(of: " models", with: "")
                .replacingOccurrences(of: " Models", with: "")

            let rawLabel = parts[1].trimmingCharacters(in: .whitespaces)
            let lowerLabel = rawLabel.lowercased()

            let label: String
            let duration: Int?
            if lowerLabel.contains("five hour") || lowerLabel.contains("5 hour") || lowerLabel.contains("5-hour") {
                label = "5 h"
                duration = 300
            } else if lowerLabel.contains("weekly") {
                label = "7 dias"
                duration = 10080
            } else {
                label = rawLabel
                duration = nil
            }

            let percentString = parts[2].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "%", with: "")
            guard let percent = Double(percentString) else { continue }
            let clampedRemaining = max(0.0, min(100.0, percent))

            let dateString = parts[3].trimmingCharacters(in: .whitespaces)
            let resetDate = parseDate(dateString)

            let windowId = "agy-\(scope.lowercased().replacingOccurrences(of: " ", with: "-"))-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))"

            windows.append(UsageWindow(
                id: windowId,
                label: label,
                remainingPercent: clampedRemaining,
                durationMinutes: duration,
                resetsAt: resetDate,
                scope: scope
            ))
        }

        if windows.isEmpty {
            return UsageSnapshot(
                profileID: profileID,
                error: "Não foi possível interpretar a usage do Antigravity."
            )
        }

        // Sort windows: Gemini first, Claude/GPT second; 5h before 7 dias
        windows.sort { lhs, rhs in
            let lScope = lhs.scope ?? ""
            let rScope = rhs.scope ?? ""
            if lScope != rScope {
                if lScope.contains("Gemini") { return true }
                if rScope.contains("Gemini") { return false }
                return lScope < rScope
            }
            return (lhs.durationMinutes ?? 0) < (rhs.durationMinutes ?? 0)
        }

        return UsageSnapshot(
            profileID: profileID,
            windows: windows,
            fetchedAt: Date(),
            error: nil
        )
    }

    private static func parseDate(_ string: String) -> Date? {
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        return iso8601FractionalFormatter.date(from: string)
    }
}
