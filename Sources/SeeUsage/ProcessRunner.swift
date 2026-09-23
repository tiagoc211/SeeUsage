import Foundation
import Darwin

public struct ProcessResult: Sendable {
    public let standardOutput: Data
    public let standardError: Data
    public let terminationStatus: Int32

    public var outputString: String {
        String(decoding: standardOutput, as: UTF8.self)
    }

    public var errorString: String {
        String(decoding: standardError, as: UTF8.self)
    }
}

public enum ProcessRunnerError: LocalizedError, Sendable {
    case executableNotFound(String)
    case timedOut(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "\(name) CLI not found."
        case .timedOut:
            return "Operation timed out."
        case .launchFailed(let name):
            return "Failed to launch \(name)."
        }
    }
}

public enum ProcessRunner {
    public static func defaultEnvironment(suppressColor: Bool = true) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let standardPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.local/bin",
            "\(home)/bin",
            "/opt/anaconda3/bin",
            "/opt/anaconda3/condabin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "\(home)/.bun/bin",
            "\(home)/.volta/bin",
            "\(home)/.cargo/bin"
        ]

        var currentPaths = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        for p in standardPaths {
            if !currentPaths.contains(p) {
                currentPaths.append(p)
            }
        }

        env["PATH"] = currentPaths.joined(separator: ":")
        env["HOME"] = home
        if suppressColor { env["NO_COLOR"] = "1" }
        return env
    }

    public static func resolveExecutable(named name: String, overridePath: String? = nil) -> String? {
        let fm = FileManager.default
        if let override = overridePath?.trimmingCharacters(in: .whitespaces), !override.isEmpty {
            let expanded = (override as NSString).expandingTildeInPath
            if fm.isExecutableFile(atPath: expanded) {
                return expanded
            }
            if override.contains("/") {
                return nil
            }
            return findInKnownPaths(named: override)
        }

        return findInKnownPaths(named: name)
    }

    private static func findInKnownPaths(named name: String) -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var candidates: [String] = []

        let env = defaultEnvironment()
        if let pathEnv = env["PATH"] {
            for dir in pathEnv.split(separator: ":").map(String.init) {
                candidates.append("\(dir)/\(name)")
            }
        }

        let knownDirs = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "/usr/bin",
            "/bin",
            "\(home)/.bun/bin",
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "\(home)/.local/share/mise/shims"
        ]

        for dir in knownDirs {
            candidates.append("\(dir)/\(name)")
        }

        for candidate in candidates {
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    public static func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        input: Data? = nil,
        timeout: TimeInterval = 15,
        completionResponseID: Int? = nil,
        suppressColor: Bool = true
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            try runSynchronous(
                executable: executable,
                arguments: arguments,
                environment: environment,
                input: input,
                timeout: timeout,
                completionResponseID: completionResponseID,
                suppressColor: suppressColor
            )
        }.value
    }

    private static func runSynchronous(
        executable: String,
        arguments: [String],
        environment: [String: String],
        input: Data?,
        timeout: TimeInterval,
        completionResponseID: Int?,
        suppressColor: Bool
    ) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        let semaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        var env = defaultEnvironment(suppressColor: suppressColor)
        environment.forEach { env[$0.key] = $0.value }
        process.environment = env

        let stdoutData = ThreadSafeData()
        let stderrData = ThreadSafeData()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            let completed = stdoutData.append(chunk, lookingForJSONRPCID: completionResponseID)
            if completed {
                try? stdinPipe.fileHandleForWriting.close()
                process.terminate()
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            stderrData.append(chunk)
        }

        process.terminationHandler = { _ in
            semaphore.signal()
        }

        let deadline = DispatchTime.now() + timeout
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            try? stdinPipe.fileHandleForWriting.close()
            throw ProcessRunnerError.launchFailed(executable)
        }

        if let inputData = input {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
            if completionResponseID == nil {
                try? stdinPipe.fileHandleForWriting.close()
            }
        } else {
            try? stdinPipe.fileHandleForWriting.close()
        }

        let waitResult = semaphore.wait(timeout: deadline)

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if waitResult == .timedOut {
            let receivedExpectedResponse = completionResponseID.map { _ in stdoutData.hasFoundJSONRPCResponse } ?? false
            if process.isRunning {
                process.terminate()
            }
            if semaphore.wait(timeout: .now() + .milliseconds(300)) == .timedOut {
                if process.isRunning {
                    _ = kill(process.processIdentifier, SIGKILL)
                }
                semaphore.wait()
            }
            guard receivedExpectedResponse else {
                throw ProcessRunnerError.timedOut(executable)
            }
        }

        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutData.append(remainingStdout)

        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stderrData.append(remainingStderr)

        return ProcessResult(
            standardOutput: stdoutData.get(),
            standardError: stderrData.get(),
            terminationStatus: process.terminationStatus
        )
    }
}

private final class ThreadSafeData: @unchecked Sendable {
    private var data = Data()
    private var lineBuffer = Data()
    private var foundJSONRPCResponse = false
    private let lock = NSLock()

    func append(_ newChunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newChunk)
    }

    func append(_ newChunk: Data, lookingForJSONRPCID expectedID: Int?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        data.append(newChunk)
        guard let expectedID else { return false }

        lineBuffer.append(newChunk)
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer.prefix(upTo: newline)
            lineBuffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let id = object["id"] as? NSNumber,
                  id.intValue == expectedID
            else { continue }
            foundJSONRPCResponse = true
            return true
        }
        return false
    }

    var hasFoundJSONRPCResponse: Bool {
        lock.lock()
        defer { lock.unlock() }
        return foundJSONRPCResponse
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
