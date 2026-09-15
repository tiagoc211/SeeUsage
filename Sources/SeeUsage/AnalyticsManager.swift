import Foundation
import Observation

// MARK: - Quota Sample Record
public struct QuotaSampleRecord: Codable, Sendable, Identifiable {
    public var id: String { "\(timestamp.timeIntervalSince1970)-\(profileID.uuidString)-\(scope ?? "")-\(windowLabel)" }
    public let timestamp: Date
    public let profileID: UUID
    public let profileName: String
    public let service: String
    public let scope: String?
    public let windowLabel: String
    public let remainingPercent: Double
    public let resetsAt: Date?

    public var usedPercent: Double {
        max(0.0, min(100.0, 100.0 - remainingPercent))
    }
}

// MARK: - Quota History Snapshot
public struct QuotaHistorySnapshot: Codable, Sendable, Identifiable {
    public var id: Double { timestamp.timeIntervalSince1970 }
    public let timestamp: Date
    public let records: [QuotaSampleRecord]
}

// MARK: - Analytics Aggregation Models
public struct HourlyConsumption: Identifiable, Sendable {
    public var id: Int { hour }
    public let hour: Int // 0...23
    public let consumptionPercent: Double
    public var hourLabel: String {
        String(format: "%02d:00", hour)
    }
}

public struct DailyConsumption: Identifiable, Sendable {
    public var id: String { dayKey }
    public let dayKey: String // "yyyy-MM-dd"
    public let date: Date
    public let profileName: String
    public let consumptionPercent: Double

    public var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    public var shortDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

public struct ProfileUsageSummary: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let service: String
    public let totalConsumption: Double
    public let percentageOfTotal: Double
}

public struct AnalyticsMetrics: Sendable {
    public let totalConsumption7Days: Double
    public let peakHourRange: String
    public let primaryProfileName: String
    public let totalSamplesCount: Int
    public let dailyAverageConsumption: Double
}

// MARK: - Analytics & History Manager
@Observable
@MainActor
public final class AnalyticsManager {
    public static let shared = AnalyticsManager()

    public private(set) var snapshots: [QuotaHistorySnapshot] = []
    public private(set) var resetEvents: [ResetEvent] = []
    public private(set) var lastRecordedAt: Date?

