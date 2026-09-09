import SwiftUI
import AppKit

// MARK: - Dynamic Theme Bridge
public enum T3Theme {
    public static var background: Color { SettingsStore.shared.currentTheme.background }
    public static var surface: Color { SettingsStore.shared.currentTheme.surface }
    public static var surfaceHover: Color { SettingsStore.shared.currentTheme.surfaceHover }
    public static var border: Color { SettingsStore.shared.currentTheme.border }
    public static var borderActive: Color { SettingsStore.shared.currentTheme.borderActive }

    public static var textPrimary: Color { SettingsStore.shared.currentTheme.textPrimary }
    public static var textSecondary: Color { SettingsStore.shared.currentTheme.textSecondary }
    public static var textMuted: Color { SettingsStore.shared.currentTheme.textMuted }

    public static var green: Color { SettingsStore.shared.currentTheme.green }
    public static var amber: Color { SettingsStore.shared.currentTheme.amber }
    public static var red: Color { SettingsStore.shared.currentTheme.red }
    public static var cyan: Color { SettingsStore.shared.currentTheme.cyan }
    public static var purple: Color { SettingsStore.shared.currentTheme.purple }
    public static var accent: Color { SettingsStore.shared.currentTheme.accent }
}

func t3QuotaColor(for percent: Double?) -> Color {
    let theme = SettingsStore.shared.currentTheme
    guard let pct = percent else { return theme.textMuted }
    if pct <= 15 { return theme.red }
    if pct <= 35 { return theme.amber }
    return theme.green
}

// MARK: - Settings Window Manager
@MainActor
public final class SettingsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?

    public func show() {
        if let win = window {
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 590),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 700, height: 520)
        win.title = "seeusage // settings"
        win.contentViewController = hosting
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win
        win.orderFrontRegardless()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}

// MARK: - Terminal Quick Copy Button
struct T3CopyButton: View {
    let command: String
    let label: String
    @State private var copied = false

    init(command: String, label: String = "copy") {
        self.command = command
        self.label = label
    }

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(command, forType: .string)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                copied = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation { copied = false }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 8, weight: .bold))
                Text(copied ? "copied" : label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(copied ? T3Theme.green : T3Theme.textMuted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(copied ? T3Theme.green.opacity(0.15) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .help("Copy command: \(command)")
    }
}

// MARK: - Toolbar Icon Button
struct T3ToolbarButton: View {
    let icon: String
    let helpText: String
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? T3Theme.surfaceHover : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isHovered ? T3Theme.borderActive : Color.clear, lineWidth: 1)
                    )
                    .frame(width: 24, height: 24)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? T3Theme.textPrimary : T3Theme.textSecondary)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: isSpinning
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
    }
}

// MARK: - Usage Popover View (Dark Terminal Aesthetic)
public struct UsagePopoverView: View {
    private var store = UsageStore.shared
    @Bindable private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView

            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(height: 1)

            // Content Area
            if store.snapshots.isEmpty && store.isRefreshing {
                loadingView
            } else {
                contentScrollView
            }

            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(height: 1)

