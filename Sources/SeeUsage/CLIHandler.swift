import Foundation
import AppKit

@MainActor
public enum CLIHandler {
    // MARK: - ANSI Color Helpers
    private static var useColor: Bool = true

    private static func color(_ code: String, _ text: String) -> String {
        guard useColor else { return text }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    private static func bold(_ text: String) -> String { color("1", text) }
    private static func dim(_ text: String) -> String { color("90", text) }
    private static func green(_ text: String) -> String { color("38;2;0;229;153", text) } // #00e599
    private static func amber(_ text: String) -> String { color("38;2;250;158;46", text) } // #fa9e2e
    private static func red(_ text: String) -> String { color("38;2;245;71;82", text) }    // #f54752
    private static func cyan(_ text: String) -> String { color("38;2;56;189;248", text) }  // #38bdf8
    private static func purple(_ text: String) -> String { color("38;2;168;119;250", text)}// #a877fa

    private static func quotaColor(for pct: Double?) -> (String) -> String {
        guard let p = pct else { return dim }
        if p <= 15 { return red }
        if p <= 35 { return amber }
        return green
    }

    // MARK: - Entry Point
    public static func handle(arguments: [String]) async -> Bool {
        // Strip executable path
        var args = Array(arguments.dropFirst())

        if args.contains("--no-color") {
            useColor = false
            args.removeAll { $0 == "--no-color" }
        }

        // Help
        if args.contains("-h") || args.contains("--help") {
            printHelp()
            return true
        }

        // Interactive TUI Watch Mode
        if args.contains("watch") || args.contains("--watch") || args.contains("-w") {
            await WatchDashboard.run()
            return true
        }

        // List themes
        if args.contains("themes") || args.contains("--themes") {
            printThemes()
            return true
        }

        // Set theme
        if let themeIdx = args.firstIndex(of: "theme") ?? args.firstIndex(of: "--theme") {
            if themeIdx + 1 < args.count {
                let themeID = args[themeIdx + 1]
                setTheme(id: themeID)
                return true
            } else {
                printThemes()
                return true
            }
        }

        // Menu Bar Display Mode
        if let modeIdx = args.firstIndex(of: "mode") ?? args.firstIndex(of: "--mode") {
            if modeIdx + 1 < args.count {
                let target = args[modeIdx + 1]
                setMenuBarMode(target)
                return true
            } else {
                printMenuBarModes()
                return true
            }
        }

        // Notification Settings & Testing
        if let notifIdx = args.firstIndex(of: "notify") ?? args.firstIndex(of: "--notify") {
            if notifIdx + 1 < args.count {
                let action = args[notifIdx + 1]
                handleNotifyCommand(action: action)
                return true
            } else {
                printNotifyStatus()
                return true
            }
        }

        // Floating Mini-HUD Desktop Widget
        if let hudIdx = args.firstIndex(of: "hud") ?? args.firstIndex(of: "--hud") {
            if hudIdx + 1 < args.count {
                let action = args[hudIdx + 1]
                handleHUDCommand(action: action)
                return true
            } else {
                printHUDStatus()
                return true
            }
        }

        // Open Settings Window
        if args.contains("settings") || args.contains("--settings") || args.contains("config") {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.openSettings"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            let appPath = NSString(string: "~/Applications/SeeUsage.app").expandingTildeInPath
            if FileManager.default.fileExists(atPath: appPath) {
                let url = URL(fileURLWithPath: appPath)
                _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            print("\n" + green("✓") + " Settings window opened.\n")
            return true
        }

        // Shell Init Script
        if let initIdx = args.firstIndex(of: "--shell-init") {
            let shell = initIdx + 1 < args.count ? args[initIdx + 1] : "zsh"
            printShellInit(shell: shell)
            return true
        }

        // Export CODEX_HOME
        if let expIdx = args.firstIndex(of: "--export") {
            let target = expIdx + 1 < args.count ? args[expIdx + 1] : ""
            handleExport(target: target)
            return true
        }

        let isMini = args.contains("--mini") || args.contains("-m")
        let isJSON = args.contains("--json") || args.contains("-j")
        let forceRefresh = args.contains("--refresh") || args.contains("-r")
        let useCached = args.contains("--cached") || args.contains("-c")

        let store = UsageStore.shared
        let settings = SettingsStore.shared

        // In mini mode, default to cached unless explicit refresh requested
        if isMini && !forceRefresh {
            store.loadCache()
            if store.snapshots.isEmpty {
                await store.refresh()
            }
        } else if useCached && !forceRefresh {
            store.loadCache()
            if store.snapshots.isEmpty {
                await store.refresh()
            }
        } else {
            // Live refresh
            await store.refresh()
        }

        if isJSON {
            printJSON(store: store, settings: settings)
            return true
        }

        if isMini {
            printMini(store: store, settings: settings)
            return true
        }

        // Default: Full Table Output
        printTable(store: store, settings: settings)
        return true
    }

    // MARK: - Themes CLI Support
    private static func printThemes() {
        let settings = SettingsStore.shared
        print("\n" + bold("// SEEUSAGE THEMES & PALETTES") + " (Dark Terminal Design System)\n")
        for category in ["Core Themes", "Developer Classics"] {
            print("  " + dim("// \(category.uppercased())"))
            let themes = ThemeRegistry.allThemes.filter { $0.category == category }
            for t in themes {
                let isCurrent = settings.selectedThemeID == t.id
                let mark = isCurrent ? green("[✓ ACTIVE]") : dim("[        ]")
                let idStr = cyan(t.id.padding(toLength: 14, withPad: " ", startingAt: 0))
                let nameStr = bold(t.name.padding(toLength: 16, withPad: " ", startingAt: 0))
                let tagStr = dim(t.tagline)
                print("    \(mark) \(idStr) \(nameStr) \(tagStr)")
            }
            print("")
        }
        print("  Use: " + bold("seeusage theme <id>") + " to activate a theme via terminal.")
        print("")
    }

    private static func setTheme(id: String) {
        let cleanID = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let theme = ThemeRegistry.theme(for: cleanID)
        SettingsStore.shared.selectTheme(theme.id)
        print("\n" + green("✓") + " Theme " + bold(theme.name) + " (\(theme.id)) activated successfully!\n")
    }

    // MARK: - Menu Bar Display Modes CLI
    private static func printMenuBarModes() {
        let settings = SettingsStore.shared
        print("\n" + bold("// SEEUSAGE MENU BAR DISPLAY MODES") + "\n")
        for mode in MenuBarDisplayMode.allCases {
            let isCurrent = settings.menuBarDisplayMode == mode
            let mark = isCurrent ? green("[✓ ACTIVE]") : dim("[        ]")
            let idStr = cyan(mode.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))
            let nameStr = bold(mode.title.padding(toLength: 16, withPad: " ", startingAt: 0))
            let subStr = dim(mode.subtitle)
            print("  \(mark) \(idStr) \(nameStr) \(subStr)")
        }
        print("\n  Use: " + bold("seeusage mode <id>") + " to change menu bar display style.\n")
    }

    private static func setMenuBarMode(_ target: String) {
        let clean = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resolvedMode: MenuBarDisplayMode?
        switch clean {
        case "percent", "lowest", "default":
            resolvedMode = .percent
        case "dual", "double", "split":
            resolvedMode = .dual
        case "gauge", "bar", "meter":
            resolvedMode = .gauge
        case "icon", "icononly", "dot":
            resolvedMode = .iconOnly
        default:
            resolvedMode = MenuBarDisplayMode(rawValue: clean)
        }

        guard let mode = resolvedMode else {
            print("\n" + red("✗") + " Unknown menu bar mode '" + target + "'. Available: percent, dual, gauge, iconOnly\n")
            return
        }

        SettingsStore.shared.selectMenuBarMode(mode)
        print("\n" + green("✓") + " Menu bar display style set to: " + bold(mode.title) + " (\(mode.rawValue))\n")
    }

    // MARK: - Mini Output (One-liner for Prompts)
    private static func printMini(store: UsageStore, settings: SettingsStore) {
        var segments: [String] = []

        // Codex Profiles
        for profile in settings.codexProfiles {
            let alias = profileAlias(name: profile.name)
            if let snap = store.snapshots[profile.id] {
                let windows = snap.windows
                let w5 = windows.first(where: { $0.label == "5h" }) ?? windows.first
                if let w = w5, let pct = w.remainingPercent {
                    let col = quotaColor(for: pct)
                    let resetStr: String
                    if let r = w.resetsAt {
                        let mins = max(0, Int(ceil(r.timeIntervalSince(Date()) / 60.0)))
                        if mins < 60 {
                            resetStr = " (\(mins)m)"
                        } else {
                            resetStr = " (\(mins / 60)h\(mins % 60)m)"
                        }
                    } else {
                        resetStr = ""
                    }
                    segments.append("\(alias): \(col("\(Int(round(pct)))%"))\(resetStr)")
                }
            }
        }

        // Antigravity (Gemini priority)
        if let agy = store.snapshots[SettingsStore.antigravityProfileID] {
            let geminiWindows = agy.windows.filter { $0.scope?.contains("Gemini") ?? false }
            let w5 = geminiWindows.first(where: { $0.label.contains("5") }) ?? geminiWindows.first ?? agy.windows.first
            if let w = w5, let pct = w.remainingPercent {
                let col = quotaColor(for: pct)
                segments.append("agy: \(col("\(Int(round(pct)))%"))")
            }
        }

        if segments.isEmpty {
            print("seeusage: --")
        } else {
            print(segments.joined(separator: " \(dim("|")) "))
        }
    }

    // MARK: - Full Table Dashboard Output
    private static func printTable(store: UsageStore, settings: SettingsStore) {
        let updatedTime: String
        if let d = store.lastUpdated {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            updatedTime = df.string(from: d)
        } else {
            updatedTime = "--:--:--"
        }

        print("\n" + bold("// SEEUSAGE") + " \(dim("--live")) " + dim("[updated \(updatedTime)]") + "\n")

        // 1. CODEX PROFILES
        print(bold(cyan("// CODEX PROFILES")))
        if settings.codexProfiles.isEmpty {
            print("  " + dim("No profiles configured."))
        } else {
            for profile in settings.codexProfiles {
                let alias = profileAlias(name: profile.name)
                let snap = store.snapshots[profile.id]
                let planTag = snap?.plan.map { dim("[\($0.lowercased())]") } ?? ""

                print("  " + cyan("$ ") + bold(alias) + dim(" (\(profile.name))") + " \(planTag)")

                if let err = snap?.error, snap?.windows.isEmpty ?? true {
                    print("    " + amber("⚠ \(err)"))
                } else if let windows = snap?.windows, !windows.isEmpty {
                    for w in windows {
                        printWindowRow(label: w.label, percent: w.remainingPercent, reset: w.resetsAt)
                    }
                } else {
                    print("    " + dim("connecting..."))
                }
                print("")
            }
        }

        // 2. ANTIGRAVITY (AGY)
        print(bold(purple("// ANTIGRAVITY (AGY)")))
        let agySnap = store.snapshots[SettingsStore.antigravityProfileID]
        if let err = agySnap?.error, agySnap?.windows.isEmpty ?? true {
            print("  " + amber("⚠ \(err)"))
        } else if let snapshot = agySnap, !snapshot.windows.isEmpty {
            let grouped = Dictionary(grouping: snapshot.windows) { $0.scope ?? "Antigravity" }
            let keys = grouped.keys.sorted { lhs, rhs in
                if lhs.contains("Gemini") { return true }
                if rhs.contains("Gemini") { return false }
                return lhs < rhs
            }

            for scope in keys {
                let badge = scopeBadge(scope: scope)
                print("  " + purple("$ ") + bold("agy") + " \(badge)")
                if let windows = grouped[scope] {
                    for w in windows {
                        printWindowRow(label: w.label, percent: w.remainingPercent, reset: w.resetsAt)
                    }
                }
                print("")
            }
        } else {
            print("  " + dim("fetching metrics..."))
            print("")
        }

        // Footer Summary
        if let minPct = store.minRemainingPercent {
            let col = quotaColor(for: Double(minPct))
            print(dim("--------------------------------------------------"))
            print(dim("Lowest Quota: ") + col("\(minPct)%"))
        }
        print("")
    }

    private static func printWindowRow(label: String, percent: Double?, reset: Date?) {
        let tag = label.lowercased().padding(toLength: 10, withPad: " ", startingAt: 0)
        let pctStr: String
        let col = quotaColor(for: percent)

        if let p = percent {
            pctStr = String(format: "%3d%%", Int(round(p)))
        } else {
            pctStr = " --%"
        }

        let clamped = max(0.0, min(100.0, percent ?? 0.0))
        let totalBlocks = 16
        let filledBlocks = Int(round((clamped / 100.0) * Double(totalBlocks)))
        let emptyBlocks = totalBlocks - filledBlocks

        let bar = col(String(repeating: "■", count: filledBlocks)) + dim(String(repeating: "□", count: emptyBlocks))

        let resetStr: String
        if let r = reset {
            resetStr = dim("(\(Formatters.resetDescription(for: r).lowercased()))")
        } else {
            resetStr = ""
        }

        print("    \(dim(tag)) \(col(pctStr)) [\(bar)] \(resetStr)")
    }

    // MARK: - JSON Output
    private static func printJSON(store: UsageStore, settings: SettingsStore) {
        struct JSONWindow: Codable {
            let label: String
            let remainingPercent: Double?
            let resetsAt: String?
            let resetHuman: String?
        }

        struct JSONProfile: Codable {
            let alias: String
            let name: String
            let homePath: String?
            let plan: String?
            let error: String?
            let windows: [JSONWindow]
        }

        struct JSONOutput: Codable {
            let timestamp: String
            let minRemainingPercent: Int?
            let codexProfiles: [JSONProfile]
            let antigravityWindows: [JSONWindow]
        }

        let iso = ISO8601DateFormatter()
        var codexList: [JSONProfile] = []

        for p in settings.codexProfiles {
            let snap = store.snapshots[p.id]
            let windows = snap?.windows ?? []
            let winList = windows.map { w in
                JSONWindow(
                    label: w.label,
                    remainingPercent: w.remainingPercent,
                    resetsAt: w.resetsAt.map { iso.string(from: $0) },
                    resetHuman: w.resetsAt.map { Formatters.resetDescription(for: $0) }
                )
            }
            codexList.append(JSONProfile(
                alias: profileAlias(name: p.name),
                name: p.name,
                homePath: p.homePath,
                plan: snap?.plan,
                error: snap?.error,
                windows: winList
            ))
        }

        let agySnap = store.snapshots[SettingsStore.antigravityProfileID]
        let agyWindows = agySnap?.windows ?? []
        let agyList = agyWindows.map { w in
            JSONWindow(
                label: "\(w.scope ?? "AGY") \(w.label)",
                remainingPercent: w.remainingPercent,
                resetsAt: w.resetsAt.map { iso.string(from: $0) },
                resetHuman: w.resetsAt.map { Formatters.resetDescription(for: $0) }
            )
        }

        let output = JSONOutput(
            timestamp: iso.string(from: store.lastUpdated ?? Date()),
            minRemainingPercent: store.minRemainingPercent,
            codexProfiles: codexList,
            antigravityWindows: agyList
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    // MARK: - Export Helper
    private static func handleExport(target: String) {
        let settings = SettingsStore.shared
        let clean = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for p in settings.codexProfiles {
            let alias = profileAlias(name: p.name)
            if clean == alias || clean == p.name.lowercased() {
                if let path = p.homePath {
                    print("export CODEX_HOME=\"\(path)\"")
                    return
                } else {
                    print("unset CODEX_HOME")
                    return
                }
            }
        }

        let aliases = settings.codexProfiles.map { profileAlias(name: $0.name) }.joined(separator: ", ")
        FileHandle.standardError.write(Data("Unknown profile '\(target)'. Available: \(aliases)\n".utf8))
        exit(1)
    }

    // MARK: - Shell Init Snippet
    private static func printShellInit(shell: String) {
        let settings = SettingsStore.shared
        var switches: [String] = []
        for p in settings.codexProfiles {
            let alias = profileAlias(name: p.name)
            if let path = p.homePath {
                switches.append("""
                \(alias)() {
                  export CODEX_HOME="\(path)"
                  codex "$@"
                }
                """)
            }
        }

        print("""
        # ==============================================================================
        # SeeUsage Shell Integration (Add this to your ~/.zshrc or ~/.bashrc)
        # ==============================================================================

        # Quick prompt quota helper (runs in <5ms using local cached state)
        seeusage_prompt() {
          seeusage --mini --cached 2>/dev/null
        }

        # Context switchers
        \(switches.joined(separator: "\n"))

        # Example Starship custom module (add to ~/.config/starship.toml):
        # [custom.seeusage]
        # command = "seeusage --mini --cached --no-color"
        # when = "true"
        # format = "[$output]($style) "
        # style = "bold cyan"
        """)
    }

    // MARK: - Floating Mini-HUD Controls
    private static func printHUDStatus() {
        let s = SettingsStore.shared
        let enabledStr = s.hudEnabled ? green("VISIBLE") : dim("HIDDEN")
        let modeStr = s.hudCompactMode ? cyan("COMPACT PILL") : bold("DETAILED CARD")
        let pinStr = s.hudAlwaysOnTop ? green("ALWAYS ON TOP") : dim("DESKTOP LEVEL")
        let opacityPct = Int(round(s.hudOpacity * 100))

        print("""

\(bold("// SEEUSAGE DESKTOP MINI-HUD"))

  Widget Status:       \(enabledStr)
  Display Mode:        \(modeStr)
  Window Layer:        \(pinStr)
  Opacity:             \(bold("\(opacityPct)%"))

  Usage:
    seeusage hud toggle         Toggle desktop HUD visibility on/off
    seeusage hud on             Show floating desktop HUD
    seeusage hud off            Hide floating desktop HUD
    seeusage hud compact        Switch HUD to compact pill layout
    seeusage hud full           Switch HUD to detailed card layout
    seeusage hud pin            Pin HUD always on top
    seeusage hud unpin          Set HUD to normal desktop window level
    seeusage hud <40-100>       Set frosted background opacity percentage

""")
    }

    private static func handleHUDCommand(action: String) {
        let s = SettingsStore.shared
        let dist = DistributedNotificationCenter.default()

        switch action.lowercased() {
        case "toggle":
            s.hudEnabled.toggle()
            dist.postNotificationName(
                NSNotification.Name("app.seeusage.toggleHUD"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            let status = s.hudEnabled ? green("Visible") : dim("Hidden")
            print("\n" + green("✓") + " Floating Desktop HUD: \(status)\n")

        case "on", "show", "open", "1":
            s.hudEnabled = true
            dist.postNotificationName(
                NSNotification.Name("app.seeusage.showHUD"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            ensureAppRunning()
            print("\n" + green("✓") + " Floating Desktop HUD opened.\n")

        case "off", "hide", "close", "0":
            s.hudEnabled = false
            dist.postNotificationName(
                NSNotification.Name("app.seeusage.hideHUD"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            print("\n" + green("✓") + " Floating Desktop HUD hidden.\n")

        case "compact", "pill", "mini":
            s.hudCompactMode = true
            print("\n" + green("✓") + " Floating HUD switched to \(cyan("Compact Pill")) mode.\n")

        case "full", "card", "expand", "detailed":
            s.hudCompactMode = false
            print("\n" + green("✓") + " Floating HUD switched to \(bold("Detailed Card")) mode.\n")

        case "pin", "top":
            s.hudAlwaysOnTop = true
            print("\n" + green("✓") + " Floating HUD pinned \(green("Always on Top")).\n")

        case "unpin", "normal", "desktop":
            s.hudAlwaysOnTop = false
            print("\n" + green("✓") + " Floating HUD set to \(dim("Normal Desktop Level")).\n")

        default:
            if let num = Double(action), num >= 10, num <= 100 {
                let opacity = num / 100.0
                s.hudOpacity = opacity
                print("\n" + green("✓") + " Floating HUD opacity set to \(bold("\(Int(round(num)))%")).\n")
            } else if let num = Double(action), num >= 0.1, num <= 1.0 {
                s.hudOpacity = num
                print("\n" + green("✓") + " Floating HUD opacity set to \(bold("\(Int(round(num * 100)))%")).\n")
            } else {
                print("\n" + red("Error:") + " Unknown HUD argument '\(action)'. Use 'toggle', 'on', 'off', 'compact', 'full', 'pin', 'unpin', or an opacity like '85'.\n")
            }
        }
    }

    private static func ensureAppRunning() {
        let appPath = NSString(string: "~/Applications/SeeUsage.app").expandingTildeInPath
        if FileManager.default.fileExists(atPath: appPath) {
            let url = URL(fileURLWithPath: appPath)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }

    // MARK: - Notification Controls
    private static func printNotifyStatus() {
        let s = SettingsStore.shared
        let enabledStr = s.notificationsEnabled ? green("ENABLED") : dim("DISABLED")
        let critStr = s.notifyOnCritical ? green("ON") : dim("OFF")
        let resetStr = s.notifyOnReset ? green("ON") : dim("OFF")
        let soundStr = s.notificationSoundEnabled ? green("ON") : dim("OFF")

        print("""

\(bold("// SEEUSAGE NOTIFICATION SETTINGS"))

  System Notifications:   \(enabledStr)
  Critical Quota Alert:   \(critStr) (threshold: \(bold("\(s.criticalThresholdPercent)%")))
  Quota Restored Alert:   \(resetStr)
  Alert Sound:            \(soundStr)

  Usage:
    seeusage notify test          Send an instant test notification
    seeusage notify on            Enable system notifications
    seeusage notify off           Disable system notifications
    seeusage notify <threshold>   Set critical threshold percentage (e.g. `seeusage notify 10`)

""")
    }

    private static func handleNotifyCommand(action: String) {
        let s = SettingsStore.shared
        switch action.lowercased() {
        case "test":
            NotificationManager.shared.sendTestNotification()
            print("\n" + green("✓") + " Test notification dispatched to macOS.\n")

        case "on", "enable", "1":
            s.notificationsEnabled = true
            print("\n" + green("✓") + " Native notifications enabled.\n")

        case "off", "disable", "0":
            s.notificationsEnabled = false
            print("\n" + green("✓") + " Native notifications disabled.\n")

        default:
            if let num = Int(action), num >= 1, num <= 90 {
                s.criticalThresholdPercent = num
                print("\n" + green("✓") + " Critical quota alert threshold set to \(bold("\(num)%")).\n")
            } else {
                print("\n" + red("Error:") + " Unknown notification argument '\(action)'. Use 'test', 'on', 'off', or a percentage number like '10'.\n")
            }
        }
    }

    // MARK: - Help Manual
    private static func printHelp() {
        print("""
        \(bold("seeusage")) - AI Quota Monitor for Codex & Antigravity

        \(bold("USAGE:"))
          seeusage [options]
          seeusage watch
          seeusage settings
          seeusage themes
          seeusage theme <id>
          seeusage mode [id]
          seeusage hud [toggle|on|off|compact|full]
          seeusage notify [test|on|off|<threshold>]
          seeusage --mini
          seeusage --export <profile>
          seeusage --json

        \(bold("OPTIONS:"))
          watch, -w           Live interactive terminal dashboard with countdown to the second
          -m, --mini          Compact one-line output (ideal for Starship / Zsh RPROMPT / tmux)
          -c, --cached        Read instantaneous cached quota from ~/.config/seeusage/cache.json
          -r, --refresh       Force a live refresh against codex app-server and agy CLI
          -j, --json          Output full status and window rate limits as JSON
          settings, config    Open SeeUsage settings window directly
          themes, --themes    List all available terminal and developer themes
          theme <id>          Set active theme by ID (e.g. `seeusage theme ocean`)
          mode [id]           Set or list menu bar display style (percent, dual, gauge, iconOnly)
          hud [action]        Control floating desktop HUD widget (toggle, compact, pin, etc.)
          notify [action]     Manage notification alerts or dispatch test notification
          --export <alias>    Output 'export CODEX_HOME=...' command (e.g. `seeusage --export cxp`)
          --shell-init [zsh]  Print shell functions and aliases to add to ~/.zshrc
          --no-color          Disable ANSI color codes
          -h, --help          Show this help message

        \(bold("EXAMPLES:"))
          $ seeusage                     # Full interactive dashboard table
          $ seeusage watch               # Real-time interactive TUI with live second countdown
          $ seeusage settings            # Open settings window with theme picker
          $ seeusage themes              # Show all themes (Emerald, Ocean, Grove, etc.)
          $ seeusage theme grove         # Activate Grove theme
          $ seeusage mode dual           # Switch menu bar to Dual Quotas mode
          $ seeusage -m -c               # Instant prompt status: cxp: 2% (3h35m) | cxt: 92% | agy: 24%
          $ eval $(seeusage --export cxp)# Switch active shell to Codex Pessoal
          $ seeusage --json | jq .       # Inspect programmatic JSON metrics
        """)
    }

    // MARK: - Helpers
    public static func profileAlias(name: String) -> String {
        let low = name.lowercased()
        if low.contains("pessoal") || low.contains("personal") { return "cxp" }
        if low.contains("trabalho") || low.contains("work") { return "cxt" }
        return low.replacingOccurrences(of: " ", with: "-")
    }

    private static func scopeBadge(scope: String) -> String {
        if scope.contains("Gemini") { return purple("[gemini]") }
        if scope.contains("Claude") { return amber("[claude]") }
        return green("[gpt]")
    }
}
