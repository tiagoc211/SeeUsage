import XCTest
import Foundation
@testable import SeeUsage

@MainActor
final class NotificationTests: XCTestCase {
    func testNotificationSettingsPersistence() {
        let settings = SettingsStore.shared
        let originalEnabled = settings.notificationsEnabled
        let originalThresh = settings.criticalThresholdPercent
        let originalCrit = settings.notifyOnCritical
        let originalReset = settings.notifyOnReset
        let originalSound = settings.notificationSoundEnabled

        defer {
            settings.notificationsEnabled = originalEnabled
            settings.criticalThresholdPercent = originalThresh
            settings.notifyOnCritical = originalCrit
            settings.notifyOnReset = originalReset
            settings.notificationSoundEnabled = originalSound
        }

        settings.notificationsEnabled = false
        XCTAssertEqual(settings.notificationsEnabled, false)

        settings.notificationsEnabled = true
        XCTAssertEqual(settings.notificationsEnabled, true)

        settings.criticalThresholdPercent = 20
        XCTAssertEqual(settings.criticalThresholdPercent, 20)

        settings.criticalThresholdPercent = 10
        XCTAssertEqual(settings.criticalThresholdPercent, 10)

        settings.notifyOnCritical = false
        XCTAssertEqual(settings.notifyOnCritical, false)

        settings.notifyOnReset = false
        XCTAssertEqual(settings.notifyOnReset, false)

        settings.notificationSoundEnabled = false
        XCTAssertEqual(settings.notificationSoundEnabled, false)
    }

    func testNotificationEvaluation() {
        let manager = NotificationManager.shared
        let profileID = UUID()

        let window5h = UsageWindow(
            id: "5h",
            label: "5 h",
            remainingPercent: 80.0,
            durationMinutes: 300,
            resetsAt: Date().addingTimeInterval(3600),
            scope: nil
        )

        let initialSnapshot = UsageSnapshot(
            profileID: profileID,
            plan: "Plus",
            windows: [window5h],
            fetchedAt: Date(),
            error: nil
        )

        // Evaluate above threshold
        manager.evaluateSnapshots(
            oldSnapshots: [:],
            newSnapshots: [profileID: initialSnapshot]
        )

        // Now drop to critical (10%)
        let lowWindow = UsageWindow(
            id: "5h",
            label: "5 h",
            remainingPercent: 10.0,
            durationMinutes: 300,
            resetsAt: Date().addingTimeInterval(1800),
            scope: nil
        )

        let lowSnapshot = UsageSnapshot(
            profileID: profileID,
            plan: "Plus",
            windows: [lowWindow],
            fetchedAt: Date(),
            error: nil
        )

        manager.evaluateSnapshots(
            oldSnapshots: [profileID: initialSnapshot],
            newSnapshots: [profileID: lowSnapshot]
        )

        // Second evaluation while still at 10% (should not duplicate)
        manager.evaluateSnapshots(
            oldSnapshots: [profileID: lowSnapshot],
            newSnapshots: [profileID: lowSnapshot]
        )

        // Now restore back to 100%
        let restoredWindow = UsageWindow(
            id: "5h",
            label: "5 h",
            remainingPercent: 100.0,
            durationMinutes: 300,
            resetsAt: Date().addingTimeInterval(18000),
            scope: nil
        )

        let restoredSnapshot = UsageSnapshot(
            profileID: profileID,
            plan: "Plus",
            windows: [restoredWindow],
            fetchedAt: Date(),
            error: nil
        )

        manager.evaluateSnapshots(
            oldSnapshots: [profileID: lowSnapshot],
            newSnapshots: [profileID: restoredSnapshot]
        )
    }

    func testCLINotifyCommands() async {
        let handledStatus = await CLIHandler.handle(arguments: ["seeusage", "notify"])
        XCTAssertTrue(handledStatus)

        let handledOn = await CLIHandler.handle(arguments: ["seeusage", "notify", "on"])
        XCTAssertTrue(handledOn)
        XCTAssertEqual(SettingsStore.shared.notificationsEnabled, true)

        let handledThresh = await CLIHandler.handle(arguments: ["seeusage", "notify", "12"])
        XCTAssertTrue(handledThresh)
        XCTAssertEqual(SettingsStore.shared.criticalThresholdPercent, 12)

        let handledTest = await CLIHandler.handle(arguments: ["seeusage", "notify", "test"])
        XCTAssertTrue(handledTest)

        // Reset to 15
        SettingsStore.shared.criticalThresholdPercent = 15
    }
}
