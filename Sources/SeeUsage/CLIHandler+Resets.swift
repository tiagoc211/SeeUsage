import Foundation

extension CLIHandler {
    // MARK: - Quota Resets Command
    static func handleResetsCommand(args: [String], resetIdx: Int) async {
        let analytics = AnalyticsManager.shared
        analytics.loadHistory()

        let subArg = (resetIdx + 1 < args.count) ? args[resetIdx + 1].lowercased() : nil

        if subArg == "consume" || subArg == "activate" || subArg == "--consume" {
            let target = (resetIdx + 2 < args.count && !args[resetIdx + 2].hasPrefix("-")) ? args[resetIdx + 2] : nil
            let autoConfirm = args.contains("--yes") || args.contains("-y")
            await handleConsumeBankedReset(target: target, autoConfirm: autoConfirm)
            return
        }

        if subArg == "clear" || subArg == "--clear" {
            analytics.clearResets()
            print("\n" + green("✓") + " Quota reset history cleared (~/.config/seeusage/resets.json deleted).\n")
            return
        }

        if subArg == "seed" || subArg == "--seed" {
            FileHandle.standardError.write(Data("Demo quota data is no longer supported; SeeUsage records real usage as it refreshes.\n".utf8))
            return
        }

        if subArg == "gui" || subArg == "--gui" {
            print("Reset details are available in the terminal. Run 'seeusage resets'.\n")
            return
        }

        if subArg == "csv" || subArg == "--csv" {
            print(analytics.exportResetsCSV())
            return
        }

        // Ensure we have active snapshots to calculate upcoming resets
        let store = UsageStore.shared
        store.loadCache()
        await store.refresh(forceAfterCurrent: true)

        let upcoming = analytics.computeUpcomingResets(from: store.snapshots)
        let history = analytics.getResetEvents(limit: 20)

        if subArg == "json" || subArg == "--json" || args.contains("--json") {
            let iso = ISO8601DateFormatter()
            let upcomingPayload: [[String: Any]] = upcoming.map { u in
                [
                    "profileName": u.profileName,
                    "service": u.service,
                    "scope": jsonValue(u.scope),
                    "windowLabel": u.windowLabel,
                    "remainingPercent": jsonValue(u.currentRemainingPercent),
                    "resetsAt": iso.string(from: u.resetsAt),
                    "secondsUntilReset": max(0, Int(round(u.secondsUntilReset))),
                    "resetHuman": Formatters.resetDescription(for: u.resetsAt)
                ]
            }
            let historyPayload = history.map { h in
                [
                    "timestamp": iso.string(from: h.timestamp),
                    "profileName": h.profileName,
                    "service": h.service,
                    "scope": jsonValue(h.scope),
                    "windowLabel": h.windowLabel,
                    "quotaBefore": h.quotaBefore,
                    "quotaAfter": h.quotaAfter,
                    "quotaRestored": h.quotaRestored,
                    "nextResetAt": jsonValue(h.nextResetAt.map { iso.string(from: $0) })
                ]
            }
            let bankedPayload = analytics.getAvailableBankedCredits(
                from: store.snapshots,
                profiles: SettingsStore.shared.codexProfiles
            ).map { b -> [String: Any] in
                var payload: [String: Any] = [
                    "profileName": b.profile.name,
                    "title": jsonValue(b.credit.title),
                    "status": b.credit.status,
                    "expiresAt": jsonValue(b.credit.expiresAt.map { iso.string(from: $0) })
                ]
                if let serverID = b.credit.serverCreditID { payload["creditId"] = serverID }
                return payload
            }
            let full: [String: Any] = [
                "upcomingResets": upcomingPayload,
                "bankedResets": bankedPayload,
                "resetHistory": historyPayload
            ]
            if let data = try? JSONSerialization.data(withJSONObject: full, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
            return
        }

        // Default: Formatted Terminal Dashboard for Resets
        printResetsDashboard(upcoming: upcoming, history: history)
    }

    // MARK: - Consume Banked Reset
    static func handleConsumeBankedReset(target: String?, autoConfirm: Bool) async {
        let store = UsageStore.shared
        let settings = SettingsStore.shared
        store.loadCache()
        await store.refresh(forceAfterCurrent: true)

        let bankedCredits = AnalyticsManager.shared.getAvailableBankedCredits(
            from: store.snapshots,
            profiles: settings.codexProfiles
        )

        if bankedCredits.isEmpty {
            print("\n" + red("✗") + " No banked resets available on any configured Codex profile.\n")
            return
        }

        // Select a profile first; multiple credits on the same profile are interchangeable
        // for activation, so use the one that expires first.
        let eligibleCredits: [(profile: UsageProfile, credit: BankedResetCredit)]
        if let target {
            let query = target.lowercased()
            let matchingProfiles = settings.codexProfiles.filter { profile in
                let name = profile.name.lowercased()
                let alias = CLIHandler.profileAlias(for: profile, among: settings.codexProfiles)
                return alias == query || name == query || name.contains(query)
            }
            guard matchingProfiles.count == 1, let matchingProfile = matchingProfiles.first else {
                if matchingProfiles.count > 1 {
                    print("\n" + amber("That profile name matches more than one account. Use a unique alias:"))
                    for profile in matchingProfiles {
                        print("  seeusage resets consume \(CLIHandler.profileAlias(for: profile, among: settings.codexProfiles))  (\(profile.name))")
                    }
                    print("")
                    return
                }
                print("\n" + red("✗") + " No available banked reset found matching '\(target)'.\n")
                return
            }
            eligibleCredits = bankedCredits.filter { $0.profile.id == matchingProfile.id }
        } else {
            let profilesWithCredits = settings.codexProfiles.filter { profile in
                bankedCredits.contains(where: { $0.profile.id == profile.id })
            }
            guard profilesWithCredits.count == 1, let onlyProfile = profilesWithCredits.first else {
                print("\n" + amber("Multiple profiles have banked resets. Please specify a profile:"))
                for profile in profilesWithCredits {
                    print("  seeusage resets consume \(CLIHandler.profileAlias(for: profile, among: settings.codexProfiles))  (\(profile.name))")
                }
                print("")
                return
            }
            eligibleCredits = bankedCredits.filter { $0.profile.id == onlyProfile.id }
        }

        guard let targetItem = eligibleCredits.sorted(by: { lhs, rhs in
            switch (lhs.credit.expiresAt, rhs.credit.expiresAt) {
            case let (left?, right?): return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.credit.id < rhs.credit.id
            }
        }).first else {
            print("\n" + red("✗") + " No available banked reset found matching \'\(target ?? "")\'.\n")
            return
        }

        let prof = targetItem.profile
        let credit = targetItem.credit
        let title = credit.title ?? "Available reset credit"

        print("\n" + bold(amber("⚡ BANKED RESET ACTIVATION")))
        print("  Profile: " + bold(prof.name))
        print("  Credit:  " + bold(title))
        if let exp = credit.expiresAt {
            print("  Expires: " + dim(Formatters.dayMonthTime(exp)) + " " + dim("(\(Formatters.resetDescription(for: exp).lowercased()))"))
        }
        print("\n" + bold("This will immediately use one credit to reset eligible Codex quota windows."))

        if !autoConfirm {
            print("Proceed with activation? [y/N]: ", terminator: "")
            fflush(stdout)
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  line == "y" || line == "yes" else {
                print(dim("\nActivation canceled.\n"))
                return
            }
        }

        print(dim("\nConnecting to Codex app-server to consume credit..."))
        let res = await store.consumeBankedReset(for: prof, creditId: credit.serverCreditID)

        if res.success {
            print("\n" + bold(green("✓ \(res.message)")))
            printTable(store: store, settings: settings)
        } else {
            print("\n" + bold(red("✗ \(res.message)\n")))
        }
    }

    private static func printResetsDashboard(upcoming: [UpcomingResetInfo], history: [ResetEvent]) {
        print("\n" + bold(cyan("// ACTIVE & UPCOMING QUOTA RESETS")))
        print("")

        // Banked Resets Section (On-Demand Refills)
        let settings = SettingsStore.shared
        let store = UsageStore.shared
        let banked = AnalyticsManager.shared.getAvailableBankedCredits(
            from: store.snapshots,
            profiles: settings.codexProfiles
        )

        if !banked.isEmpty {
            print("  " + bold(amber("⚡ BANKED RESETS (ON-DEMAND REFILLS / ATIVAÇÃO MANUAL)")))
            print("  " + dim(String(repeating: "─", count: 74)))
            for b in banked {
                let alias = CLIHandler.profileAlias(for: b.profile, among: settings.codexProfiles)
                let title = b.credit.title ?? "Full reset"
                let planName = (store.snapshots[b.profile.id]?.plan ?? "Plus").capitalized

                let expStr: String
                if let exp = b.credit.expiresAt {
                    expStr = "expires on \(Formatters.dayMonth(exp))"
                } else {
                    expStr = "no expiration"
                }
                print("  " + amber("⚡ [codex] \(b.profile.name)") + " " + cyan("[\(planName)]") + " " + bold(title) + " " + dim("• \(expStr)"))
                print("    " + dim("Activate with: ") + bold(green("seeusage resets consume \(alias)")))
            }
            print("")
        }

        // Filter out past resets older than 5 minutes
        let activeUpcoming = upcoming.filter { $0.resetsAt > Date().addingTimeInterval(-300) }

        if activeUpcoming.isEmpty {
            print("  " + dim("No active renewal schedules detected (run `seeusage -r` to sync live rate limits)."))
        } else {
            let hService = "SERVICE / PROFILE".padding(toLength: 20, withPad: " ", startingAt: 0)
            let hWindow = "WINDOW".padding(toLength: 8, withPad: " ", startingAt: 0)
            let hQuota = "REMAINING".padding(toLength: 10, withPad: " ", startingAt: 0)
            let hResetAt = "SCHEDULED RESET".padding(toLength: 16, withPad: " ", startingAt: 0)
            let hCountdown = "COUNTDOWN"
            print("  " + bold(dim("\(hService) \(hWindow) \(hQuota) \(hResetAt) \(hCountdown)")))
            print("  " + dim(String(repeating: "─", count: 74)))

            for u in activeUpcoming {
                let tagStr = u.service == "Antigravity" ? "[agy]" : "[cx]"
                let namePart: String
                if u.service == "Antigravity" {
                    if let sc = u.scope {
                        namePart = sc.lowercased().contains("gemini") ? "Gemini" : "Claude/GPT"
                    } else {
                        namePart = "Antigravity"
                    }
                } else {
                    namePart = u.profileName
                }
                let rawFull = "\(tagStr) \(namePart)".padding(toLength: 20, withPad: " ", startingAt: 0)
                let sCol = u.service == "Antigravity"
                    ? rawFull.replacingOccurrences(of: "[agy]", with: purple("[agy]"))
                    : rawFull.replacingOccurrences(of: "[cx]", with: green("[cx]"))

                let wCol = u.windowLabel.padding(toLength: 8, withPad: " ", startingAt: 0)

                let pctStr = u.currentRemainingPercent.map { String(format: "%3.0f%%", $0) } ?? " --%"
                let paddedPct = pctStr.padding(toLength: 10, withPad: " ", startingAt: 0)
                let colorFn = quotaColor(for: u.currentRemainingPercent)
                let qCol = bold(colorFn(paddedPct))

                let dateStr = Formatters.dayMonthTime(u.resetsAt).padding(toLength: 16, withPad: " ", startingAt: 0)

                let countdown = bold(cyan(WatchDashboard.countdownString(until: u.resetsAt)))

                print("  \(sCol) \(dim(wCol)) \(qCol) \(dim(dateStr)) \(countdown)")
            }
        }

        print("")
        print(bold(cyan("// RECENT RESET AUDIT LOG (HISTÓRICO DE RESETS)")))
        print("")

        if history.isEmpty {
            print("  " + dim("No reset events logged yet."))
            print("  " + dim("SeeUsage detects resets automatically when quota renews or scheduled cycles elapse."))
            print("  " + dim("Reset events are recorded from real quota changes when SeeUsage refreshes."))
        } else {
            let hDate = "EVENT TIME".padding(toLength: 17, withPad: " ", startingAt: 0)
            let hProf = "PROFILE".padding(toLength: 16, withPad: " ", startingAt: 0)
            let hWin = "WINDOW".padding(toLength: 8, withPad: " ", startingAt: 0)
            let hJump = "QUOTA RESTORATION".padding(toLength: 20, withPad: " ", startingAt: 0)
            let hStatus = "STATUS"
            print("  " + bold(dim("\(hDate) \(hProf) \(hWin) \(hJump) \(hStatus)")))
            print("  " + dim(String(repeating: "─", count: 74)))

            for h in history {
                let timeStr = Formatters.dayMonthTime(h.timestamp).padding(toLength: 17, withPad: " ", startingAt: 0)
                let tagStr = h.service == "Antigravity" ? "[agy]" : "[cx]"
                let rawProf = "\(tagStr) \(h.profileName)".padding(toLength: 16, withPad: " ", startingAt: 0)
                let profStr = h.service == "Antigravity"
                    ? rawProf.replacingOccurrences(of: "[agy]", with: purple("[agy]"))
                    : rawProf.replacingOccurrences(of: "[cx]", with: green("[cx]"))

                let winStr = h.windowLabel.padding(toLength: 8, withPad: " ", startingAt: 0)
                let jumpStr = String(format: "%3.0f%% ➔ %3.0f%% (+%.0f%%)", h.quotaBefore, h.quotaAfter, h.quotaRestored)
                    .padding(toLength: 20, withPad: " ", startingAt: 0)
                let statusStr = green("✓ Restored")

                print("  \(dim(timeStr)) \(profStr) \(dim(winStr)) \(bold(cyan(jumpStr))) \(statusStr)")
            }
        }

        print("")
        print(dim("  Commands:"))
        print(dim("    seeusage resets json         Export upcoming and history as JSON"))
        print(dim("    seeusage resets csv          Export reset history as CSV"))
        print(dim("    seeusage resets clear        Clear recorded reset history"))
        print("")
    }

}