            // Footer Bar
            footerView
        }
        .frame(width: 370)
        .background(settings.currentTheme.background)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: settings.selectedThemeID)
        .onAppear {
            Task {
                await store.refresh()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Terminal Prompt Indicator
            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.green)

                Text("seeusage")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)

                Text("--live")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            Spacer()

            // Toolbar Controls
            HStack(spacing: 3) {
                T3ToolbarButton(
                    icon: "arrow.clockwise",
                    helpText: "Refresh quotas",
                    isSpinning: store.isRefreshing
                ) {
                    Task { await store.refresh() }
                }

                T3ToolbarButton(
                    icon: "gearshape",
                    helpText: "Settings"
                ) {
                    SettingsWindowManager.shared.show()
                }

                T3ToolbarButton(
                    icon: "power",
                    helpText: "Quit"
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("polling rate limits...")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
    }

    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // CODEX SECTION
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(title: "CODEX PROFILES", tag: "CLI")

                    if settings.codexProfiles.isEmpty {
                        emptyCard(text: "No codex profiles found.")
                    } else {
                        ForEach(settings.codexProfiles) { profile in
                            CodexT3CardView(
                                profile: profile,
                                snapshot: store.snapshots[profile.id]
                            )
                        }
                    }
                }

                // ANTIGRAVITY SECTION
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(title: "ANTIGRAVITY", tag: "AGY")

                    let agySnapshot = store.snapshots[SettingsStore.antigravityProfileID]
                    if let err = agySnapshot?.error, agySnapshot?.windows.isEmpty ?? true {
                        errorCard(text: err)
                    } else if let snapshot = agySnapshot {
                        let grouped = Dictionary(grouping: snapshot.windows) { $0.scope ?? "Antigravity" }
                        let keys = grouped.keys.sorted { lhs, rhs in
                            if lhs.contains("Gemini") { return true }
                            if rhs.contains("Gemini") { return false }
                            return lhs < rhs
                        }

                        ForEach(keys, id: \.self) { scope in
                            AntigravityT3CardView(
                                scope: scope,
                                windows: grouped[scope] ?? []
                            )
                        }

                        if let err = agySnapshot?.error {
                            HStack(spacing: 5) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 10))
                                Text(err)
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            .foregroundStyle(settings.currentTheme.amber)
                            .padding(.horizontal, 4)
                        }
                    } else {
                        loadingCard
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 370)
        .frame(minHeight: 260, maxHeight: 490)
    }

    // MARK: - Section Label
    private func sectionLabel(title: String, tag: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textSecondary)
                .tracking(0.8)

            Text("[\(tag)]")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(settings.currentTheme.textMuted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t3CardBackground)
    }

    private func errorCard(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(settings.currentTheme.amber)
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t3CardBackground)
    }

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.6)
            Text("fetching metrics...")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t3CardBackground)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            // Live Status Dot
            HStack(spacing: 6) {
                Circle()
                    .fill(store.isRefreshing ? settings.currentTheme.amber : settings.currentTheme.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: (store.isRefreshing ? settings.currentTheme.amber : settings.currentTheme.green).opacity(0.6), radius: 3)

                Text(store.isRefreshing ? "syncing" : "connected")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            Spacer()

            // Lowest Quota Monospace Chip
            if let minPct = store.minRemainingPercent {
                HStack(spacing: 4) {
                    Text("min:")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Text("\(minPct)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(t3QuotaColor(for: Double(minPct)))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(t3QuotaColor(for: Double(minPct)).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(t3QuotaColor(for: Double(minPct)).opacity(0.25), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Codex Card
struct CodexT3CardView: View {
    let profile: UsageProfile
    let snapshot: UsageSnapshot?

    private var aliasName: String {
        let low = profile.name.lowercased()
        if low.contains("pessoal") { return "cxp" }
        if low.contains("trabalho") { return "cxt" }
        return profile.name.lowercased()
    }

    private var exportCommand: String {
        if let home = profile.homePath {
            return "export CODEX_HOME=\"\(home)\""
        }
        return "unset CODEX_HOME"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card Title Row
            HStack(alignment: .center, spacing: 6) {
                // Command chip
                HStack(spacing: 3) {
                    Text("$")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.cyan)
                    Text(aliasName)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.textPrimary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

                Text("(\(profile.name))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(T3Theme.textMuted)

                Spacer()

                // Quick Copy export command
                T3CopyButton(command: exportCommand)

                if let plan = snapshot?.plan {
                    Text("[\(plan.lowercased())]")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.cyan)
                }
            }

            // Quotas
            if let err = snapshot?.error, snapshot?.windows.isEmpty ?? true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9.5))
                    Text(err)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(T3Theme.amber)
            } else if let windows = snapshot?.windows, !windows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(windows) { window in
                        T3QuotaRowView(window: window)
                    }
                }

                if let err = snapshot?.error {
                    Text(err)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(T3Theme.amber)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.5)
                    Text("connecting...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(T3Theme.textMuted)
                }
            }
        }
        .padding(10)
        .background(t3CardBackground)
    }
}

// MARK: - Antigravity Card
struct AntigravityT3CardView: View {
    let scope: String
    let windows: [UsageWindow]

