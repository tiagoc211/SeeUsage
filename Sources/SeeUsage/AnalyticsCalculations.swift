import Foundation

enum AnalyticsCalculations {
    // MARK: - Computations

    /// Hourly consumption profile (0h - 23h)
    static func hourlyConsumption(in snapshots: [QuotaHistorySnapshot], days: Int = 7) -> [HourlyConsumption] {
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
                let key = r.id
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = r.id
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
    static func dailyConsumption(in snapshots: [QuotaHistorySnapshot], days: Int = 7) -> [DailyConsumption] {
        let calendar = Calendar.current
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        let relevant = snapshots.filter { $0.timestamp >= cutoff }

        guard relevant.count >= 2 else { return [] }

        var dayProfileSums: [String: [UUID: (name: String, total: Double)]] = [:]
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
                let key = r.id
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = r.id
                if let p = prevMap[key], p >= r.remainingPercent {
                    let consumed = p - r.remainingPercent
                    if consumed > 0 {
                        var current = dayProfileSums[dayKey]?[r.profileID] ?? (name: r.profileName, total: 0.0)
                        current.total += consumed
                        dayProfileSums[dayKey, default: [:]][r.profileID] = current
                    }
                }
            }
        }

        var results: [DailyConsumption] = []
        let sortedDays = dayProfileSums.keys.sorted()

        for d in sortedDays {
            let date = dateMap[d] ?? Date()
            if let profiles = dayProfileSums[d] {
                for (profileID, profile) in profiles {
                    results.append(DailyConsumption(
                        dayKey: d,
                        date: date,
                        profileID: profileID,
                        profileName: profile.name,
                        consumptionPercent: profile.total
                    ))
                }
            }
        }

        return results
    }

    /// Breakdown of usage per profile / model family
    static func profileSummaries(in snapshots: [QuotaHistorySnapshot], days: Int = 7) -> [ProfileUsageSummary] {
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        let relevant = snapshots.filter { $0.timestamp >= cutoff }

        guard relevant.count >= 2 else { return [] }

        var profileTotals: [String: (name: String, service: String, total: Double)] = [:]

        for i in 1..<relevant.count {
            let prev = relevant[i - 1]
            let curr = relevant[i]

            var prevMap: [String: Double] = [:]
            for r in prev.records {
                let key = r.id
                prevMap[key] = r.remainingPercent
            }

            for r in curr.records {
                let key = r.id
                if let p = prevMap[key], p >= r.remainingPercent {
                    let consumed = p - r.remainingPercent
                    if consumed > 0 {
                        let displayName: String
                        if r.service == "Antigravity" {
                            displayName = r.scope.map { "agy (\($0.lowercased()))" } ?? "Antigravity"
                        } else {
                            displayName = r.profileName
                        }
                        let summaryID = "\(r.profileID.uuidString):\(r.scope ?? "")"
                        let current = profileTotals[summaryID] ?? (name: displayName, service: r.service, total: 0.0)
                        profileTotals[summaryID] = (name: displayName, service: r.service, total: current.total + consumed)
                    }
                }
            }
        }

        let grandTotal = profileTotals.values.reduce(0.0) { $0 + $1.total }
        guard grandTotal > 0 else { return [] }

        return profileTotals.map { id, tuple in
            ProfileUsageSummary(
                id: id,
                name: tuple.name,
                service: tuple.service,
                totalConsumption: tuple.total,
                percentageOfTotal: (tuple.total / grandTotal) * 100.0
            )
        }.sorted { $0.totalConsumption > $1.totalConsumption }
    }

    /// High-level metrics for dashboard cards
    static func metrics(in snapshots: [QuotaHistorySnapshot], days: Int = 7) -> AnalyticsMetrics {
        let daily = dailyConsumption(in: snapshots, days: days)
        let total = daily.reduce(0.0) { $0 + $1.consumptionPercent }

        let hourly = hourlyConsumption(in: snapshots, days: days)
        let peakHour = hourly.max(by: { $0.consumptionPercent < $1.consumptionPercent })

        let peakRangeStr: String
        if let ph = peakHour, ph.consumptionPercent > 0 {
            let nextHour = (ph.hour + 1) % 24
            peakRangeStr = String(format: "%02d:00 – %02d:00", ph.hour, nextHour)
        } else {
            peakRangeStr = "N/A"
        }

        let profiles = profileSummaries(in: snapshots, days: days)
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

}
