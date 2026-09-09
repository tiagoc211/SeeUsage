import SwiftUI
import AppKit

// MARK: - T3 Code Design System
enum T3Theme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06) // #0d0d0f deep graphite
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.11)    // #17171c card surface
    static let surfaceHover = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let border = Color.white.opacity(0.08)                     // 1px subtle boundary
    static let borderActive = Color.white.opacity(0.18)

    static let textPrimary = Color(red: 0.95, green: 0.96, blue: 0.98) // #f1f3f7
    static let textSecondary = Color(red: 0.62, green: 0.63, blue: 0.67) // #9ea1ab
    static let textMuted = Color(red: 0.42, green: 0.43, blue: 0.47)     // #6b6e78

    // T3 Neon Accents
    static let green = Color(red: 0.0, green: 0.90, blue: 0.60)    // #00e599 Terminal Emerald
    static let amber = Color(red: 0.98, green: 0.63, blue: 0.18)    // #fa9e2e Warning Amber
    static let red = Color(red: 0.96, green: 0.28, blue: 0.32)      // #f54752 Critical Red
    static let cyan = Color(red: 0.22, green: 0.74, blue: 0.98)     // #38bdf8 Tech Cyan
    static let purple = Color(red: 0.66, green: 0.47, blue: 0.98)   // #a877fa AI Purple
}

func t3QuotaColor(for percent: Double?) -> Color {
    guard let pct = percent else { return T3Theme.textMuted }
    if pct <= 15 { return T3Theme.red }
    if pct <= 35 { return T3Theme.amber }
    return T3Theme.green
}

// MARK: - Settings Window Manager
@MainActor
public final class SettingsWindowManager {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?

    public func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "seeusage // settings"
        win.contentViewController = hosting
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - T3 Button
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

// MARK: - Usage Popover View (T3 Code Aesthetic)
public struct UsagePopoverView: View {
    private var store = UsageStore.shared
    private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView

            Rectangle()
                .fill(T3Theme.border)
                .frame(height: 1)

            // Content Area
            if store.snapshots.isEmpty && store.isRefreshing {
                loadingView
            } else {
                contentScrollView
            }

            Rectangle()
                .fill(T3Theme.border)
                .frame(height: 1)

            // Footer Bar
            footerView
        }
        .frame(width: 370)
        .background(T3Theme.background)
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
                    .foregroundStyle(T3Theme.green)

                Text("seeusage")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T3Theme.textPrimary)

                Text("--live")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(T3Theme.textMuted)
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
                .foregroundStyle(T3Theme.textMuted)
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
                            .foregroundStyle(T3Theme.amber)
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
                .foregroundStyle(T3Theme.textSecondary)
                .tracking(0.8)

            Text("[\(tag)]")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(T3Theme.textMuted)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(T3Theme.textMuted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t3CardBackground)
    }

    private func errorCard(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(T3Theme.amber)
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(T3Theme.textSecondary)
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
                .foregroundStyle(T3Theme.textMuted)
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
                    .fill(store.isRefreshing ? T3Theme.amber : T3Theme.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: (store.isRefreshing ? T3Theme.amber : T3Theme.green).opacity(0.6), radius: 3)

                Text(store.isRefreshing ? "syncing" : "connected")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(T3Theme.textSecondary)
            }

            Spacer()

            // Lowest Quota Monospace Chip
            if let minPct = store.minRemainingPercent {
                HStack(spacing: 4) {
                    Text("min:")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(T3Theme.textMuted)

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

// MARK: - Codex T3 Card
struct CodexT3CardView: View {
    let profile: UsageProfile
    let snapshot: UsageSnapshot?

    private var aliasName: String {
        let low = profile.name.lowercased()
        if low.contains("pessoal") { return "cxp" }
        if low.contains("trabalho") { return "cxt" }
        return profile.name.lowercased()
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

// MARK: - Antigravity T3 Card
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

// MARK: - T3 Quota Row View
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

// MARK: - T3 Fine Progress Bar (Engineered Precision)
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

// MARK: - T3 Card Background
private var t3CardBackground: some View {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(T3Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(T3Theme.border, lineWidth: 1)
        )
}

// MARK: - Settings View (T3 Code Dark Theme)
public struct SettingsView: View {
    @Bindable var settings = SettingsStore.shared
    @State private var editingID: UUID?
    @State private var editName = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Perfis Codex
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("// CODEX PROFILES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(T3Theme.cyan)

                        Spacer()

                        Button {
                            chooseCodexHome()
                        } label: {
                            Text("+ add profile")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(spacing: 0) {
                        if settings.codexProfiles.isEmpty {
                            Text("No profiles configured.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T3Theme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(Array(settings.codexProfiles.enumerated()), id: \.element.id) { index, profile in
                                VStack(spacing: 0) {
                                    HStack(alignment: .center, spacing: 10) {
                                        Text("$")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(T3Theme.cyan)

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
                                                    .foregroundStyle(T3Theme.textPrimary)
                                                Text(profile.homePath ?? "~/.codex")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(T3Theme.textMuted)
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
                                                        .foregroundStyle(T3Theme.textSecondary)
                                                }
                                                .buttonStyle(.borderless)

                                                Button {
                                                    settings.removeProfile(id: profile.id)
                                                } label: {
                                                    Text("del")
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundStyle(T3Theme.red)
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)

                                    if index < settings.codexProfiles.count - 1 {
                                        Rectangle()
                                            .fill(T3Theme.border)
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .background(t3CardBackground)
                }

                // Section 2: Executáveis
                VStack(alignment: .leading, spacing: 8) {
                    Text("// EXECUTABLES OVERRIDE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.textSecondary)

                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("codex cli")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(T3Theme.textPrimary)
                                Spacer()
                                Text("default: /opt/homebrew/bin/codex")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(T3Theme.textMuted)
                            }
                            TextField("auto-detect", text: $settings.codexExecutableOverride)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10.5, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("antigravity cli (agy)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(T3Theme.textPrimary)
                                Spacer()
                                Text("default: ~/.local/bin/agy")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(T3Theme.textMuted)
                            }
                            TextField("auto-detect", text: $settings.antigravityExecutableOverride)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10.5, design: .monospaced))
                        }
                    }
                    .padding(12)
                    .background(t3CardBackground)
                }

                // Section 3: Sincronização
                VStack(alignment: .leading, spacing: 8) {
                    Text("// SYNC INTERVAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(T3Theme.textSecondary)

                    HStack {
                        Text("poll interval:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(T3Theme.textPrimary)
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
                    .padding(12)
                    .background(t3CardBackground)
                }
            }
            .padding(18)
        }
        .frame(width: 500, height: 500)
        .background(T3Theme.background)
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