    public static var historyFileURL: URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/seeusage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }

    public static var resetsFileURL: URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/seeusage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("resets.json")
    }

    private init() {
        loadHistory()
    }

    // MARK: - Persistence
    public func loadHistory() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: Self.historyFileURL),
           let list = try? decoder.decode([QuotaHistorySnapshot].self, from: data) {
            self.snapshots = list
            self.lastRecordedAt = list.last?.timestamp
        }

        if let data = try? Data(contentsOf: Self.resetsFileURL),
           let events = try? decoder.decode([ResetEvent].self, from: data) {
            self.resetEvents = events
        }
    }

    public func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Keep at most 3,000 snapshots (~30-60 days at regular polling)
        let trimmed: [QuotaHistorySnapshot]
        if snapshots.count > 3000 {
            trimmed = Array(snapshots.suffix(3000))
        } else {
            trimmed = snapshots
        }

        if let data = try? encoder.encode(trimmed) {
            try? data.write(to: Self.historyFileURL, options: .atomic)
        }

        // Keep at most 1,000 reset events
        let trimmedResets: [ResetEvent]
        if resetEvents.count > 1000 {
            trimmedResets = Array(resetEvents.prefix(1000))
        } else {
            trimmedResets = resetEvents
        }

        if let data = try? encoder.encode(trimmedResets) {
            try? data.write(to: Self.resetsFileURL, options: .atomic)
        }
    }

    public func clearHistory() {
        snapshots.removeAll()
        resetEvents.removeAll()
        lastRecordedAt = nil
        try? FileManager.default.removeItem(at: Self.historyFileURL)
        try? FileManager.default.removeItem(at: Self.resetsFileURL)
    }

    public func clearResets() {
        resetEvents.removeAll()
        try? FileManager.default.removeItem(at: Self.resetsFileURL)
    }

    // MARK: - Recording Snapshots & Detecting Resets
    public func recordSnapshots(_ usageSnapshots: [UUID: UsageSnapshot]) {
        let settings = SettingsStore.shared
        var records: [QuotaSampleRecord] = []
        let now = Date()

        for (profileID, snapshot) in usageSnapshots {
            let profileName: String
            let service: String

            if profileID == SettingsStore.antigravityProfileID {
                profileName = "Antigravity"
                service = "Antigravity"
            } else if let p = settings.codexProfiles.first(where: { $0.id == profileID }) {
                profileName = p.name
                service = "Codex"
            } else {
                profileName = "Codex"
                service = "Codex"
            }

            for window in snapshot.windows {
                guard let pct = window.remainingPercent else { continue }
                records.append(QuotaSampleRecord(
                    timestamp: now,
                    profileID: profileID,
                    profileName: profileName,
                    service: service,
                    scope: window.scope,
                    windowLabel: window.label,
                    remainingPercent: pct,
                    resetsAt: window.resetsAt
                ))
            }
        }

        guard !records.isEmpty else { return }

        // Detect Reset Events by comparing against the most recent snapshot
        if let lastSnapshot = snapshots.last {
            var lastRecordsMap: [String: QuotaSampleRecord] = [:]
            for r in lastSnapshot.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                lastRecordsMap[key] = r
            }

            for newRecord in records {
                let key = "\(newRecord.profileID.uuidString):\(newRecord.scope ?? ""):\(newRecord.windowLabel)"
                guard let oldRecord = lastRecordsMap[key] else { continue }

                var isReset = false

                // Condition 1: Old reset deadline has passed or new reset deadline has advanced
                if let oldReset = oldRecord.resetsAt {
                    let passedOldReset = oldReset <= now
                    let cycleAdvanced = newRecord.resetsAt != nil && newRecord.resetsAt!.timeIntervalSince(oldReset) > 60.0
                    if (passedOldReset || cycleAdvanced) && (newRecord.remainingPercent > oldRecord.remainingPercent || newRecord.remainingPercent >= 95.0) {
                        isReset = true
                    }
                }

                // Condition 2: Quota increased significantly (at least +10% restoration)
                if newRecord.remainingPercent >= oldRecord.remainingPercent + 10.0 {
                    isReset = true
                }

                if isReset {
                    let win = usageSnapshots[newRecord.profileID]?.windows.first(where: {
                        $0.label == newRecord.windowLabel && $0.scope == newRecord.scope
                    })
                    let duration = win?.durationMinutes

                    // Avoid duplicate logging within 2 minutes for the same window
                    let isDuplicate = resetEvents.contains { past in
                        past.profileID == newRecord.profileID &&
                        past.windowLabel == newRecord.windowLabel &&
                        past.scope == newRecord.scope &&
                        abs(past.timestamp.timeIntervalSince(now)) < 120.0
                    }

                    if !isDuplicate {
                        let event = ResetEvent(
                            id: UUID(),
                            timestamp: now,
                            profileID: newRecord.profileID,
                            profileName: newRecord.profileName,
                            service: newRecord.service,
                            scope: newRecord.scope,
                            windowLabel: newRecord.windowLabel,
                            durationMinutes: duration,
                            quotaBefore: oldRecord.remainingPercent,
                            quotaAfter: newRecord.remainingPercent,
                            quotaRestored: max(0.0, newRecord.remainingPercent - oldRecord.remainingPercent),
                            nextResetAt: newRecord.resetsAt
                        )
                        resetEvents.insert(event, at: 0)
                    }
                }
            }
        }

        // Deduplicate snapshots against very recent recording (under 45 seconds) unless quota changed
        if let last = snapshots.last,
           now.timeIntervalSince(last.timestamp) < 45.0 {
            let lastRecordsMap = Dictionary(uniqueKeysWithValues: last.records.map { ($0.id, $0.remainingPercent) })
            let hasChange = records.contains { record in
                if let oldPct = lastRecordsMap[record.id] {
                    return abs(oldPct - record.remainingPercent) > 0.001
                }
                return true
            }
            if !hasChange { return }
        }

        let newSnapshot = QuotaHistorySnapshot(timestamp: now, records: records)
        snapshots.append(newSnapshot)
        lastRecordedAt = now
        saveHistory()
    }

    // MARK: - Upcoming & Historical Resets Queries

    /// Gathers all currently active windows that have a scheduled resetsAt date
    public func computeUpcomingResets(from usageSnapshots: [UUID: UsageSnapshot]? = nil) -> [UpcomingResetInfo] {
        let snapshotsToUse = usageSnapshots ?? UsageStore.shared.snapshots
        let settings = SettingsStore.shared
        var results: [UpcomingResetInfo] = []

        for (profileID, snapshot) in snapshotsToUse {
            let profileName: String
            let service: String

            if profileID == SettingsStore.antigravityProfileID {
                profileName = "Antigravity"
                service = "Antigravity"
            } else if let p = settings.codexProfiles.first(where: { $0.id == profileID }) {
                profileName = p.name
                service = "Codex"
            } else {
                profileName = "Codex"
                service = "Codex"
            }

            for window in snapshot.windows {
                guard let resetDate = window.resetsAt else { continue }
                results.append(UpcomingResetInfo(
                    profileID: profileID,
                    profileName: profileName,
                    service: service,
                    scope: window.scope,
                    windowLabel: window.label,
                    durationMinutes: window.durationMinutes,
                    currentRemainingPercent: window.remainingPercent,
                    resetsAt: resetDate
                ))
            }
        }

        // If active snapshots were empty (e.g. fresh CLI launch), fallback to latest history records
        if results.isEmpty, let lastSnap = snapshots.last {
            for record in lastSnap.records {
                guard let resetDate = record.resetsAt, resetDate > Date() else { continue }
                results.append(UpcomingResetInfo(
                    profileID: record.profileID,
                    profileName: record.profileName,
                    service: record.service,
                    scope: record.scope,
                    windowLabel: record.windowLabel,
                    durationMinutes: nil,
                    currentRemainingPercent: record.remainingPercent,
                    resetsAt: resetDate
                ))
            }
        }

        return results.sorted { $0.resetsAt < $1.resetsAt }
    }

    /// Retrieve reset history filtered by optional criteria
    public func getResetEvents(
        limit: Int = 100,
        service: String? = nil,
        profileID: UUID? = nil
    ) -> [ResetEvent] {
        var list = resetEvents
        if let s = service {
            list = list.filter { $0.service.lowercased() == s.lowercased() }
        }
        if let pid = profileID {
            list = list.filter { $0.profileID == pid }
        }
        return Array(list.prefix(limit))
    }

    // MARK: - Seeding Realistic Demo Data
    public func seedDemoDataIfEmpty() {
        guard snapshots.isEmpty else { return }

        var seeded: [QuotaHistorySnapshot] = []
        let calendar = Calendar.current
        let now = Date()

        let personalID = SettingsStore.shared.codexProfiles.first?.id ?? UUID()
        let workID = SettingsStore.shared.codexProfiles.dropFirst().first?.id ?? UUID()
        let agyID = SettingsStore.antigravityProfileID

        // Generate 7 days of 3-hour interval snapshots
        for dayOffset in (0...7).reversed() {
            guard let dayBase = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            for hour in stride(from: 8, through: 22, by: 2) {
                guard let sampleDate = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: dayBase) else { continue }
                if sampleDate > now { continue }

                // Simulate realistic daily burn
                let progressInDay = Double(hour - 8) / 14.0
                let personalPct = max(18.0, 95.0 - (progressInDay * 70.0) + Double.random(in: -3...3))
                let workPct = max(24.0, 100.0 - (progressInDay * 65.0) + Double.random(in: -4...4))
                let agyGeminiPct = max(35.0, 90.0 - (progressInDay * 50.0) + Double.random(in: -2...2))

                let records: [QuotaSampleRecord] = [
                    QuotaSampleRecord(
                        timestamp: sampleDate,
                        profileID: personalID,
                        profileName: "Pessoal",
                        service: "Codex",
                        scope: nil,
                        windowLabel: "5 h",
                        remainingPercent: personalPct,
                        resetsAt: sampleDate.addingTimeInterval(3600 * 3)
                    ),
                    QuotaSampleRecord(
                        timestamp: sampleDate,
                        profileID: workID,
                        profileName: "Trabalho",
                        service: "Codex",
                        scope: nil,
                        windowLabel: "5 h",
                        remainingPercent: workPct,
                        resetsAt: sampleDate.addingTimeInterval(3600 * 2.5)
                    ),
                    QuotaSampleRecord(
                        timestamp: sampleDate,
                        profileID: agyID,
                        profileName: "Antigravity",
                        service: "Antigravity",
                        scope: "Gemini",
                        windowLabel: "5 h",
                        remainingPercent: agyGeminiPct,
                        resetsAt: sampleDate.addingTimeInterval(3600 * 4)
                    )
                ]

                seeded.append(QuotaHistorySnapshot(timestamp: sampleDate, records: records))
            }
        }

        self.snapshots = seeded
        self.lastRecordedAt = seeded.last?.timestamp

        seedDemoResetDataIfEmpty()
        saveHistory()
    }

    public func seedDemoResetDataIfEmpty() {
        guard resetEvents.isEmpty else { return }

        let now = Date()
        let personalID = SettingsStore.shared.codexProfiles.first?.id ?? UUID()
        let workID = SettingsStore.shared.codexProfiles.dropFirst().first?.id ?? UUID()
        let agyID = SettingsStore.antigravityProfileID

        let sampleEvents: [ResetEvent] = [
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-3600 * 3.5),
                profileID: personalID,
                profileName: "Pessoal",
                service: "Codex",
                scope: nil,
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 18.0,
                quotaAfter: 100.0,
                quotaRestored: 82.0,
                nextResetAt: now.addingTimeInterval(3600 * 1.5)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-3600 * 8.5),
                profileID: personalID,
                profileName: "Pessoal",
                service: "Codex",
                scope: nil,
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 24.0,
                quotaAfter: 100.0,
                quotaRestored: 76.0,
                nextResetAt: now.addingTimeInterval(-3600 * 3.5)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-3600 * 12.0),
                profileID: workID,
                profileName: "Trabalho",
                service: "Codex",
                scope: nil,
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 31.0,
                quotaAfter: 100.0,
                quotaRestored: 69.0,
                nextResetAt: now.addingTimeInterval(-3600 * 7.0)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-3600 * 19.0),
                profileID: agyID,
                profileName: "Antigravity",
                service: "Antigravity",
                scope: "Gemini",
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 42.0,
                quotaAfter: 100.0,
                quotaRestored: 58.0,
                nextResetAt: now.addingTimeInterval(-3600 * 14.0)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-86400 * 2.1),
                profileID: personalID,
                profileName: "Pessoal",
                service: "Codex",
                scope: nil,
                windowLabel: "7 days",
                durationMinutes: 10080,
                quotaBefore: 48.0,
                quotaAfter: 100.0,
                quotaRestored: 52.0,
                nextResetAt: now.addingTimeInterval(86400 * 4.9)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-86400 * 3.2),
                profileID: workID,
                profileName: "Trabalho",
                service: "Codex",
                scope: nil,
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 15.0,
                quotaAfter: 100.0,
                quotaRestored: 85.0,
                nextResetAt: now.addingTimeInterval(-86400 * 3.0)
            ),
            ResetEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-86400 * 4.5),
                profileID: personalID,
                profileName: "Pessoal",
                service: "Codex",
                scope: nil,
                windowLabel: "5 h",
                durationMinutes: 300,
                quotaBefore: 8.0,
                quotaAfter: 100.0,
                quotaRestored: 92.0,
                nextResetAt: now.addingTimeInterval(-86400 * 4.3)
            )
        ]

        self.resetEvents = sampleEvents
        saveHistory()
    }

    // MARK: - Computations

    /// Hourly consumption profile (0h - 23h)
    public func computeHourlyConsumption(days: Int = 7) -> [HourlyConsumption] {
        let calendar = Calendar.current
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        let relevant = snapshots.filter { $0.timestamp >= cutoff }

        var hourlyBins: [Int: Double] = [:]
        for h in 0..<24 { hourlyBins[h] = 0.0 }

        guard relevant.count >= 2 else {
            return (0..<24).map { HourlyConsumption(hour: $0, consumptionPercent: hourlyBins[$0] ?? 0.0) }
        }

        for i in 1..<relevant.count {
            let prev = relevant[i - 1]
            let curr = relevant[i]
            let hour = calendar.component(.hour, from: curr.timestamp)

            var prevMap: [String: Double] = [:]
            for r in prev.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                if let p = prevMap[key], p >= r.remainingPercent {
                    let consumed = p - r.remainingPercent
                    if consumed > 0 {
                        hourlyBins[hour, default: 0.0] += consumed
                    }
                }
            }
        }

        return (0..<24).map {
            HourlyConsumption(hour: $0, consumptionPercent: hourlyBins[$0] ?? 0.0)
        }
    }

    /// Daily consumption for the last 7 days
    public func computeDailyConsumption(days: Int = 7) -> [DailyConsumption] {
        let calendar = Calendar.current
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        let relevant = snapshots.filter { $0.timestamp >= cutoff }

        guard relevant.count >= 2 else { return [] }

        var dayProfileSums: [String: [String: Double]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var dateMap: [String: Date] = [:]

        for i in 1..<relevant.count {
            let prev = relevant[i - 1]
            let curr = relevant[i]
            let dayKey = dateFormatter.string(from: curr.timestamp)
            dateMap[dayKey] = calendar.startOfDay(for: curr.timestamp)

            var prevMap: [String: Double] = [:]
            for r in prev.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                if let p = prevMap[key], p >= r.remainingPercent {
                    let consumed = p - r.remainingPercent
                    if consumed > 0 {
                        if dayProfileSums[dayKey] == nil { dayProfileSums[dayKey] = [:] }
                        dayProfileSums[dayKey]?[r.profileName, default: 0.0] += consumed
                    }
                }
            }
        }

        var results: [DailyConsumption] = []
        let sortedDays = dayProfileSums.keys.sorted()

        for d in sortedDays {
            let date = dateMap[d] ?? Date()
            if let profiles = dayProfileSums[d] {
                for (pName, consumed) in profiles {
                    results.append(DailyConsumption(
                        dayKey: d,
                        date: date,
                        profileName: pName,
                        consumptionPercent: consumed
                    ))
                }
            }
        }

        return results
    }

    /// Breakdown of usage per profile / model family
    public func computeProfileSummaries(days: Int = 7) -> [ProfileUsageSummary] {
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        let relevant = snapshots.filter { $0.timestamp >= cutoff }

        guard relevant.count >= 2 else { return [] }

        var profileTotals: [String: (service: String, total: Double)] = [:]

        for i in 1..<relevant.count {
            let prev = relevant[i - 1]
            let curr = relevant[i]

            var prevMap: [String: Double] = [:]
            for r in prev.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = "\(r.profileID.uuidString):\(r.scope ?? ""):\(r.windowLabel)"
                if let p = prevMap[key], p >= r.remainingPercent {
                    let consumed = p - r.remainingPercent
                    if consumed > 0 {
                        let displayName: String
                        if r.service == "Antigravity" {
                            displayName = r.scope.map { "agy (\($0.lowercased()))" } ?? "Antigravity"
                        } else {
                            displayName = r.profileName
                        }
                        let current = profileTotals[displayName] ?? (service: r.service, total: 0.0)
                        profileTotals[displayName] = (service: r.service, total: current.total + consumed)
                    }
                }
            }
        }

        let grandTotal = profileTotals.values.reduce(0.0) { $0 + $1.total }
        guard grandTotal > 0 else { return [] }

        return profileTotals.map { name, tuple in
            ProfileUsageSummary(
                name: name,
                service: tuple.service,
                totalConsumption: tuple.total,
                percentageOfTotal: (tuple.total / grandTotal) * 100.0
            )
        }.sorted { $0.totalConsumption > $1.totalConsumption }
    }

    /// High-level metrics for dashboard cards
    public func computeMetrics(days: Int = 7) -> AnalyticsMetrics {
        let daily = computeDailyConsumption(days: days)
        let total = daily.reduce(0.0) { $0 + $1.consumptionPercent }

        let hourly = computeHourlyConsumption(days: days)
        let peakHour = hourly.max(by: { $0.consumptionPercent < $1.consumptionPercent })

        let peakRangeStr: String
        if let ph = peakHour, ph.consumptionPercent > 0 {
            let nextHour = (ph.hour + 2) % 24
            peakRangeStr = String(format: "%02d:00 – %02d:00", ph.hour, nextHour)
        } else {
            peakRangeStr = "N/A"
        }

        let profiles = computeProfileSummaries(days: days)
        let primaryProfile = profiles.first?.name ?? "Codex"
        let activeDaysCount = max(1, Set(daily.map(\.dayKey)).count)

        return AnalyticsMetrics(
            totalConsumption7Days: total,
            peakHourRange: peakRangeStr,
            primaryProfileName: primaryProfile,
            totalSamplesCount: snapshots.count,
            dailyAverageConsumption: total / Double(activeDaysCount)
        )
    }

    // MARK: - Export Helpers
    public func exportCSV() -> String {
        var csv = "Timestamp,Profile,Service,Scope,Window,RemainingPercent,ResetsAt\n"
        let dateFormatter = ISO8601DateFormatter()

        for snapshot in snapshots {
            let timeStr = dateFormatter.string(from: snapshot.timestamp)
            for r in snapshot.records {
                let resetStr = r.resetsAt.map { dateFormatter.string(from: $0) } ?? ""
                let scopeStr = r.scope ?? ""
                csv += "\"\(timeStr)\",\"\(r.profileName)\",\"\(r.service)\",\"\(scopeStr)\",\"\(r.windowLabel)\",\(r.remainingPercent),\"\(resetStr)\"\n"
            }
        }
        return csv
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshots),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    public func exportResetsCSV() -> String {
        var csv = "Timestamp,Profile,Service,Scope,Window,QuotaBefore,QuotaAfter,QuotaRestored,NextResetAt\n"
        let dateFormatter = ISO8601DateFormatter()

        for event in resetEvents {
            let timeStr = dateFormatter.string(from: event.timestamp)
            let nextStr = event.nextResetAt.map { dateFormatter.string(from: $0) } ?? ""
            let scopeStr = event.scope ?? ""
            csv += "\"\(timeStr)\",\"\(event.profileName)\",\"\(event.service)\",\"\(scopeStr)\",\"\(event.windowLabel)\",\(event.quotaBefore),\(event.quotaAfter),\(event.quotaRestored),\"\(nextStr)\"\n"
        }
        return csv
    }

    public func exportResetsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(resetEvents),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    /// Extract all available banked reset credits across profiles
    public func getAvailableBankedCredits(
        from snapshots: [UUID: UsageSnapshot],
        profiles: [UsageProfile]
    ) -> [(profile: UsageProfile, credit: BankedResetCredit)] {
        var results: [(profile: UsageProfile, credit: BankedResetCredit)] = []
        for profile in profiles {
            guard let snap = snapshots[profile.id] else { continue }
            for credit in snap.bankedCredits where credit.status.lowercased() == "available" {
                results.append((profile: profile, credit: credit))
            }
        }
        return results
    }

    /// Explicitly record a reset event (e.g. from banked reset consumption)
    public func recordResetEvent(_ event: ResetEvent) {
        resetEvents.insert(event, at: 0)
        saveHistory()
    }
}
