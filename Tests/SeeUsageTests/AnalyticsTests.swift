import XCTest
import Foundation
@testable import SeeUsage

@MainActor
final class AnalyticsTests: XCTestCase {
    func testAnalyticsDataStructures() {
        let now = Date()
        let pID = UUID()

        let record = QuotaSampleRecord(
            timestamp: now,
            profileID: pID,
            profileName: "Personal",
            service: "Codex",
            scope: nil,
            windowLabel: "5 h",
            remainingPercent: 75.0,
            resetsAt: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(record.usedPercent, 25.0)
        XCTAssertEqual(record.profileName, "Personal")
        XCTAssertEqual(record.service, "Codex")
        XCTAssertEqual(record.windowLabel, "5 h")

        let snapshot = QuotaHistorySnapshot(timestamp: now, records: [record])
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(snapshot.records.first?.remainingPercent, 75.0)
    }

    func testAnalyticsManagerComputations() {
        let manager = AnalyticsManager.shared
        manager.clearHistory()
        XCTAssertEqual(manager.snapshots.count, 0)

        // Seed demo data
        manager.seedDemoDataIfEmpty()
        XCTAssertTrue(manager.snapshots.count > 0)

        // Compute metrics
        let metrics = manager.computeMetrics(days: 7)
        XCTAssertTrue(metrics.totalConsumption7Days >= 0.0)
        XCTAssertTrue(metrics.totalSamplesCount > 0)

        // Hourly consumption
        let hourly = manager.computeHourlyConsumption(days: 7)
        XCTAssertEqual(hourly.count, 24)

        // Daily consumption
        let daily = manager.computeDailyConsumption(days: 7)
        XCTAssertTrue(daily.count >= 0)

        // Profile summaries
        let profiles = manager.computeProfileSummaries(days: 7)
        XCTAssertTrue(profiles.count >= 0)

        // CSV & JSON export
        let csv = manager.exportCSV()
        XCTAssertTrue(csv.contains("Timestamp,Profile,Service,Scope,Window,RemainingPercent,ResetsAt"))

        let json = manager.exportJSON()
        XCTAssertTrue(json.contains("remainingPercent"))
    }

    func testCLIAnalyticsCommands() async {
        let handledGeneral = await CLIHandler.handle(arguments: ["seeusage", "analytics"])
        XCTAssertTrue(handledGeneral)

        let handledCSV = await CLIHandler.handle(arguments: ["seeusage", "analytics", "csv"])
        XCTAssertTrue(handledCSV)

        let handledJSON = await CLIHandler.handle(arguments: ["seeusage", "analytics", "json"])
        XCTAssertTrue(handledJSON)

        let handledClear = await CLIHandler.handle(arguments: ["seeusage", "analytics", "clear"])
        XCTAssertTrue(handledClear)
        XCTAssertEqual(AnalyticsManager.shared.snapshots.count, 0)

        let handledHistoryAlias = await CLIHandler.handle(arguments: ["seeusage", "history"])
        XCTAssertTrue(handledHistoryAlias)
    }
}