    private var modelBadge: (label: String, color: Color) {
        if scope.contains("Gemini") { return ("gemini", T3Theme.purple) }
        if scope.contains("Claude") { return ("claude", T3Theme.amber) }
        return ("gpt", T3Theme.green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Scope Row
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Text("$")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.purple)
                    Text("agy")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.textPrimary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

                Text("[\(modelBadge.label)]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(modelBadge.color)

                Spacer()

                // Quick copy command
                T3CopyButton(command: "agy -p \"/usage\"", label: "usage")
            }

            // Quotas
            VStack(spacing: 6) {
                ForEach(windows) { window in
                    T3QuotaRowView(window: window)
                }
            }
        }
        .padding(10)
        .background(t3CardBackground)
    }
}

// MARK: - Quota Row View
struct T3QuotaRowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 8) {
                // Window Tag
                Text(window.label.lowercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(T3Theme.textSecondary)
                    .frame(width: 32, alignment: .leading)

                // Industrial Fine Progress Bar
                T3ProgressBar(percent: window.remainingPercent ?? 0)

                // Percentage
                Text(window.remainingPercent.map { "\(Int(round($0)))%" } ?? "--")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(t3QuotaColor(for: window.remainingPercent))
                    .frame(width: 38, alignment: .trailing)
            }

            // Reset Subtitle
            if let reset = window.resetsAt {
                HStack(spacing: 4) {
                    Color.clear
                        .frame(width: 32 + 8, height: 1)

                    Text("↳ \(Formatters.resetDescription(for: reset).lowercased())")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(T3Theme.textMuted)
                }
            }
        }
    }
}

// MARK: - Fine Progress Bar
struct T3ProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0.0, min(100.0, percent))
            let fillWidth = geo.size.width * CGFloat(clamped / 100.0)

            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 5)

                // Precision Progress Fill
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(t3QuotaColor(for: clamped))
                    .frame(width: max(fillWidth, clamped > 0 ? 3 : 0), height: 5)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: clamped)
            }
        }
        .frame(minWidth: 90)
        .frame(height: 5)
    }
}

// MARK: - Card Background
private var t3CardBackground: some View {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(T3Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(T3Theme.border, lineWidth: 1)
        )
}

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case menubar = "menubar"
    case appearance = "appearance"
    case notifications = "notifications"
    case profiles = "profiles"
    case executables = "executables"
    case sync = "sync"
    case about = "about"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menubar: return "Menu Bar"
        case .appearance: return "Appearance"
        case .notifications: return "Notifications"
        case .profiles: return "Codex Profiles"
        case .executables: return "Executables"
        case .sync: return "Sync"
        case .about: return "About & CLI"
        }
    }

    var subtitle: String {
        switch self {
        case .menubar: return "display & launch"
        case .appearance: return "themes & palette"
        case .notifications: return "alerts & thresholds"
        case .profiles: return "codex accounts"
        case .executables: return "cli paths"
        case .sync: return "polling frequency"
        case .about: return "cli & commands"
        }
    }

    var icon: String {
        switch self {
        case .menubar: return "menubar.rectangle"
        case .appearance: return "paintbrush.fill"
        case .notifications: return "bell.badge.fill"
        case .profiles: return "person.crop.circle"
        case .executables: return "slider.horizontal.3"
        case .sync: return "arrow.triangle.2.circlepath"
        case .about: return "terminal.fill"
        }
    }
}

// MARK: - Settings View (Sidebar Navigation)
public struct SettingsView: View {
    @Bindable var settings = SettingsStore.shared
    @State private var selectedTab: SettingsTab = .menubar
    @State private var hoveredTab: SettingsTab?
    @State private var editingID: UUID?
    @State private var editName = ""

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: Left Sidebar
            sidebarView
                .frame(width: 215)
                .background(settings.currentTheme.background)

            // Vertical 1px boundary
            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(width: 1)

