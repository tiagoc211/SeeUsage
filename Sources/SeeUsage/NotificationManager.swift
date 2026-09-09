import Foundation
import UserNotifications
import AppKit

@MainActor
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    private var alertedLowWindows: Set<String> = []
    private var lastKnownPercentages: [String: Double] = [:]

    private static let alertedKey = "app.seeusage.alertedLowWindows"
    private static let lastPercentsKey = "app.seeusage.lastKnownPercentages"

    private override init() {
        super.init()
        loadState()
        setupCenterIfAvailable()
    }

    private func setupCenterIfAvailable() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    public func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - State Persistence
    private func loadState() {
        let prefs = SettingsStore.defaults
        if let list = prefs.stringArray(forKey: Self.alertedKey) {
            alertedLowWindows = Set(list)
        }
        if let dict = prefs.dictionary(forKey: Self.lastPercentsKey) as? [String: Double] {
            lastKnownPercentages = dict
        }
    }

    private func saveState() {
        let prefs = SettingsStore.defaults
        prefs.set(Array(alertedLowWindows), forKey: Self.alertedKey)
        prefs.set(lastKnownPercentages, forKey: Self.lastPercentsKey)
    }

    // MARK: - Quota Evaluation Engine
    public func evaluateSnapshots(
        oldSnapshots: [UUID: UsageSnapshot],
        newSnapshots: [UUID: UsageSnapshot]
    ) {
        let settings = SettingsStore.shared
        guard settings.notificationsEnabled else { return }

        let threshold = Double(settings.criticalThresholdPercent)

        for (profileID, newSnapshot) in newSnapshots {
            let profileName: String
            let serviceName: String

            if profileID == SettingsStore.antigravityProfileID {
                serviceName = "Antigravity"
                profileName = "Antigravity"
            } else if let p = settings.codexProfiles.first(where: { $0.id == profileID }) {
                serviceName = "Codex"
                profileName = p.name
            } else {
                serviceName = "Codex"
                profileName = "Profile"
            }

            for window in newSnapshot.windows {
                guard let currentPct = window.remainingPercent else { continue }
                let scopeLabel = window.scope.map { " (\($0))" } ?? ""
                let key = "\(profileID.uuidString):\(window.scope ?? ""):\(window.label)"
                let prevPct = lastKnownPercentages[key]

                // 1. Critical Quota Alert
                if settings.notifyOnCritical && currentPct <= threshold {
                    let wasAbove = prevPct == nil || prevPct! > threshold
                    if wasAbove && !alertedLowWindows.contains(key) {
                        alertedLowWindows.insert(key)
                        let title = "⚠️ Low Quota: \(serviceName)\(scopeLabel)"
                        let countdown = window.resetsAt.map { " Resets in " + WatchDashboard.countdownString(until: $0) + "." } ?? ""
                        let body = "\(profileName) \(window.label) quota is down to \(Int(round(currentPct)))%.\(countdown)"
                        postNotification(
                            title: title,
                            subtitle: "Critical Quota Alert",
                            body: body,
                            identifier: "low-\(key)"
                        )
                    }
                }

                // 2. Quota Restored Alert
                if settings.notifyOnReset {
                    let wasLow = (prevPct != nil && prevPct! <= threshold) || alertedLowWindows.contains(key)
                    let isRestored = currentPct > threshold && (prevPct == nil || currentPct > (prevPct! + 5.0) || currentPct >= 95.0)
                    if wasLow && isRestored {
                        alertedLowWindows.remove(key)
                        let title = "⚡ Quota Restored: \(serviceName)\(scopeLabel)"
                        let body = "\(profileName) \(window.label) quota has been restored to \(Int(round(currentPct)))%."
                        postNotification(
                            title: title,
                            subtitle: "Quota Reset",
                            body: body,
                            identifier: "restored-\(key)"
                        )
                    }
                }

                lastKnownPercentages[key] = currentPct
            }
        }
        saveState()
    }

    // MARK: - Post Notification
    public func postNotification(
        title: String,
        subtitle: String? = nil,
        body: String,
        identifier: String = UUID().uuidString
    ) {
        let settings = SettingsStore.shared
        guard settings.notificationsEnabled else { return }
        let soundEnabled = settings.notificationSoundEnabled

        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            if let sub = subtitle { content.subtitle = sub }
            content.body = body
            if soundEnabled {
                content.sound = .default
            }

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    Self.postViaAppleScript(
                        title: title,
                        subtitle: subtitle,
                        body: body,
                        sound: soundEnabled
                    )
                }
            }
        } else {
            Self.postViaAppleScript(
                title: title,
                subtitle: subtitle,
                body: body,
                sound: soundEnabled
            )
        }
    }

    public func sendTestNotification() {
        let threshold = SettingsStore.shared.criticalThresholdPercent
        postNotification(
            title: "⚡ SeeUsage Notification Test",
            subtitle: "Alerts Configured",
            body: "Native macOS notifications are working properly! Critical threshold is currently set to \(threshold)%.",
            identifier: "test-\(Date().timeIntervalSince1970)"
        )
    }

    private nonisolated static func postViaAppleScript(title: String, subtitle: String?, body: String, sound: Bool) {
        let cleanTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let cleanBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        var script = "display notification \"\(cleanBody)\" with title \"\(cleanTitle)\""
        if let sub = subtitle {
            let cleanSub = sub.replacingOccurrences(of: "\"", with: "\\\"")
            script += " subtitle \"\(cleanSub)\""
        }
        if sound {
            script += " sound name \"default\""
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
