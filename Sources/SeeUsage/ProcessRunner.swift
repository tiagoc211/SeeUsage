import Foundation

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
            return "\(name) CLI não encontrado."
        case .timedOut:
            return "Tempo limite excedido."
        case .launchFailed(let name):
            return "Falha ao iniciar \(name)."
        }
    }
}

public enum ProcessRunner {
    public static func resolveExecutable(named name: String, overridePath: String? = nil) -> String? {
        let fm = FileManager.default
        if let override = overridePath, !override.trimmingCharacters(in: .whitespaces).isEmpty {
            let expanded = (override as NSString).expandingTildeInPath
            if fm.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        let home = fm.homeDirectoryForCurrentUser.path
        var candidates: [String] = []

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
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
        completionMarker: String? = nil
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            try runSynchronous(
                executable: executable,
                arguments: arguments,
                environment: environment,
                input: input,
                timeout: timeout,
                completionMarker: completionMarker
            )
        }.value
    }

    private static func runSynchronous(
        executable: String,
        arguments: [String],
        environment: [String: String],
        input: Data?,
        timeout: TimeInterval,
        completionMarker: String?
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

        var env = ProcessInfo.processInfo.environment
        environment.forEach { env[$0.key] = $0.value }
        env["NO_COLOR"] = "1"
        process.environment = env

        let stdoutStorage = OutputBuffer(marker: completionMarker)
        let stderrStorage = OutputBuffer(marker: nil)

        process.terminationHandler = { _ in
            semaphore.signal()
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            if stdoutStorage.append(chunk) {
                // Marker found, close stdin to signal EOF and terminate process gracefully
                try? stdinPipe.fileHandleForWriting.close()
                if process.isRunning {
                    process.terminate()
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            _ = stderrStorage.append(chunk)
        }

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(URL(fileURLWithPath: executable).lastPathComponent)
        }

        if let input = input {
            stdinPipe.fileHandleForWriting.write(input)
        }
        if completionMarker == nil {
            try? stdinPipe.fileHandleForWriting.close()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if waitResult == .timedOut {
            if process.isRunning {
                process.terminate()
                _ = semaphore.wait(timeout: .now() + 1)
            }
            throw ProcessRunnerError.timedOut(URL(fileURLWithPath: executable).lastPathComponent)
        }

        _ = stdoutStorage.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        _ = stderrStorage.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        return ProcessResult(
            standardOutput: stdoutStorage.data,
            standardError: stderrStorage.data,
            terminationStatus: process.terminationStatus
        )
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let marker: Data?
    private var buffer = Data()
    private var markerFound = false

    init(marker: String?) {
        self.marker = marker.flatMap { $0.data(using: .utf8) }
    }

    var data: Data {
        lock.withLock { buffer }
    }

    func append(_ chunk: Data) -> Bool {
        lock.withLock {
            buffer.append(chunk)
            guard !markerFound, let marker = marker, buffer.range(of: marker) != nil else {
                return false
            }
            markerFound = true
            return true
        }
    }
}
