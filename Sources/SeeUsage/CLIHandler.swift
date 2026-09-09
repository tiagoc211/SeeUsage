import Foundation

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
                } else if snap.error != nil {
                    segments.append("\(alias): \(dim("!"))")
                }
            }
        }

        // Antigravity (Gemini primary)
        let agyID = SettingsStore.antigravityProfileID
        if let agySnap = store.snapshots[agyID] {
            let windows = agySnap.windows
            let gemini5h = windows.first(where: { ($0.scope ?? "").contains("Gemini") && $0.label == "5h" }) ?? windows.first
            if let g = gemini5h, let pct = g.remainingPercent {
                let col = quotaColor(for: pct)
                segments.append("agy: \(col("\(Int(round(pct)))%"))")
            }
        }

        if segments.isEmpty {
            print(dim("seeusage: no data"))
        } else {
            print(segments.joined(separator: dim(" | ")))
        }
    }

    // MARK: - Table Output
    private static func printTable(store: UsageStore, settings: SettingsStore) {
        print("")
        print(bold("\(green("$")) seeusage --status"))
        print(dim("------------------------------------------------------------"))

        // Codex Section
        print(bold(cyan("CODEX PROFILES [CLI]")))
        if settings.codexProfiles.isEmpty {
            print(dim("  No Codex profiles configured."))
        } else {
            for profile in settings.codexProfiles {
                let alias = profileAlias(name: profile.name)
                let snap = store.snapshots[profile.id]
                let planTag = snap?.plan.map { "[\($0.lowercased())]" } ?? ""

                print("  \(cyan("$")) \(bold(alias)) \(dim("(\(profile.name))")) \(cyan(planTag))")

                if let err = snap?.error, snap?.windows.isEmpty ?? true {
                    print("    \(amber("Error:")) \(err)")
                } else if let windows = snap?.windows, !windows.isEmpty {
                    for w in windows {
                        printQuotaBar(label: w.label, pct: w.remainingPercent, reset: w.resetsAt)
                    }
                } else {
                    print(dim("    Connecting to codex app-server..."))
                }
                print("")
            }
        }

        // Antigravity Section
        print(bold(purple("ANTIGRAVITY [AGY]")))
        let agyID = SettingsStore.antigravityProfileID
        if let agySnap = store.snapshots[agyID] {
            let grouped = Dictionary(grouping: agySnap.windows) { $0.scope ?? "Antigravity" }
            let keys = grouped.keys.sorted { lhs, rhs in
                if lhs.contains("Gemini") { return true }
                if rhs.contains("Gemini") { return false }
                return lhs < rhs
            }

            for scope in keys {
                let badge = scopeBadge(scope: scope)
                print("  \(purple("$")) \(bold("agy")) \(badge)")
                for w in grouped[scope] ?? [] {
                    printQuotaBar(label: w.label, pct: w.remainingPercent, reset: w.resetsAt)
                }
                print("")
            }

            if let err = agySnap.error {
                print("  \(amber("Warning:")) \(err)")
                print("")
            }
        } else {
            print(dim("  Polling antigravity usage..."))
            print("")
        }

        print(dim("------------------------------------------------------------"))
        if let minQuota = store.minRemainingPercent {
            let col = quotaColor(for: Double(minQuota))
            print("Status: \(green("connected")) | Min quota: \(col("\(minQuota)%")) | Last updated: \(dim(Formatters.relativeUpdated(for: store.lastUpdated)))")
        }
        print("")
    }

    private static func printQuotaBar(label: String, pct: Double?, reset: Date?) {
        let tag = label.lowercased().padding(toLength: 4, withPad: " ", startingAt: 0)
        let percentVal = pct.map { Int(round($0)) }
        let pctStr = percentVal.map { String(format: "%3d%%", $0) } ?? " --%"
        let col = quotaColor(for: pct)

        // Progress bar (20 blocks)
        let width = 20
        let filledCount: Int
        if let p = pct {
            filledCount = max(0, min(width, Int(round(Double(width) * (p / 100.0)))))
        } else {
            filledCount = 0
        }
        let emptyCount = width - filledCount
        let bar = col(String(repeating: "━", count: filledCount)) + dim(String(repeating: "━", count: emptyCount))

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

    // MARK: - Help Manual
    private static func printHelp() {
        print("""
        \(bold("seeusage")) - AI Quota Monitor for Codex & Antigravity

        \(bold("USAGE:"))
          seeusage [options]
          seeusage --mini
          seeusage --export <profile>
          seeusage --json

        \(bold("OPTIONS:"))
          -m, --mini          Compact one-line output (ideal for Starship / Zsh RPROMPT / tmux)
          -c, --cached        Read instantaneous cached quota from ~/.config/seeusage/cache.json
          -r, --refresh       Force a live refresh against codex app-server and agy CLI
          -j, --json          Output full status and window rate limits as JSON
          --export <alias>    Output 'export CODEX_HOME=...' command (e.g. `seeusage --export cxp`)
          --shell-init [zsh]  Print shell functions and aliases to add to ~/.zshrc
          --no-color          Disable ANSI color codes
          -h, --help          Show this help message

        \(bold("EXAMPLES:"))
          $ seeusage                     # Full interactive dashboard table
          $ seeusage -m -c               # Instant prompt status: cxp: 2% (3h35m) | cxt: 92% | agy: 24%
          $ eval $(seeusage --export cxp)# Switch active shell to Codex Pessoal
          $ seeusage --json | jq .       # Inspect programmatic JSON metrics
        """)
    }

    // MARK: - Helpers
    public static func profileAlias(name: String) -> String {
        let low = name.lowercased()
        if low.contains("pessoal") { return "cxp" }
        if low.contains("trabalho") { return "cxt" }
        return low.replacingOccurrences(of: " ", with: "-")
    }

    private static func scopeBadge(scope: String) -> String {
        if scope.contains("Gemini") { return purple("[gemini]") }
        if scope.contains("Claude") { return amber("[claude]") }
        return green("[gpt]")
    }
}
