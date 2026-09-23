import Foundation
import Observation

public extension Notification.Name {
    static let usageStoreDidUpdate = Notification.Name("app.seeusage.store.didUpdate")
}

public struct SharedUsageCache: Codable, Sendable {
    public let timestamp: Date
    public let snapshots: [UUID: UsageSnapshot]

    public init(timestamp: Date, snapshots: [UUID: UsageSnapshot]) {
        self.timestamp = timestamp
        self.snapshots = snapshots
    }
}

@Observable
@MainActor
public final class UsageStore {
    public static let shared = UsageStore()

    public private(set) var snapshots: [UUID: UsageSnapshot] = [:]
    public private(set) var claudeUsageSnapshot: ClaudeUsageSnapshot?
    public private(set) var isRefreshing: Bool = false
    public private(set) var lastUpdated: Date? = nil

    private var timerTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?
    private var refreshRequestedAfterCurrent = false
    private static let cacheKey = "app.seeusage.snapshots.cache"

    public static var sharedCacheURL: URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/seeusage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("cache.json")
    }

    public var minRemainingPercent: Int? {
        var minVal: Double? = nil
        let activeIDs = Set(SettingsStore.shared.codexProfiles.map(\.id) + [SettingsStore.antigravityProfileID])
        for (id, snapshot) in snapshots where activeIDs.contains(id) && snapshot.error == nil && !snapshot.isStale {
            for window in snapshot.windows {
                if let pct = window.remainingPercent {
                    if let current = minVal {
                        minVal = min(current, pct)
                    } else {
                        minVal = pct
                    }
                }
            }
        }
        return minVal.map { Int(round($0)) }
    }

    public var codexLowestPercent: Int? {
        let codexIDs = Set(SettingsStore.shared.codexProfiles.map(\.id))
        var minVal: Double? = nil
        for (id, snapshot) in snapshots where codexIDs.contains(id) && snapshot.error == nil && !snapshot.isStale {
            for window in snapshot.windows {
                if let pct = window.remainingPercent {
                    minVal = min(minVal ?? pct, pct)
                }
            }
        }
        return minVal.map { Int(round($0)) }
    }

    public var antigravityLowestPercent: Int? {
        guard let snapshot = snapshots[SettingsStore.antigravityProfileID] else { return nil }
        guard snapshot.error == nil, !snapshot.isStale else { return nil }
        var minVal: Double? = nil
        for window in snapshot.windows {
            if let pct = window.remainingPercent {
                minVal = min(minVal ?? pct, pct)
            }
        }
        return minVal.map { Int(round($0)) }
    }

    public init() {
        loadCache()
        loadClaudeUsageCache()
        observeSharedCacheUpdates()
        startTimer()
    }

    private func observeSharedCacheUpdates() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.cacheChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.loadCache() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.claudeUsageChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.loadClaudeUsageCache() }
        }
    }

    public func loadCache() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 1. Try reading from ~/.config/seeusage/cache.json
        let diskData = SharedFileLock.withExclusiveLock(for: Self.sharedCacheURL) {
            try? Data(contentsOf: Self.sharedCacheURL)
        }
        if let diskData,
           let cached = try? decoder.decode(SharedUsageCache.self, from: diskData) {
            self.snapshots = cached.snapshots
            self.lastUpdated = cached.timestamp
            NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
            return
        }

        // 2. Fallback to UserDefaults
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let decoded = try? decoder.decode([UUID: UsageSnapshot].self, from: data) {
            self.snapshots = decoded
            self.lastUpdated = decoded.values.map(\.fetchedAt).max()
            NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
        }
    }

    public func loadClaudeUsageCache() {
        let latest = ClaudeStatusLineIntegration.loadCachedUsage()
        guard latest != claudeUsageSnapshot else { return }
        claudeUsageSnapshot = latest
        NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
    }

    private func saveCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(snapshots) {
            UserDefaults.standard.set(encoded, forKey: Self.cacheKey)
        }

        SharedFileLock.withExclusiveLock(for: Self.sharedCacheURL) {
            var mergedSnapshots: [UUID: UsageSnapshot] = [:]
            var cacheTimestamp = lastUpdated ?? Date()
            let cacheDecoder = JSONDecoder()
            cacheDecoder.dateDecodingStrategy = .iso8601
            if let existingData = try? Data(contentsOf: Self.sharedCacheURL),
               let existing = try? cacheDecoder.decode(SharedUsageCache.self, from: existingData) {
                mergedSnapshots = existing.snapshots
                cacheTimestamp = max(cacheTimestamp, existing.timestamp)
            }

            let activeIDs = Set(SettingsStore.shared.codexProfiles.map(\.id) + [SettingsStore.antigravityProfileID])
            mergedSnapshots = mergedSnapshots.filter { activeIDs.contains($0.key) }
            for (id, snapshot) in snapshots where activeIDs.contains(id) {
                if let existing = mergedSnapshots[id], existing.fetchedAt > snapshot.fetchedAt { continue }
                mergedSnapshots[id] = snapshot
            }

            let cacheObj = SharedUsageCache(timestamp: cacheTimestamp, snapshots: mergedSnapshots)
            if let sharedData = try? encoder.encode(cacheObj) {
                try? sharedData.write(to: Self.sharedCacheURL, options: .atomic)
            }
        }
        let bundleID = Bundle.main.bundleIdentifier
        if bundleID == nil || bundleID == "app.seeusage.SeeUsage" {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.cacheChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard let self = self, !Task.isCancelled else { break }
                let interval = SettingsStore.shared.refreshIntervalMinutes * 60
                let now = Date()
                let intervalElapsed = self.lastUpdated.map { now.timeIntervalSince($0) >= Double(interval) } ?? true

                self.loadClaudeUsageCache()

                // Check if any window reset time just elapsed
                var resetTriggered = false
                if let last = self.lastUpdated {
                    for snap in self.snapshots.values {
                        for win in snap.windows {
                            if let r = win.resetsAt, r <= now, r > last {
                                resetTriggered = true
                                break
                            }
                        }
                        if resetTriggered { break }
                    }
                }

                if intervalElapsed || resetTriggered {
                    await self.refresh()
                }
            }
        }
    }

    public func refresh(forceAfterCurrent: Bool = false) async {
        if let activeRefreshTask {
            if forceAfterCurrent {
                refreshRequestedAfterCurrent = true
            }
            await activeRefreshTask.value
            return
        }

        isRefreshing = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                self.refreshRequestedAfterCurrent = false
                await self.performRefresh()
            } while self.refreshRequestedAfterCurrent
            self.activeRefreshTask = nil
            self.isRefreshing = false
        }
        activeRefreshTask = task
        await task.value
    }

    public func pruneInactiveSnapshots() {
        let activeIDs = Set(SettingsStore.shared.codexProfiles.map(\.id) + [SettingsStore.antigravityProfileID])
        NotificationManager.shared.pruneInactiveProfiles(keeping: activeIDs)
        let previousCount = snapshots.count
        snapshots = snapshots.filter { activeIDs.contains($0.key) }
        guard snapshots.count != previousCount else { return }
        saveCache()
        NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
    }

    private func performRefresh() async {
        let settings = SettingsStore.shared
        let codexPath = ProcessRunner.resolveExecutable(named: "codex", overridePath: settings.codexExecutableOverride)
        let agyPath = ProcessRunner.resolveExecutable(named: "agy", overridePath: settings.antigravityExecutableOverride)

        let codexProfiles = settings.codexProfiles
        let agyProfileID = SettingsStore.antigravityProfileID
        let oldSnapshots = self.snapshots
        let activeProfileIDs = Set(codexProfiles.map(\.id) + [agyProfileID])
        self.snapshots = self.snapshots.filter { activeProfileIDs.contains($0.key) }

        await withTaskGroup(of: (UUID, UsageSnapshot).self) { group in
            // Codex profiles
            for profile in codexProfiles {
                group.addTask {
                    guard let exe = codexPath else {
                        return (profile.id, UsageSnapshot(profileID: profile.id, error: "Codex CLI not found."))
                    }
                    let snapshot = await CodexClient.fetch(profile: profile, executable: exe)
                    return (profile.id, snapshot)
                }
            }

            // Antigravity profile
            group.addTask {
                guard let exe = agyPath else {
                    return (agyProfileID, UsageSnapshot(profileID: agyProfileID, error: "Antigravity CLI not found."))
                }
                let snapshot = await AntigravityClient.fetch(profileID: agyProfileID, executable: exe)
                return (agyProfileID, snapshot)
            }

            for await (id, snapshot) in group {
                let stillActive = id == agyProfileID || SettingsStore.shared.codexProfiles.contains(where: { $0.id == id })
                guard stillActive else { continue }
                if let err = snapshot.error, let old = self.snapshots[id] {
                    self.snapshots[id] = UsageSnapshot(
                        profileID: id,
                        plan: old.plan,
                        windows: old.windows,
                        availableResetCredits: old.availableResetCredits,
                        bankedCredits: old.bankedCredits,
                        fetchedAt: old.fetchedAt,
                        error: "\(err) (Outdated)"
                    )
                } else {
                    self.snapshots[id] = snapshot
                }
            }
        }

        self.lastUpdated = Date()
        self.saveCache()
        NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
        NotificationManager.shared.evaluateSnapshots(oldSnapshots: oldSnapshots, newSnapshots: self.snapshots)
        AnalyticsManager.shared.recordSnapshots(self.snapshots)
    }

    // MARK: - Banked Reset Consumption
    public func consumeBankedReset(for profile: UsageProfile, creditId: String?) async -> (success: Bool, message: String) {
        await refresh(forceAfterCurrent: true)
        guard let snapshot = snapshots[profile.id], snapshot.error == nil, !snapshot.isStale else {
            return (false, snapshots[profile.id]?.error ?? "No current usage data for this profile.")
        }

        if let creditId {
            guard snapshot.bankedCredits.contains(where: { $0.serverCreditID == creditId || $0.id == creditId }) else {
                return (false, "That reset credit is no longer available. Refresh and try again.")
            }
        } else if (snapshot.availableResetCredits ?? 0) < 1 {
            return (false, "No available reset credit found on this account.")
        }

        guard let exe = ProcessRunner.resolveExecutable(
            named: "codex",
            overridePath: SettingsStore.shared.codexExecutableOverride
        ) else {
            return (false, "Codex CLI not found.")
        }

        let res = await CodexClient.consumeResetCredit(
            profile: profile,
            creditId: creditId,
            executable: exe
        )

        // A timeout can happen after the server applied the operation, so always
        // reconcile local state after sending a consume request.
        await refresh(forceAfterCurrent: true)
        if res.success {
            let updated = snapshots[profile.id]
            let analytics = AnalyticsManager.shared
            for after in updated?.windows ?? [] {
                guard let before = snapshot.windows.first(where: { $0.id == after.id }),
                      let beforePercent = before.remainingPercent,
                      let afterPercent = after.remainingPercent,
                      afterPercent > beforePercent
                else { continue }
                analytics.recordResetEvent(ResetEvent(
                    timestamp: Date(),
                    profileID: profile.id,
                    profileName: profile.name,
                    service: "Codex",
                    scope: after.scope,
                    windowLabel: after.label,
                    durationMinutes: after.durationMinutes,
                    quotaBefore: beforePercent,
                    quotaAfter: afterPercent,
                    nextResetAt: after.resetsAt
                ))
            }
        }

        return res
    }
}
