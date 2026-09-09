import Foundation
import Observation

extension Notification.Name {
    public static let usageStoreDidUpdate = Notification.Name("usageStoreDidUpdate")
}

@Observable
@MainActor
public final class UsageStore {
    public static let shared = UsageStore()

    private static let cacheKey = "cachedSnapshots"

    public private(set) var snapshots: [UUID: UsageSnapshot] = [:]
    public private(set) var isRefreshing = false
    public private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?

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

    public init() {
        loadCache()
        startTimer()
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let decoded = try? JSONDecoder().decode([UUID: UsageSnapshot].self, from: data) else {
            return
        }
        self.snapshots = decoded
        NotificationCenter.default.post(name: .usageStoreDidUpdate, object: nil)
    }

    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(encoded, forKey: Self.cacheKey)
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
                        return (profile.id, UsageSnapshot(profileID: profile.id, error: "Codex CLI não encontrado."))
                    }
                    let snapshot = await CodexClient.fetch(profile: profile, executable: exe)
                    return (profile.id, snapshot)
                }
            }

            // Antigravity profile
            group.addTask {
                guard let exe = agyPath else {
                    return (agyProfileID, UsageSnapshot(profileID: agyProfileID, error: "Antigravity CLI não encontrado."))
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