            // MARK: Right Detail Pane
            VStack(spacing: 0) {
                detailHeaderView

                Rectangle()
                    .fill(settings.currentTheme.border)
                    .frame(height: 1)

                ScrollView {
                    detailContent
                        .padding(22)
                }
            }
            .background(settings.currentTheme.background)
        }
        .frame(minWidth: 720, minHeight: 540)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selectedTab)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: settings.selectedThemeID)
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 7) {
                Text("$")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.green)

                Text("seeusage")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)

                Text("// settings")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(height: 1)

            // Navigation Section Label
            Text("PREFERENCES")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
                .tracking(1.0)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

            // Navigation Items
            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(for: tab)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Sidebar Footer: Active Theme Indicator
            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(height: 1)

            HStack(spacing: 7) {
                Circle()
                    .fill(settings.currentTheme.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: settings.currentTheme.accent.opacity(0.5), radius: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ACTIVE THEME")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text(settings.currentTheme.name)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                }

                Spacer()

                Text("[CORE]")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.cyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(settings.currentTheme.surface.opacity(0.4))
        }
    }

    // MARK: - Sidebar Item
    private func sidebarItem(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isSelected ? settings.currentTheme.accent : Color.clear)
                    .frame(width: 3, height: 16)

                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? settings.currentTheme.accent : (isHovered ? settings.currentTheme.textPrimary : settings.currentTheme.textSecondary))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.title)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? settings.currentTheme.textPrimary : (isHovered ? settings.currentTheme.textPrimary : settings.currentTheme.textSecondary))

                    Text(tab.subtitle)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                // Small badge
                tabBadge(for: tab, isSelected: isSelected)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? settings.currentTheme.surfaceHover : (isHovered ? settings.currentTheme.surface.opacity(0.5) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isSelected ? settings.currentTheme.borderActive : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hoveredTab = $0 ? tab : nil }
    }

    @ViewBuilder
    private func tabBadge(for tab: SettingsTab, isSelected: Bool) -> some View {
        switch tab {
        case .menubar:
            Text(settings.menuBarDisplayMode.badgeLabel)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? settings.currentTheme.accent : settings.currentTheme.textMuted)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        case .appearance:
            Text(settings.currentTheme.category == "Core Themes" ? "core" : "ext")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? settings.currentTheme.accent : settings.currentTheme.textMuted)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        case .notifications:
            Text(settings.notificationsEnabled ? "\(settings.criticalThresholdPercent)%" : "off")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? settings.currentTheme.accent : settings.currentTheme.textMuted)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        case .profiles:
            Text("\(settings.codexProfiles.count)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
        case .sync:
            Text("\(settings.refreshIntervalMinutes)m")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
        default:
            EmptyView()
        }
    }

    // MARK: - Detail Header View
    private var detailHeaderView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Breadcrumbs
            HStack(spacing: 5) {
                Text("settings")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                Text("/")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted.opacity(0.5))
                Text(selectedTab.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)
            }

            Spacer()

            // Header Actions
            switch selectedTab {
            case .menubar:
                if settings.menuBarDisplayMode != .percent || !settings.menuBarShowIcon {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            settings.selectMenuBarMode(.percent)
                            settings.menuBarShowIcon = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9))
                            Text("reset default")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(settings.currentTheme.textSecondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            case .appearance:
                if settings.selectedThemeID != "t3-default" {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            settings.selectTheme("t3-default")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9))
                            Text("reset default")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(settings.currentTheme.textSecondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            case .profiles:
                Button {
                    chooseCodexHome()
                } label: {
                    Text("+ add profile")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            case .notifications:
                Button {
                    NotificationManager.shared.sendTestNotification()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 9))
                        Text("test alert")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(settings.currentTheme.textSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            case .sync:
                Button {
                    Task { await UsageStore.shared.refresh() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5))
                        Text("sync now")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    // MARK: - Detail Content Switcher
    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .menubar:
            menuBarPane
        case .appearance:
            appearancePane
        case .notifications:
            notificationsPane
        case .profiles:
            profilesPane
        case .executables:
            executablesPane
        case .sync:
            syncPane
        case .about:
            aboutPane
        }
    }

    // MARK: - Menu Bar & Display Pane
    private var menuBarPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("// MENU BAR ITEM & LAUNCH")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("Customize how SeeUsage presents quotas in your macOS menu bar and configure startup behavior.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Live Simulated Menu Bar Preview
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("LIVE MENU BAR PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                        .tracking(0.8)

                    Text("[MACOS TOP BAR]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Spacer()
                }

                HStack(spacing: 12) {
                    // Simulated Menu Bar strip
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 11))
                            .foregroundStyle(settings.currentTheme.textMuted)

                        Text("SeeUsage")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(settings.currentTheme.textSecondary)

                        Spacer()

                        // Simulated active item
                        HStack(spacing: 5) {
                            menuBarPreviewContent
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(settings.currentTheme.accent.opacity(0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(settings.currentTheme.accent.opacity(0.4), lineWidth: 1)
                                )
                        )

                        Image(systemName: "wifi")
                            .font(.system(size: 10))
                            .foregroundStyle(settings.currentTheme.textMuted)

                        Image(systemName: "battery.100")
                            .font(.system(size: 11))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(settings.currentTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(settings.currentTheme.border, lineWidth: 1)
                    )
                }
            }

            // Mode Selection Cards
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("DISPLAY STYLES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                        .tracking(0.8)

                    Text("[SELECT ONE]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        MenuBarModeCard(
                            mode: mode,
                            isSelected: settings.menuBarDisplayMode == mode
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                settings.selectMenuBarMode(mode)
                            }
                        }
                    }
                }
            }

            // Additional Preferences
            VStack(alignment: .leading, spacing: 10) {
                Text("ADDITIONAL PREFERENCES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
                    .tracking(0.8)

                VStack(spacing: 8) {
                    // Show Icon Toggle
                    if settings.menuBarDisplayMode != .iconOnly {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Status Icon")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textPrimary)
                                Text("Display leading gauge icon before quota metrics")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textMuted)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.menuBarShowIcon)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        .padding(12)
                        .background(settings.currentTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(settings.currentTheme.border, lineWidth: 1)
                        )
                    }

                    // Launch at Login Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                            Text("Start SeeUsage automatically when logging into macOS")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(12)
                    .background(settings.currentTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(settings.currentTheme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var menuBarPreviewContent: some View {
        let pct = UsageStore.shared.minRemainingPercent ?? 47
        let cxPct = UsageStore.shared.codexLowestPercent ?? 92
        let agPct = UsageStore.shared.antigravityLowestPercent ?? 81

        switch settings.menuBarDisplayMode {
        case .percent:
            if settings.menuBarShowIcon {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.currentTheme.accent)
            }
            Text("\(pct)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textPrimary)

        case .dual:
            if settings.menuBarShowIcon {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(settings.currentTheme.accent)
            }
            Text("cx: \(cxPct)% · ag: \(agPct)%")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textPrimary)

        case .gauge:
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 24, height: 7)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(settings.currentTheme.accent)
                        .frame(width: CGFloat(pct) / 100.0 * 24, height: 6)
                }
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)
            }

        case .iconOnly:
            Circle()
                .fill(settings.currentTheme.accent)
                .frame(width: 8, height: 8)
                .shadow(color: settings.currentTheme.accent.opacity(0.5), radius: 3)
        }
    }

    // MARK: - Appearance & Themes Pane
    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("// THEMES & PALETTES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("Choose a visual theme for SeeUsage. Changes apply immediately across the app and menu bar.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Category 1: Core Themes
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("CORE PRESETS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                        .tracking(0.8)

                    Text("[SIGNATURE PALETTES]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(ThemeRegistry.allThemes.filter { $0.category == "Core Themes" }) { theme in
                        ThemeCardView(theme: theme, isSelected: settings.selectedThemeID == theme.id) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                settings.selectTheme(theme.id)
                            }
                        }
                    }
                }
            }

            // Category 2: Developer Classics
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("DEVELOPER CLASSICS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                        .tracking(0.8)

                    Text("[POPULAR PALETTES]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(ThemeRegistry.allThemes.filter { $0.category == "Developer Classics" }) { theme in
                        ThemeCardView(theme: theme, isSelected: settings.selectedThemeID == theme.id) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                settings.selectTheme(theme.id)
                            }
                        }
                    }
                }
            }

            // Live Quota Preview Section
            VStack(alignment: .leading, spacing: 8) {
                Text("// LIVE QUOTA PREVIEW (\(settings.currentTheme.name.uppercased()))")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("crit")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textSecondary)
                            .frame(width: 32, alignment: .leading)
                        T3ProgressBar(percent: 12.0)
                        Text("12%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(t3QuotaColor(for: 12.0))
                            .frame(width: 38, alignment: .trailing)
                    }

                    HStack(spacing: 8) {
                        Text("warn")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textSecondary)
                            .frame(width: 32, alignment: .leading)
                        T3ProgressBar(percent: 32.0)
                        Text("32%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(t3QuotaColor(for: 32.0))
                            .frame(width: 38, alignment: .trailing)
                    }

                    HStack(spacing: 8) {
                        Text("good")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textSecondary)
                            .frame(width: 32, alignment: .leading)
                        T3ProgressBar(percent: 86.0)
                        Text("86%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(t3QuotaColor(for: 86.0))
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                .padding(12)
                .background(t3CardBackground)
            }

            // Palette Inspector Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("// ACTIVE PALETTE VALUES")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)

                HStack(spacing: 8) {
                    paletteChip(name: "bg", hex: settings.currentTheme.bgHex, color: settings.currentTheme.background)
                    paletteChip(name: "surface", hex: settings.currentTheme.surfaceHex, color: settings.currentTheme.surface)
                    paletteChip(name: "accent", hex: settings.currentTheme.accentHex, color: settings.currentTheme.accent)
                    paletteChip(name: "secondary", hex: settings.currentTheme.secondaryHex, color: settings.currentTheme.cyan)
                }
            }
        }
    }

    private func paletteChip(name: String, hex: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                Text(hex)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)
            }

            T3CopyButton(command: hex, label: "")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(t3CardBackground)
    }

    // MARK: - Notifications Pane
    private var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("// NATIVE MAC NOTIFICATIONS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("Configure native macOS system alerts for critical quota thresholds and scheduled reset events.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Master Switch Card
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(settings.notificationsEnabled ? settings.currentTheme.accent.opacity(0.15) : Color.white.opacity(0.04))
                            .frame(width: 32, height: 32)
                        Image(systemName: settings.notificationsEnabled ? "bell.badge.fill" : "bell.slash")
                            .font(.system(size: 14))
                            .foregroundStyle(settings.notificationsEnabled ? settings.currentTheme.accent : settings.currentTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable System Notifications")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textPrimary)
                        Text("Deliver banners and sounds when quotas drop or recover")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.notificationsEnabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                }
                .padding(14)
            }
            .background(t3CardBackground)

            if settings.notificationsEnabled {
                // Critical Quota Alert Configuration
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(settings.currentTheme.red)
                        Text("CRITICAL QUOTA ALERTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }

                    // Toggle for critical alert
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alert on Low Quota")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                            Text("Notify when any model or profile drops to or below the threshold")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.notifyOnCritical)
                            .toggleStyle(.switch)
                            .scaleEffect(0.8)
                    }

                    if settings.notifyOnCritical {
                        Rectangle()
                            .fill(settings.currentTheme.border)
                            .frame(height: 1)

                        // Threshold Selector
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Alert Threshold:")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textSecondary)
                                Text("≤ \(settings.criticalThresholdPercent)%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.red)
                                Spacer()
                            }

                            HStack(spacing: 8) {
                                ForEach([5, 10, 15, 20, 25], id: \.self) { val in
                                    let isSelected = settings.criticalThresholdPercent == val
                                    Button {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                            settings.criticalThresholdPercent = val
                                        }
                                    } label: {
                                        Text("\(val)%")
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                                            .foregroundStyle(isSelected ? Color.white : settings.currentTheme.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(isSelected ? settings.currentTheme.accent : Color.white.opacity(0.04))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .stroke(isSelected ? settings.currentTheme.accent : settings.currentTheme.border, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(t3CardBackground)

                // Quota Restored & Sound Configuration
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(settings.currentTheme.green)
                        Text("RESTORATION & SOUND")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }

                    // Reset alert toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alert on Quota Reset")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                            Text("Notify when quota counter resets and usage capacity is restored")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.notifyOnReset)
                            .toggleStyle(.switch)
                            .scaleEffect(0.8)
                    }

                    Rectangle()
                        .fill(settings.currentTheme.border)
                        .frame(height: 1)

                    // Sound toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Play System Sound")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                            Text("Play the default macOS alert sound with notifications")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.notificationSoundEnabled)
                            .toggleStyle(.switch)
                            .scaleEffect(0.8)
                    }
                }
                .padding(14)
                .background(t3CardBackground)

                // Test Delivery Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Test Native Delivery")
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textPrimary)
                        Text("Dispatch a sample alert to verify macOS banner and sound")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        NotificationManager.shared.sendTestNotification()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 9))
                            Text("send test")
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(14)
                .background(t3CardBackground)
            }
        }
    }

    // MARK: - Profiles Pane
    private var profilesPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// CODEX PROFILES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.cyan)

                Text("Configure home directories for each Codex CLI profile.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            VStack(spacing: 0) {
                if settings.codexProfiles.isEmpty {
                    Text("No profiles configured.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    ForEach(Array(settings.codexProfiles.enumerated()), id: \.element.id) { index, profile in
                        VStack(spacing: 0) {
                            HStack(alignment: .center, spacing: 10) {
                                Text("$")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.cyan)

                                if editingID == profile.id {
                                    HStack(spacing: 6) {
                                        TextField("Profile Name", text: $editName)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 11, design: .monospaced))
                                        Button("save") {
                                            settings.renameProfile(id: profile.id, newName: editName)
                                            editingID = nil
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        Button("cancel") {
                                            editingID = nil
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(settings.currentTheme.textPrimary)
                                        Text(profile.homePath ?? "~/.codex")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(settings.currentTheme.textMuted)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Button {
                                            editingID = profile.id
                                            editName = profile.name
                                        } label: {
                                            Text("edit")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(settings.currentTheme.textSecondary)
                                        }
                                        .buttonStyle(.borderless)

                                        Button {
                                            settings.removeProfile(id: profile.id)
                                        } label: {
                                            Text("del")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(settings.currentTheme.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            if index < settings.codexProfiles.count - 1 {
                                Rectangle()
                                    .fill(settings.currentTheme.border)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
            .background(t3CardBackground)
        }
    }

    // MARK: - Executables Pane
    private var executablesPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// EXECUTABLES OVERRIDE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)

                Text("Specify custom executable paths if not located in standard PATH.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("codex cli")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textPrimary)
                        Spacer()
                        Text("default: /opt/homebrew/bin/codex")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }
                    TextField("auto-detect", text: $settings.codexExecutableOverride)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5, design: .monospaced))
                }

                Rectangle()
                    .fill(settings.currentTheme.border)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("antigravity cli (agy)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textPrimary)
                        Spacer()
                        Text("default: ~/.local/bin/agy")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }
                    TextField("auto-detect", text: $settings.antigravityExecutableOverride)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5, design: .monospaced))
                }
            }
            .padding(14)
            .background(t3CardBackground)
        }
    }

    // MARK: - Sync Pane
    private var syncPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// SYNC INTERVAL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)

                Text("Background quota polling frequency.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("polling rate limit:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Text("Automatically refresh metrics in the background.")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }
                Spacer()
                Picker("", selection: $settings.refreshIntervalMinutes) {
                    Text("5m").tag(5)
                    Text("10m").tag(10)
                    Text("15m").tag(15)
                    Text("30m").tag(30)
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            .padding(14)
            .background(t3CardBackground)
        }
    }

    // MARK: - About Pane
    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// ABOUT SEEUSAGE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.green)

                Text("Rate limit and quota monitor for Codex and Antigravity.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("// CLI COMMANDS QUICK REFERENCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)

                HStack {
                    Text("$ seeusage")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "seeusage", label: "copy")
                }

                HStack {
                    Text("$ seeusage watch")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "seeusage watch", label: "copy")
                }

                HStack {
                    Text("$ seeusage mode")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "seeusage mode", label: "copy")
                }

                HStack {
                    Text("$ seeusage --json")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "seeusage --json", label: "copy")
                }

                HStack {
                    Text("$ seeusage prompt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "seeusage prompt", label: "copy")
                }

                HStack {
                    Text("$ agy -p \"/usage\"")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Spacer()
                    T3CopyButton(command: "agy -p \"/usage\"", label: "copy")
                }
            }
            .padding(14)
            .background(t3CardBackground)

            VStack(alignment: .leading, spacing: 4) {
                Text("SeeUsage v1.1.0 // Minimal Dark Terminal Design System")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }
            .padding(.top, 8)
        }
    }

    private func chooseCodexHome() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Select"
        panel.message = "Choose CODEX_HOME directory (e.g. ~/.codex-profiles/...)"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let name = url.lastPathComponent.capitalized
            settings.addProfile(name: name, path: path)
        }
    }
}

