import XCTest
@testable import SeeUsage

final class ProcessRunnerTests: XCTestCase {
    func testSuccessfulExecution() async throws {
        let result = try await ProcessRunner.run(
            executable: "/bin/echo",
            arguments: ["hello world"],
            timeout: 5
        )
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.outputString.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    func testNonZeroExit() async throws {
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/false",
            arguments: [],
            timeout: 5
        )
        XCTAssertNotEqual(result.terminationStatus, 0)
    }

    func testTimeout() async {
        do {
            _ = try await ProcessRunner.run(
                executable: "/bin/sleep",
                arguments: ["5"],
                timeout: 0.5
            )
            XCTFail("Should have timed out")
        } catch let error as ProcessRunnerError {
            if case .timedOut = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecutableResolution() {
        let echoPath = ProcessRunner.resolveExecutable(named: "echo")
        XCTAssertNotNil(echoPath)
        XCTAssertTrue(echoPath?.hasSuffix("/echo") == true)
    }
}
