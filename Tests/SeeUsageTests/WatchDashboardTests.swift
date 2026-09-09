import XCTest
import Foundation
@testable import SeeUsage

@MainActor
final class WatchDashboardTests: XCTestCase {
    func testCountdownFormatting() {
        let now = Date()

        // Nil date
        XCTAssertEqual(WatchDashboard.countdownString(until: nil), "--:--:--")

        // Past date
        let past = now.addingTimeInterval(-10)
        XCTAssertEqual(WatchDashboard.countdownString(until: past), "ready")

        // Future within same day: 2 hours, 15 minutes, 30 seconds
        let secondsShort: TimeInterval = 2 * 3600 + 15 * 60 + 30
        let futureShort = now.addingTimeInterval(secondsShort)
        let formattedShort = WatchDashboard.countdownString(until: futureShort)
        XCTAssertTrue(formattedShort.contains("02:15:") || formattedShort.contains("02:14:"))

        // Future multiple days: 3 days, 4 hours, 20 minutes
        let secondsLong: TimeInterval = 3 * 86400 + 4 * 3600 + 20 * 60 + 10
        let futureLong = now.addingTimeInterval(secondsLong)
        let formattedLong = WatchDashboard.countdownString(until: futureLong)
        XCTAssertTrue(formattedLong.hasPrefix("3d 04:20:") || formattedLong.hasPrefix("3d 04:19:"))
    }

    func testProgressBarRendering() {
        let full = WatchDashboard.progressBar(percent: 100.0, width: 10)
        XCTAssertEqual(full, "[██████████]")

        let empty = WatchDashboard.progressBar(percent: 0.0, width: 10)
        XCTAssertEqual(empty, "[░░░░░░░░░░]")

        let half = WatchDashboard.progressBar(percent: 50.0, width: 10)
        XCTAssertEqual(half, "[█████░░░░░]")

        let nilBar = WatchDashboard.progressBar(percent: nil, width: 10)
        XCTAssertEqual(nilBar, "[░░░░░░░░░░]")
    }

    func testQuotaColorAnsi() {
        let redColor = WatchDashboard.quotaColorAnsi(for: 10.0)
        XCTAssertTrue(redColor.contains("245;71;82"))

        let amberColor = WatchDashboard.quotaColorAnsi(for: 25.0)
        XCTAssertTrue(amberColor.contains("250;158;46"))

        let greenColor = WatchDashboard.quotaColorAnsi(for: 80.0)
        XCTAssertTrue(greenColor.contains("0;229;153"))

        let nilColor = WatchDashboard.quotaColorAnsi(for: nil)
        XCTAssertTrue(nilColor.contains("90m"))
    }

    func testStripAnsi() {
        let colored = "\u{001B}[31mHello\u{001B}[0m \u{001B}[1mWorld\u{001B}[0m"
        let stripped = WatchDashboard.stripAnsi(colored)
        XCTAssertEqual(stripped, "Hello World")
    }

    func testRenderFrame() {
        let frame = WatchDashboard.renderFrame(
            store: UsageStore.shared,
            settings: SettingsStore.shared,
            isRefreshing: false,
            notice: "Testing notice"
        )
        XCTAssertTrue(frame.contains("SEEUSAGE WATCH"))
        XCTAssertTrue(frame.contains("HOTKEYS"))
        XCTAssertTrue(frame.contains("Testing notice"))
    }
}
