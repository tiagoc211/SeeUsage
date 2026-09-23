import Foundation

extension CLIHandler {
    // MARK: - Analytics & History Command
    static func handleAnalyticsCommand(subArg: String?) {
        let analytics = AnalyticsManager.shared
        analytics.loadHistory()

        guard let action = subArg?.lowercased() else {
            printAnalyticsDashboard(analytics: analytics)
            return
        }

        switch action {
        case "clear", "--clear", "reset":
            analytics.clearHistory()
            print("\n" + green("✓") + " Quota history cleared (~/.config/seeusage/history.json deleted).\n")
        case "csv", "--csv":
            print(analytics.exportCSV())
        case "json", "--json":
            print(analytics.exportJSON())
        default:
            printAnalyticsDashboard(analytics: analytics)
        }
    }

    private static func printAnalyticsDashboard(analytics: AnalyticsManager) {
        let metrics = analytics.computeMetrics(days: 7)
        let daily = analytics.computeDailyConsumption(days: 7)
        let summaries = analytics.computeProfileSummaries(days: 7)

        print("\n" + bold(cyan("// SEEUSAGE QUOTA ANALYTICS (LAST 7 DAYS)")))
        print("")
        print("  " + bold("Total Burned:") + "        " + amber(String(format: "%.0f%%", metrics.totalConsumption7Days)))
        print("  " + bold("Peak Burn Window:") + "    " + cyan(metrics.peakHourRange))
        print("  " + bold("Primary Profile:") + "     " + green(metrics.primaryProfileName))
        print("  " + bold("Samples Logged:") + "      " + dim("\(metrics.totalSamplesCount) in ~/.config/seeusage/history.json"))
        print("")

        // Daily Consumption
        print(bold(dim("// DAILY CONSUMPTION (LAST 7 DAYS)")))
        if daily.isEmpty {
            print("  " + dim("No consumption detected yet."))
        } else {
            var dayTotals: [String: (label: String, val: Double)] = [:]
            for item in daily {
                let cur = dayTotals[item.dayKey] ?? (label: item.shortDateLabel, val: 0.0)
                dayTotals[item.dayKey] = (label: item.shortDateLabel, val: cur.val + item.consumptionPercent)
            }
            let sortedKeys = dayTotals.keys.sorted()
            let maxDay = sortedKeys.compactMap { dayTotals[$0]?.val }.max() ?? 100.0

            for k in sortedKeys {
                if let data = dayTotals[k] {
                    let label = data.label.padding(toLength: 12, withPad: " ", startingAt: 0)
                    let pct = Int(round(data.val))
                    let blocksCount = Int(round((data.val / max(1.0, maxDay)) * 14.0))
                    let bar = cyan(String(repeating: "■", count: blocksCount)) + dim(String(repeating: "□", count: max(0, 14 - blocksCount)))
                    print("  \(dim(label)) [\(bar)] \(bold(String(format: "%3d%%", pct)))")
                }
            }
        }
        print("")

        // Profile Share
        print(bold(dim("// PROFILE & MODEL BREAKDOWN")))
        if summaries.isEmpty {
            print("  " + dim("No profile metrics recorded yet."))
        } else {
            for item in summaries {
                let name = item.name.padding(toLength: 18, withPad: " ", startingAt: 0)
                let pctStr = String(format: "%5.1f%%", item.percentageOfTotal)
                let ptsStr = String(format: "(%.0f pts)", item.totalConsumption).padding(toLength: 12, withPad: " ", startingAt: 0)
                let tag = item.service == "Antigravity" ? purple("[agy]") : green("[codex]")
                print("  \(bold(name)) \(cyan(pctStr))  \(dim(ptsStr)) \(tag)")
            }
        }
        print("")
        print(dim("  Commands:"))
        print(dim("    seeusage analytics csv       Export history to CSV"))
        print(dim("    seeusage analytics json      Export history to JSON"))
        print(dim("    seeusage analytics clear     Reset all recorded history"))
        print("")
    }

}
