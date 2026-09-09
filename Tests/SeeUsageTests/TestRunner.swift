import Foundation

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

        runAsync("CLIHandlerTests.testProfileAliasGeneration") {
            await MainActor.run {
                CLIHandlerTests().testProfileAliasGeneration()
            }
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
            print("Test Case '-[\(name)]' failed: \(error)")
            failedTests += 1
        }
    }

    private static func runAsync(_ name: String, block: @escaping () async throws -> Void) {
        totalTests += 1
        print("Test Case '-[\(name)]' started.")
        let start = Date()
        let sema = DispatchSemaphore(value: 0)
        var testError: Error?

        Task {
            do {
                try await block()
            } catch {
                testError = error
            }
            sema.signal()
        }

        sema.wait()
        let duration = Date().timeIntervalSince(start)
        if let err = testError {
            print("Test Case '-[\(name)]' failed: \(err)")
            failedTests += 1
        } else {
            print(String(format: "Test Case '-[\(name)]' passed (%.3f seconds).", duration))
            passedTests += 1
        }
    }
}
