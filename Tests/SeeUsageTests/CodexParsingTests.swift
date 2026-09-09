import Foundation
import XCTest
@testable import SeeUsage

final class CodexParsingTests: XCTestCase {
    let profileID = UUID()

    func testCodexRateLimitsWithTwoWindows() {
        let json = """
        {"method":"remoteControl/status/changed","params":{"status":"disabled"}}
        {"id":2,"result":{"rateLimits":{"planType":"plus","primary":{"usedPercent":23,"windowDurationMins":300,"resetsAt":1788939204},"secondary":{"usedPercent":38,"windowDurationMins":10080,"resetsAt":1789463786}}}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.plan, "Plus")
        XCTAssertEqual(snapshot.windows.count, 2)

        let w1 = snapshot.windows[0]
        XCTAssertEqual(w1.label, "5 h")
        XCTAssertEqual(w1.remainingPercent, 77.0) // usedPercent = 23 -> remaining = 77
        XCTAssertEqual(w1.durationMinutes, 300)
        XCTAssertNotNil(w1.resetsAt)

        let w2 = snapshot.windows[1]
        XCTAssertEqual(w2.label, "7 dias")
        XCTAssertEqual(w2.remainingPercent, 62.0)
        XCTAssertEqual(w2.durationMinutes, 10080)
    }

    func testCodexRateLimitsByLimitId() {
        let json = """
        {"id":2,"result":{"rateLimitsByLimitId":{"codex":{"planType":"pro","primary":{"usedPercent":10,"windowDurationMins":300,"resetsAt":1788939204}}}}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.plan, "Pro")
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 90.0)
    }

    func testCodexSingleWindowAndUnknownDuration() {
        let json = """
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":15,"windowDurationMins":120}}}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertNil(snapshot.plan)
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].label, "2 h")
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 85.0)
        XCTAssertNil(snapshot.windows[0].resetsAt)
    }

    func testCodexPercentageClamp() {
        let json = """
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":120,"windowDurationMins":300},"secondary":{"usedPercent":-10,"windowDurationMins":10080}}}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 0.0)
        XCTAssertEqual(snapshot.windows[1].remainingPercent, 100.0)
    }

    func testCodexNotificationsBeforeResponse() {
        let json = """
        {"method":"remoteControl/status/changed","params":{"status":"disabled"}}
        {"method":"config/reload","params":{}}
        {"id":1,"result":{"status":"ok"}}
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":23,"windowDurationMins":300}}}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 77.0)
    }

    func testCodexJsonRpcError() {
        let json = """
        {"id":2,"error":{"code":-32600,"message":"Unauthorized or token expired."}}
        """
        let snapshot = CodexClient.parse(output: Data(json.utf8), profileID: profileID)

        XCTAssertNotNil(snapshot.error)
        XCTAssertTrue(snapshot.error?.contains("Unauthorized") == true)
        XCTAssertTrue(snapshot.windows.isEmpty)
    }

    func testCodexFormatDuration() {
        XCTAssertEqual(CodexClient.formatDuration(minutes: 60), "1 h")
        XCTAssertEqual(CodexClient.formatDuration(minutes: 300), "5 h")
        XCTAssertEqual(CodexClient.formatDuration(minutes: 1440), "24 h")
        XCTAssertEqual(CodexClient.formatDuration(minutes: 10080), "7 dias")
        XCTAssertEqual(CodexClient.formatDuration(minutes: 20160), "2 dias")
        XCTAssertEqual(CodexClient.formatDuration(minutes: 45), "45 min")
    }
}
