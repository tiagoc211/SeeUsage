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
    public private(set) var isRefreshing: Bool = false
    public private(set) var lastUpdated: Date? = nil

    private var refreshTask: Task<Void, Never>?
    private static let cacheKey = "app.seeusage.snapshots.cache"

    public static var sharedCacheURL: URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/seeusage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("cache.json")
    }

    public var minRemainingPercent: Int? {
        var minVal: Double? = nil
        for (_, snapshot) in snapshots {
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
        for (id, snapshot) in snapshots where codexIDs.contains(id) {
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
        startTimer()
    }

    public func loadCache() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 1. Try reading from ~/.config/seeusage/cache.json
        if let diskData = try? Data(contentsOf: Self.sharedCacheURL),
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
            NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
        }
    }

    private func saveCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(snapshots) {
            UserDefaults.standard.set(encoded, forKey: Self.cacheKey)
        }

        let cacheObj = SharedUsageCache(timestamp: lastUpdated ?? Date(), snapshots: snapshots)
        if let sharedData = try? encoder.encode(cacheObj) {
            try? sharedData.write(to: Self.sharedCacheURL, options: .atomic)
        }
    }

    public func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard let self = self, !Task.isCancelled else { break }
                let interval = SettingsStore.shared.refreshIntervalMinutes * 60
                if let last = self.lastUpdated, Date().timeIntervalSince(last) >= Double(interval) {
                    await self.refresh()
                }
            }
        }
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let settings = SettingsStore.shared
        let codexPath = ProcessRunner.resolveExecutable(named: "codex", overridePath: settings.codexExecutableOverride)
        let agyPath = ProcessRunner.resolveExecutable(named: "agy", overridePath: settings.antigravityExecutableOverride)

        let codexProfiles = settings.codexProfiles
        let agyProfileID = SettingsStore.antigravityProfileID

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
                if let err = snapshot.error, let old = self.snapshots[id], !old.windows.isEmpty {
                    self.snapshots[id] = UsageSnapshot(
                        profileID: id,
                        plan: old.plan,
                        windows: old.windows,
                        fetchedAt: old.fetchedAt,
                        error: "\(err) (Desatualizado)"
                    )
                } else {
                    self.snapshots[id] = snapshot
                }
                self.saveCache()
                self.lastUpdated = Date()
                NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
            }
        }
    }
}
