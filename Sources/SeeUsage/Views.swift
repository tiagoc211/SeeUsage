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
        .help("Copiar comando: \(command)")
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
                    helpText: "Atualizar quotas",
                    isSpinning: store.isRefreshing
                ) {
                    Task { await store.refresh() }
                }

                T3ToolbarButton(
                    icon: "gearshape",
                    helpText: "Definições"
                ) {
                    SettingsWindowManager.shared.show()
                }

                T3ToolbarButton(
                    icon: "power",
                    helpText: "Sair"
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
    case appearance = "appearance"
    case profiles = "profiles"
    case executables = "executables"
    case sync = "sync"
    case about = "about"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "Aparência"
        case .profiles: return "Perfis Codex"
        case .executables: return "Executáveis"
        case .sync: return "Sincronização"
        case .about: return "Sobre & CLI"
        }
    }

    var subtitle: String {
        switch self {
        case .appearance: return "themes & palette"
        case .profiles: return "codex accounts"
        case .executables: return "cli paths"
        case .sync: return "polling frequency"
        case .about: return "cli & commands"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
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
    @State private var selectedTab: SettingsTab = .appearance
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
        case .appearance:
            appearancePane
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

    // MARK: - Appearance & Themes Pane
    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("// THEMES & PALETTES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("Escolha o tema visual para o SeeUsage. As alterações são aplicadas instantaneamente em toda a aplicação e na barra de menus.")
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

    // MARK: - Profiles Pane
    private var profilesPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// CODEX PROFILES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.cyan)

                Text("Configure as pastas de home para cada conta ou perfil do Codex CLI.")
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

                Text("Especifique caminhos customizados para os binários se não estiverem no PATH padrão.")
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

                Text("Frequência de consulta de quotas de rate limit em background.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("polling rate limit:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                    Text("Atualiza automaticamente as métricas em segundo plano.")
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

                Text("Monitor de Quotas e Rate Limits para Codex e Antigravity.")
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
                            Text("ativo")
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
                        Text("usar →")
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
