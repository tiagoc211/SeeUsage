import Foundation
import XCTest
@testable import SeeUsage

final class AntigravityParsingTests: XCTestCase {
    let profileID = UUID()

    func testRealOutputParsing() {
        let output = """
        Gemini Models\tWeekly Limit Remaining\t84%\t2026-09-14T02:47:01Z
        Gemini Models\tFive Hour Limit Remaining\t63%\t2026-09-09T04:48:04Z
        Claude and GPT models\tWeekly Limit Remaining\t100%\t2026-09-16T02:40:16Z
        Claude and GPT models\tFive Hour Limit Remaining\t100%\t2026-09-09T07:40:16Z
        """
        let snapshot = AntigravityClient.parse(output: output, profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.windows.count, 4)

        // Gemini 5h should be first because 5h duration < weekly duration
        let gemini5h = snapshot.windows.first { $0.scope == "Gemini" && $0.label == "5 h" }
        XCTAssertNotNil(gemini5h)
        XCTAssertEqual(gemini5h?.remainingPercent, 63.0)
        XCTAssertNotNil(gemini5h?.resetsAt)

        let geminiWeekly = snapshot.windows.first { $0.scope == "Gemini" && $0.label == "7 dias" }
        XCTAssertNotNil(geminiWeekly)
        XCTAssertEqual(geminiWeekly?.remainingPercent, 84.0)

        let claudeWeekly = snapshot.windows.first { $0.scope == "Claude and GPT" && $0.label == "7 dias" }
        XCTAssertNotNil(claudeWeekly)
        XCTAssertEqual(claudeWeekly?.remainingPercent, 100.0)
    }

    func testUnknownScopeAndWhitespace() {
        let output = """
        \t\n
          CustomAgent Models \t  Weekly Limit Remaining  \t  45%  \t  2026-09-15T12:00:00Z  
        """
        let snapshot = AntigravityClient.parse(output: output, profileID: profileID)

        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].scope, "CustomAgent")
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 45.0)
    }

    func testInvalidFormat() {
        let output = "Total gibberish that has no tabs or structure"
        let snapshot = AntigravityClient.parse(output: output, profileID: profileID)

        XCTAssertNotNil(snapshot.error)
        XCTAssertTrue(snapshot.windows.isEmpty)
    }
}
