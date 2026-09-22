import XCTest
import Foundation
@testable import SeeUsage

@MainActor
final class AnalyticsTests: XCTestCase {
    private func makeAnalyticsManager() -> AnalyticsManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeeUsageAnalyticsTests-\(UUID().uuidString)", isDirectory: true)
        return AnalyticsManager(storageDirectory: directory)
    }

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
        let manager = makeAnalyticsManager()
        manager.clearHistory()
        XCTAssertEqual(manager.snapshots.count, 0)

        let profileID = UUID()
        let resetAt = Date().addingTimeInterval(3600)
        manager.recordSnapshots([profileID: UsageSnapshot(profileID: profileID, windows: [
            UsageWindow(id: "test-window", label: "5 h", remainingPercent: 90, durationMinutes: 300, resetsAt: resetAt)
        ])])
        manager.recordSnapshots([profileID: UsageSnapshot(profileID: profileID, windows: [
            UsageWindow(id: "test-window", label: "5 h", remainingPercent: 80, durationMinutes: 300, resetsAt: resetAt)
        ])])
        XCTAssertEqual(manager.snapshots.count, 2)

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

        let handledHistoryAlias = await CLIHandler.handle(arguments: ["seeusage", "history"])
        XCTAssertTrue(handledHistoryAlias)
    }

    func testResetDataModels() {
        let now = Date()
        let pID = UUID()
        let nextReset = now.addingTimeInterval(18000)

        let event = ResetEvent(
            timestamp: now,
            profileID: pID,
            profileName: "Pessoal",
            service: "Codex",
            scope: nil,
            windowLabel: "5 h",
            durationMinutes: 300,
            quotaBefore: 12.0,
            quotaAfter: 100.0,
            quotaRestored: 88.0,
            nextResetAt: nextReset
        )

        XCTAssertEqual(event.profileName, "Pessoal")
        XCTAssertEqual(event.service, "Codex")
        XCTAssertEqual(event.windowLabel, "5 h")
        XCTAssertEqual(event.quotaBefore, 12.0)
        XCTAssertEqual(event.quotaAfter, 100.0)
        XCTAssertEqual(event.quotaRestored, 88.0)
        XCTAssertEqual(event.nextResetAt, nextReset)

        let upcoming = UpcomingResetInfo(
            profileID: pID,
            profileName: "Trabalho",
            service: "Codex",
            scope: nil,
            windowLabel: "7 days",
            durationMinutes: 10080,
            currentRemainingPercent: 65.0,
            resetsAt: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(upcoming.profileName, "Trabalho")
        XCTAssertEqual(upcoming.windowLabel, "7 days")
        XCTAssertEqual(upcoming.currentRemainingPercent, 65.0)
        XCTAssertFalse(upcoming.isExpired)
        XCTAssertTrue(upcoming.secondsUntilReset > 0)
    }

    func testResetDetectionAndPersistence() {
        let manager = makeAnalyticsManager()
        manager.clearResets()
        XCTAssertEqual(manager.resetEvents.count, 0)

        manager.recordResetEvent(ResetEvent(
            profileID: UUID(),
            profileName: "Test",
            service: "Codex",
            windowLabel: "5 h",
            durationMinutes: 300,
            quotaBefore: 15,
            quotaAfter: 100
        ))
        XCTAssertGreaterThan(manager.resetEvents.count, 0)

        let events = manager.getResetEvents(limit: 10)
        XCTAssertFalse(events.isEmpty)

        // CSV export
        let csv = manager.exportResetsCSV()
        XCTAssertTrue(csv.contains("Timestamp,Profile,Service,Scope,Window,QuotaBefore,QuotaAfter,QuotaRestored,NextResetAt"))
        XCTAssertTrue(csv.contains("Codex"))

        // JSON export
        let json = manager.exportResetsJSON()
        XCTAssertTrue(json.contains("quotaRestored"))

        // Clear resets
        manager.clearResets()
        XCTAssertEqual(manager.resetEvents.count, 0)
    }

    func testUpcomingResetsComputation() {
        let manager = makeAnalyticsManager()
        let pID = UUID()
        let now = Date()

        let win5h = UsageWindow(
            id: "5h",
            label: "5 h",
            remainingPercent: 80.0,
            durationMinutes: 300,
            resetsAt: now.addingTimeInterval(7200),
            scope: nil
        )

        let win7d = UsageWindow(
            id: "7d",
            label: "7 days",
            remainingPercent: 60.0,
            durationMinutes: 10080,
            resetsAt: now.addingTimeInterval(86400),
            scope: nil
        )

        let snap = UsageSnapshot(
            profileID: pID,
            plan: "Pro",
            windows: [win7d, win5h]
        )

        let upcoming = manager.computeUpcomingResets(from: [pID: snap])
        XCTAssertEqual(upcoming.count, 2)
        // Earliest resetsAt should come first
        XCTAssertEqual(upcoming.first?.windowLabel, "5 h")
        XCTAssertEqual(upcoming.last?.windowLabel, "7 days")
    }

    func testCLIResetsCommands() async {
        let handledRemovedSeed = await CLIHandler.handle(arguments: ["seeusage", "resets", "seed"])
        XCTAssertTrue(handledRemovedSeed)

        let handledCSV = await CLIHandler.handle(arguments: ["seeusage", "resets", "csv"])
        XCTAssertTrue(handledCSV)
    }
}