// MARK: - Theme Card View
struct ThemeCardView: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Mock Mini App Window Container
                ZStack(alignment: .topLeading) {
                    theme.background

                    VStack(alignment: .leading, spacing: 5) {
                        // Traffic light header
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 5.5, height: 5.5)
                            Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 5.5, height: 5.5)
                            Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 5.5, height: 5.5)

                            Spacer()

                            // Mini Tag
                            Text(theme.category == "Core Themes" ? "core" : "ext")
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.textMuted)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        // Mini terminal prompt & quota card preview
                        HStack(spacing: 6) {
                            // Mini card preview
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 3) {
                                    Text("$")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(theme.cyan)
                                    Text("seeusage")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.textPrimary)
                                }

                                // Mini progress bar in theme colors
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 3.5)
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(theme.accent)
                                        .frame(width: 48, height: 3.5)
                                }
                            }
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(theme.border, lineWidth: 0.5)
                                    )
                            )

                            Spacer()

                            // 3 Palette Swatch Circles
                            HStack(spacing: -4) {
                                Circle()
                                    .fill(theme.background)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                Circle()
                                    .fill(theme.surface)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    }
                }
                .frame(height: 56)

                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)

                // Card Footer with Details
                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(theme.name)
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)

                        Text(theme.tagline)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Selection Status Badge
                    if isSelected {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("active")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(theme.accent.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                    } else if isHovered {
                        Text("apply →")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent : (isHovered ? theme.borderActive : theme.border),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: isSelected ? theme.accent.opacity(0.12) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Formatters
public enum Formatters {
    public static func resetDescription(for date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        if interval <= 0 {
            return "resets now"
        }
        let minutes = Int(ceil(interval / 60.0))
        if minutes < 60 {
            return "in \(minutes)m"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours < 12 {
            if remMinutes == 0 {
                return "in \(hours)h"
            } else {
                return "in \(hours)h \(remMinutes)m"
            }
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "today at \(timeStr)"
        }
        if calendar.isDateInTomorrow(date) {
            return "tomorrow at \(timeStr)"
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US")
        weekdayFormatter.dateFormat = "EEE"
        let weekday = weekdayFormatter.string(from: date).lowercased()
        return "\(weekday) at \(timeStr)"
    }

    public static func relativeUpdated(for date: Date?) -> String {
        guard let date = date else { return "never updated" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        }
        let minutes = seconds / 60
        if minutes == 1 {
            return "1m ago"
        }
        return "\(minutes)m ago"
    }
}


// MARK: - Menu Bar Mode Card View
public struct MenuBarModeCard: View {
    @Bindable var settings = SettingsStore.shared
    let mode: MenuBarDisplayMode
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelected ? settings.currentTheme.accent.opacity(0.16) : settings.currentTheme.surfaceHover)
                            .frame(width: 28, height: 28)

                        modeIcon(for: mode)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? settings.currentTheme.accent : settings.currentTheme.textSecondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(isSelected ? settings.currentTheme.accent : settings.currentTheme.borderActive, lineWidth: 1.2)
                            .frame(width: 15, height: 15)

                        if isSelected {
                            Circle()
                                .fill(settings.currentTheme.accent)
                                .frame(width: 7.5, height: 7.5)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)

                    Text(mode.subtitle)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 4) {
                    Text("Sample:")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Text(sampleText(for: mode))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? settings.currentTheme.accent : settings.currentTheme.textSecondary)
                }
                .padding(.top, 2)
            }
            .padding(12)
            .background(isSelected ? settings.currentTheme.surfaceHover : settings.currentTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected ? settings.currentTheme.accent : (isHovered ? settings.currentTheme.borderActive : settings.currentTheme.border),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func modeIcon(for mode: MenuBarDisplayMode) -> some View {
        switch mode {
        case .percent:
            Image(systemName: "gauge.with.needle")
        case .dual:
            Image(systemName: "bolt.horizontal.fill")
        case .gauge:
            Image(systemName: "chart.bar.xaxis")
        case .iconOnly:
            Image(systemName: "circle.fill")
        }
    }

    private func sampleText(for mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .percent: return "⚡ 47%"
        case .dual: return "cx: 92% · ag: 81%"
        case .gauge: return "■■■□ 47%"
        case .iconOnly: return "●"
        }
    }
}
