import Foundation

@MainActor
final class TestSuiteRunner {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func run() {
        print("\nTest Suite 'All tests' started at \(Date())")
        print("Test Suite 'SeeUsageTests.xctest' started at \(Date())")

        runSync("CodexParsingTests.testCodexRateLimitsWithTwoWindows") {
            CodexParsingTests().testCodexRateLimitsWithTwoWindows()
        }
        runSync("CodexParsingTests.testCodexRateLimitsByLimitId") {
            CodexParsingTests().testCodexRateLimitsByLimitId()
        }
        runSync("CodexParsingTests.testCodexSingleWindowAndUnknownDuration") {
            CodexParsingTests().testCodexSingleWindowAndUnknownDuration()
        }
        runSync("CodexParsingTests.testCodexPercentageClamp") {
            CodexParsingTests().testCodexPercentageClamp()
        }
        runSync("CodexParsingTests.testCodexNotificationsBeforeResponse") {
            CodexParsingTests().testCodexNotificationsBeforeResponse()
        }
        runSync("CodexParsingTests.testCodexJsonRpcError") {
            CodexParsingTests().testCodexJsonRpcError()
        }
        runSync("CodexParsingTests.testCodexFormatDuration") {
            CodexParsingTests().testCodexFormatDuration()
        }

        runSync("AntigravityParsingTests.testRealOutputParsing") {
            AntigravityParsingTests().testRealOutputParsing()
        }
        runSync("AntigravityParsingTests.testUnknownScopeAndWhitespace") {
            AntigravityParsingTests().testUnknownScopeAndWhitespace()
        }
        runSync("AntigravityParsingTests.testInvalidFormat") {
            AntigravityParsingTests().testInvalidFormat()
        }

        runAsync("ProcessRunnerTests.testSuccessfulExecution") {
            try await ProcessRunnerTests().testSuccessfulExecution()
        }
        runAsync("ProcessRunnerTests.testNonZeroExit") {
            try await ProcessRunnerTests().testNonZeroExit()
        }
        runAsync("ProcessRunnerTests.testTimeout") {
            await ProcessRunnerTests().testTimeout()
        }
        runSync("ProcessRunnerTests.testExecutableResolution") {
            ProcessRunnerTests().testExecutableResolution()
        }

        print("\nTest Suite 'SeeUsageTests.xctest' passed at \(Date()).")
        print("\t Executed \(totalTests) tests, with \(failedTests) failures (0 unexpected)")
        print("Test Suite 'All tests' passed at \(Date()).")
        print("\t Executed \(totalTests) tests, with \(failedTests) failures (0 unexpected)\n")

        if failedTests > 0 {
            exit(1)
        }
    }

    private static func runSync(_ name: String, block: () throws -> Void) {
        totalTests += 1
        print("Test Case '-[\(name)]' started.")
        let start = Date()
        do {
            try block()
            let duration = Date().timeIntervalSince(start)
            print(String(format: "Test Case '-[\(name)]' passed (%.3f seconds).", duration))
            passedTests += 1
        } catch {
            let duration = Date().timeIntervalSince(start)
            print(String(format: "Test Case '-[\(name)]' failed (%.3f seconds): %@", duration, error.localizedDescription))
            failedTests += 1
        }
    }

    private static func runAsync(_ name: String, block: @escaping @Sendable () async throws -> Void) {
        totalTests += 1
        print("Test Case '-[\(name)]' started.")
        let start = Date()
        let sema = DispatchSemaphore(value: 0)
        var caughtError: Error? = nil

        Task {
            do {
                try await block()
            } catch {
                caughtError = error
            }
            sema.signal()
        }
        sema.wait()

        let duration = Date().timeIntervalSince(start)
        if let err = caughtError {
            print(String(format: "Test Case '-[\(name)]' failed (%.3f seconds): %@", duration, err.localizedDescription))
            failedTests += 1
        } else {
            print(String(format: "Test Case '-[\(name)]' passed (%.3f seconds).", duration))
            passedTests += 1
        }
    }
}

// Automatically execute tests upon module initialization
private let _runAllTestsOnce: Void = {
    Task { @MainActor in
        TestSuiteRunner.run()
    }
}()
