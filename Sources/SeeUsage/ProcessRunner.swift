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
    public static func defaultEnvironment() -> [String: String] {
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
        env["NO_COLOR"] = "1"
        return env
    }

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

        var env = defaultEnvironment()
        environment.forEach { env[$0.key] = $0.value }
        process.environment = env

        let stdoutData = ThreadSafeData()
        let stderrData = ThreadSafeData()

        var markerFound = false
        let markerLock = NSLock()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            stdoutData.append(chunk)

            if let marker = completionMarker {
                markerLock.lock()
                defer { markerLock.unlock() }
                if !markerFound {
                    let text = String(decoding: stdoutData.get(), as: UTF8.self)
                    if text.contains(marker) {
                        markerFound = true
                        try? stdinPipe.fileHandleForWriting.close()
                    }
                }
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

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(executable)
        }

        if let inputData = input {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
            if completionMarker == nil {
                try? stdinPipe.fileHandleForWriting.close()
            }
        } else {
            try? stdinPipe.fileHandleForWriting.close()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if waitResult == .timedOut {
            process.terminate()
            throw ProcessRunnerError.timedOut(executable)
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
    private let lock = NSLock()

    func append(_ newChunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newChunk)
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
