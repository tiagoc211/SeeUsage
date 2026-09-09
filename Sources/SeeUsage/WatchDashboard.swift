import Foundation
import Darwin

@MainActor
public enum WatchDashboard {
    // MARK: - Run Interactive Watch Loop
    public static func run() async {
        let isTTY = isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0

        // If not running in an interactive TTY (e.g. piped), do a single live print
        guard isTTY else {
            let store = UsageStore.shared
            await store.refresh()
            print(renderFrame(store: store, settings: SettingsStore.shared, isRefreshing: false))
            return
        }

        // Set up raw terminal mode
        var originalTermios = termios()
        tcgetattr(STDIN_FILENO, &originalTermios)

        var raw = originalTermios
        raw.c_lflag &= ~UInt(ECHO | ICANON)
        raw.c_cc.16 = 0 // VMIN = 0 (non-blocking read)
        raw.c_cc.17 = 1 // VTIME = 1 (100ms timeout)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        // Enter alternate screen buffer and hide cursor
        print("\u{001B}[?1049h\u{001B}[?25l", terminator: "")
        fflush(stdout)

        // Register SIGINT handler to ensure terminal restoration
        signal(SIGINT) { _ in
            print("\u{001B}[?25h\u{001B}[?1049l", terminator: "")
            fflush(stdout)
            exit(0)
        }

        defer {
            // Restore terminal
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
            print("\u{001B}[?25h\u{001B}[?1049l", terminator: "")
            fflush(stdout)
        }

        let store = UsageStore.shared
        let settings = SettingsStore.shared

        var isRefreshing = false
        var lastRefreshTime = Date()
        var shouldExit = false
        var statusNotice = ""
        var noticeUntil = Date()

        // Initial background refresh if empty
        if store.snapshots.isEmpty {
            isRefreshing = true
            Task {
                await store.refresh()
                isRefreshing = false
            }
        }

        while !shouldExit {
            // Clear status notice if expired
            if Date() > noticeUntil {
                statusNotice = ""
            }

            // Render zero-flicker frame
            let frame = renderFrame(
                store: store,
                settings: settings,
                isRefreshing: isRefreshing,
                notice: statusNotice
            )

            // Cursor home + print frame + clear to end of screen
            print("\u{001B}[H" + frame + "\u{001B}[J", terminator: "")
            fflush(stdout)

            // Read keyboard input non-blockingly (up to 100ms)
            var byte: UInt8 = 0
            let bytesRead = read(STDIN_FILENO, &byte, 1)

            if bytesRead > 0 {
                switch byte {
                case 113, 81, 3, 27: // 'q', 'Q', Ctrl+C (0x03), ESC (0x1B)
                    shouldExit = true

                case 114, 82: // 'r', 'R' (Refresh)
                    if !isRefreshing {
                        isRefreshing = true
                        statusNotice = "Refreshing metrics from Codex & Antigravity..."
                        noticeUntil = Date().addingTimeInterval(3.5)
                        Task {
                            await store.refresh()
                            isRefreshing = false
                            lastRefreshTime = Date()
                            statusNotice = "Quotas refreshed successfully!"
                            noticeUntil = Date().addingTimeInterval(2.5)
                        }
                    }

                case 116, 84: // 't', 'T' (Cycle Theme)
                    let allThemes = ThemeRegistry.allThemes
                    if let currentIndex = allThemes.firstIndex(where: { $0.id == settings.selectedThemeID }) {
                        let nextTheme = allThemes[(currentIndex + 1) % allThemes.count]
                        settings.selectTheme(nextTheme.id)
                        statusNotice = "Theme: \(nextTheme.name)"
                        noticeUntil = Date().addingTimeInterval(2.0)
                    } else if let first = allThemes.first {
                        settings.selectTheme(first.id)
                    }

                case 109, 77: // 'm', 'M' (Cycle Menu Bar Mode)
                    let allModes = MenuBarDisplayMode.allCases
                    if let currentIndex = allModes.firstIndex(of: settings.menuBarDisplayMode) {
                        let nextMode = allModes[(currentIndex + 1) % allModes.count]
                        settings.selectMenuBarMode(nextMode)
                        statusNotice = "Menu Bar Mode: \(nextMode.title)"
                        noticeUntil = Date().addingTimeInterval(2.0)
                    }

                default:
                    break
                }
            } else {
                // Auto refresh check every interval minutes
                let intervalSeconds = Double(settings.refreshIntervalMinutes * 60)
                if Date().timeIntervalSince(lastRefreshTime) >= intervalSeconds && !isRefreshing {
                    isRefreshing = true
                    Task {
                        await store.refresh()
                        isRefreshing = false
                        lastRefreshTime = Date()
                    }
                }
                // Sleep briefly (40ms) to reduce CPU while keeping countdown snappy
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }

    // MARK: - Frame Renderer (Zero Flicker)
    public static func renderFrame(
        store: UsageStore,
        settings: SettingsStore,
        isRefreshing: Bool,
        notice: String = ""
    ) -> String {
        let theme = settings.currentTheme
        let accentAnsi = ansiColor(hex: theme.accentHex)
        let secAnsi = ansiColor(hex: theme.secondaryHex)
        let resetAnsi = "\u{001B}[0m"
        let boldAnsi = "\u{001B}[1m"
        let dimAnsi = "\u{001B}[90m"

        var lines: [String] = []

        // Terminal width calculation
        var ws = winsize()
        let width: Int
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 40 {
            width = max(68, min(96, Int(ws.ws_col) - 2))
        } else {
            width = 76
        }

        // Top Border Box
        let titleBadge = " SEEUSAGE WATCH "
        let modeBadge = " [LIVE] "
        let topBarLen = max(0, width - 2 - titleBadge.count - modeBadge.count)
        let topBarLeft = String(repeating: "─", count: 4)
        let topBarRight = String(repeating: "─", count: max(0, topBarLen - 4))

        lines.append("\(accentAnsi)┌\(topBarLeft)\(boldAnsi)\(titleBadge)\(resetAnsi)\(accentAnsi)\(topBarRight)\(boldAnsi)\(modeBadge)\(resetAnsi)\(accentAnsi)┐\(resetAnsi)")

        // Header Info Row
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let updateTimeStr = store.lastUpdated.map { df.string(from: $0) } ?? "--:--:--"
        let statusStr = isRefreshing ? "\(boldAnsi)\u{001B}[33m⟳ REFRESHING...\(resetAnsi)" : "\(dimAnsi)idle\(resetAnsi)"

        let infoContent = " Theme: \(boldAnsi)\(theme.name)\(resetAnsi) │ Mode: \(dimAnsi)\(settings.menuBarDisplayMode.title)\(resetAnsi) │ Synced: \(dimAnsi)\(updateTimeStr)\(resetAnsi) │ Status: \(statusStr)"
        lines.append(padBoxLine(infoContent, visibleLength: stripAnsi(infoContent).count, totalWidth: width, borderAnsi: accentAnsi))

        if !notice.isEmpty {
            let noticeContent = " ⚡ \(boldAnsi)\(secAnsi)\(notice)\(resetAnsi)"
            lines.append(padBoxLine(noticeContent, visibleLength: stripAnsi(noticeContent).count, totalWidth: width, borderAnsi: accentAnsi))
        }

        lines.append("\(accentAnsi)├\(String(repeating: "─", count: width - 2))┤\(resetAnsi)")

        // 1. Codex Profiles Section
        let codexHeader = " \(boldAnsi)\(secAnsi)// CODEX PROFILES\(resetAnsi)"
        lines.append(padBoxLine(codexHeader, visibleLength: stripAnsi(codexHeader).count, totalWidth: width, borderAnsi: accentAnsi))

        if settings.codexProfiles.isEmpty {
            let emptyLine = "   \(dimAnsi)No Codex profiles configured.\(resetAnsi)"
            lines.append(padBoxLine(emptyLine, visibleLength: stripAnsi(emptyLine).count, totalWidth: width, borderAnsi: accentAnsi))
        } else {
            for profile in settings.codexProfiles {
                let alias = CLIHandler.profileAlias(name: profile.name)
                let snap = store.snapshots[profile.id]
                let planTag = snap?.plan.map { " [\(dimAnsi)\($0.lowercased())\(resetAnsi)]" } ?? ""
                let errTag = snap?.error.map { " \u{001B}[31m(\($0))\(resetAnsi)" } ?? ""

                let pTitle = "   \(boldAnsi)\(accentAnsi)$\(resetAnsi) \(boldAnsi)\(alias)\(resetAnsi) \(dimAnsi)(\(profile.name))\(resetAnsi)\(planTag)\(errTag)"
                lines.append(padBoxLine(pTitle, visibleLength: stripAnsi(pTitle).count, totalWidth: width, borderAnsi: accentAnsi))

                if let windows = snap?.windows, !windows.isEmpty {
                    for window in windows {
                        let pct = window.remainingPercent
                        let colorAnsi = quotaColorAnsi(for: pct)
                        let pctStr = pct.map { String(format: "%3.0f%%", $0) } ?? " --%"
                        let bar = progressBar(percent: pct, width: 14)
                        let countdown = countdownString(until: window.resetsAt)

                        let labelPadded = window.label.padding(toLength: 8, withPad: " ", startingAt: 0)
                        let wLine = "     \(dimAnsi)\(labelPadded)\(resetAnsi) \(boldAnsi)\(colorAnsi)\(pctStr)\(resetAnsi) \(colorAnsi)\(bar)\(resetAnsi)  \(dimAnsi)Reset in\(resetAnsi) \(boldAnsi)\(countdown)\(resetAnsi)"
                        lines.append(padBoxLine(wLine, visibleLength: stripAnsi(wLine).count, totalWidth: width, borderAnsi: accentAnsi))
                    }
                } else if snap?.error == nil {
                    let loadingLine = "     \(dimAnsi)Waiting for quota metrics...\(resetAnsi)"
                    lines.append(padBoxLine(loadingLine, visibleLength: stripAnsi(loadingLine).count, totalWidth: width, borderAnsi: accentAnsi))
                }
            }
        }

        lines.append("\(accentAnsi)├\(String(repeating: "─", count: width - 2))┤\(resetAnsi)")

        // 2. Antigravity Section
        let agyHeader = " \(boldAnsi)\(secAnsi)// ANTIGRAVITY (AGY)\(resetAnsi)"
        lines.append(padBoxLine(agyHeader, visibleLength: stripAnsi(agyHeader).count, totalWidth: width, borderAnsi: accentAnsi))

        let agySnap = store.snapshots[SettingsStore.antigravityProfileID]
        if let err = agySnap?.error {
            let errLine = "   \u{001B}[31m\(err)\(resetAnsi)"
            lines.append(padBoxLine(errLine, visibleLength: stripAnsi(errLine).count, totalWidth: width, borderAnsi: accentAnsi))
        } else if let windows = agySnap?.windows, !windows.isEmpty {
            let scopes = Dictionary(grouping: windows, by: { $0.scope ?? "Default" })
            let sortedScopes = scopes.keys.sorted { s1, s2 in
                if s1.contains("Gemini") { return true }
                if s2.contains("Gemini") { return false }
                return s1 < s2
            }

            for scope in sortedScopes {
                let sTag = scope.lowercased().contains("gemini") ? "gemini" : (scope.lowercased().contains("claude") ? "claude & gpt" : scope.lowercased())
                let sLine = "   \(boldAnsi)\(accentAnsi)$\(resetAnsi) \(boldAnsi)agy\(resetAnsi) [\(dimAnsi)\(sTag)\(resetAnsi)]"
                lines.append(padBoxLine(sLine, visibleLength: stripAnsi(sLine).count, totalWidth: width, borderAnsi: accentAnsi))

                let scopeWindows = scopes[scope]?.sorted(by: { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) }) ?? []
                for window in scopeWindows {
                    let pct = window.remainingPercent
                    let colorAnsi = quotaColorAnsi(for: pct)
                    let pctStr = pct.map { String(format: "%3.0f%%", $0) } ?? " --%"
                    let bar = progressBar(percent: pct, width: 14)
                    let countdown = countdownString(until: window.resetsAt)

                    let labelPadded = window.label.padding(toLength: 8, withPad: " ", startingAt: 0)
                    let wLine = "     \(dimAnsi)\(labelPadded)\(resetAnsi) \(boldAnsi)\(colorAnsi)\(pctStr)\(resetAnsi) \(colorAnsi)\(bar)\(resetAnsi)  \(dimAnsi)Reset in\(resetAnsi) \(boldAnsi)\(countdown)\(resetAnsi)"
                    lines.append(padBoxLine(wLine, visibleLength: stripAnsi(wLine).count, totalWidth: width, borderAnsi: accentAnsi))
                }
            }
        } else {
            let loadingLine = "   \(dimAnsi)Waiting for Antigravity quotas...\(resetAnsi)"
            lines.append(padBoxLine(loadingLine, visibleLength: stripAnsi(loadingLine).count, totalWidth: width, borderAnsi: accentAnsi))
        }

        lines.append("\(accentAnsi)├\(String(repeating: "─", count: width - 2))┤\(resetAnsi)")

        // 3. Summary Row
        let minPct = store.minRemainingPercent
        let minPctColor = quotaColorAnsi(for: minPct.map { Double($0) })
        let minPctStr = minPct.map { "\($0)%" } ?? "--%"
        let summaryContent = " Lowest Quota: \(boldAnsi)\(minPctColor)\(minPctStr)\(resetAnsi)  │  Auto-refresh: \(dimAnsi)every \(settings.refreshIntervalMinutes)m\(resetAnsi)"
        lines.append(padBoxLine(summaryContent, visibleLength: stripAnsi(summaryContent).count, totalWidth: width, borderAnsi: accentAnsi))

        lines.append("\(accentAnsi)├\(String(repeating: "─", count: width - 2))┤\(resetAnsi)")

        // 4. Hotkeys Bar
        let hotkeys = " HOTKEYS: \(boldAnsi)[r]\(resetAnsi) Refresh  \(boldAnsi)[t]\(resetAnsi) Theme  \(boldAnsi)[m]\(resetAnsi) Menu Bar  \(boldAnsi)[q]\(resetAnsi) Quit"
        lines.append(padBoxLine(hotkeys, visibleLength: stripAnsi(hotkeys).count, totalWidth: width, borderAnsi: accentAnsi))

        // Bottom Border Box
        lines.append("\(accentAnsi)└\(String(repeating: "─", count: width - 2))┘\(resetAnsi)")

        // Append line-clearing ANSI code to each line to prevent artifacts
        return lines.map { $0 + "\u{001B}[K" }.joined(separator: "\n")
    }

    // MARK: - Helpers
    private static func padBoxLine(_ content: String, visibleLength: Int, totalWidth: Int, borderAnsi: String) -> String {
        let padSpaces = max(0, totalWidth - 2 - visibleLength)
        return "\(borderAnsi)│\(content)\u{001B}[0m\(String(repeating: " ", count: padSpaces))\(borderAnsi)│\(contentAnsiReset)"
    }

    private static let contentAnsiReset = "\u{001B}[0m"

    public static func countdownString(until date: Date?) -> String {
        guard let date = date else { return "--:--:--" }
        let diff = Int(date.timeIntervalSince(Date()))
        if diff <= 0 {
            return "ready"
        }
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60

        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    public static func progressBar(percent: Double?, width: Int = 14) -> String {
        guard let p = percent else {
            return "[" + String(repeating: "░", count: width) + "]"
        }
        let clamped = max(0.0, min(100.0, p))
        let filledCount = Int(round((clamped / 100.0) * Double(width)))
        let emptyCount = max(0, width - filledCount)
        let filledStr = String(repeating: "█", count: filledCount)
        let emptyStr = String(repeating: "░", count: emptyCount)
        return "[\(filledStr)\(emptyStr)]"
    }

    public static func quotaColorAnsi(for percent: Double?) -> String {
        guard let p = percent else { return "\u{001B}[90m" }
        if p <= 15.0 {
            return "\u{001B}[38;2;245;71;82m" // Red
        } else if p <= 35.0 {
            return "\u{001B}[38;2;250;158;46m" // Amber
        } else {
            return "\u{001B}[38;2;0;229;153m" // Green / Emerald
        }
    }

    public static func ansiColor(hex: String) -> String {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let val = UInt64(clean, radix: 16) else {
            return "\u{001B}[38;2;56;189;248m" // Fallback cyan
        }
        let r = Int((val >> 16) & 0xFF)
        let g = Int((val >> 8) & 0xFF)
        let b = Int(val & 0xFF)
        return "\u{001B}[38;2;\(r);\(g);\(b)m"
    }

    public static func stripAnsi(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;]*[a-zA-Z]", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
