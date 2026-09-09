import Foundation
import Observation

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

        var newSnapshots: [UUID: UsageSnapshot] = [:]

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
                newSnapshots[id] = snapshot
            }
        }

        // Preserve previous windows if new fetch returned an error (fallback to cached data)
        for (id, newSnapshot) in newSnapshots {
            if let err = newSnapshot.error, let old = snapshots[id], !old.windows.isEmpty {
                snapshots[id] = UsageSnapshot(
                    profileID: id,
                    plan: old.plan,
                    windows: old.windows,
                    fetchedAt: old.fetchedAt,
                    error: "\(err) (Desatualizado)"
                )
            } else {
                snapshots[id] = newSnapshot
            }
        }

        saveCache()
        lastUpdated = Date()
    }
}
