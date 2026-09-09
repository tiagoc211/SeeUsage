import SwiftUI
import AppKit

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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Definições SeeUsage"
        win.contentViewController = hosting
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Mac Native Icon Button
struct MacIconButton: View {
    let icon: String
    let helpText: String
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning
                            ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                            : .default,
                        value: isSpinning
                    )
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
    }
}

// MARK: - Usage Popover View (Apple macOS Design)
public struct UsagePopoverView: View {
    private var store = UsageStore.shared
    private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .opacity(0.4)

            // Content
            if store.snapshots.isEmpty && store.isRefreshing {
                loadingView
            } else {
                contentScrollView
            }

            Divider()
                .opacity(0.4)

            // Footer
            footerView
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .onAppear {
            Task {
                await store.refresh()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            // Apple-style App Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.blue.opacity(0.25), radius: 3, y: 1)

                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Quotas de IA")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Text(Formatters.relativeUpdated(for: store.lastUpdated))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 2) {
                MacIconButton(
                    icon: "arrow.clockwise",
                    helpText: "Atualizar quotas agora",
                    isSpinning: store.isRefreshing
                ) {
                    Task { await store.refresh() }
                }

                MacIconButton(
                    icon: "gearshape",
                    helpText: "Definições"
                ) {
                    SettingsWindowManager.shared.show()
                }

                MacIconButton(
                    icon: "power",
                    helpText: "Sair do SeeUsage"
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("A consultar contas...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .padding(.vertical, 40)
    }

    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // CODEX SECTION
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "CODEX", icon: "terminal.fill", color: .blue)

                    if settings.codexProfiles.isEmpty {
                        emptyProfileCard
                    } else {
                        ForEach(settings.codexProfiles) { profile in
                            CodexProfileCardView(
                                profile: profile,
                                snapshot: store.snapshots[profile.id]
                            )
                        }
                    }
                }

                // ANTIGRAVITY SECTION
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "ANTIGRAVITY", icon: "sparkles", color: .purple)

                    let agySnapshot = store.snapshots[SettingsStore.antigravityProfileID]
                    if let err = agySnapshot?.error, agySnapshot?.windows.isEmpty ?? true {
                        errorCard(message: err)
                    } else if let snapshot = agySnapshot {
                        let grouped = Dictionary(grouping: snapshot.windows) { $0.scope ?? "Antigravity" }
                        let keys = grouped.keys.sorted { lhs, rhs in
                            if lhs.contains("Gemini") { return true }
                            if rhs.contains("Gemini") { return false }
                            return lhs < rhs
                        }

                        ForEach(keys, id: \.self) { scope in
                            AntigravityScopeCardView(
                                scope: scope,
                                windows: grouped[scope] ?? []
                            )
                        }

                        if let err = agySnapshot?.error {
                            HStack(spacing: 5) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 10))
                                Text(err)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                        }
                    } else {
                        loadingCard
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360)
        .frame(minHeight: 260, maxHeight: 500)
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
        }
        .padding(.leading, 4)
    }

    // MARK: - Empty / Loading Cards
    private var emptyProfileCard: some View {
        Text("Nenhum perfil configurado.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appleCardBackground)
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appleCardBackground)
    }

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.6)
            Text("A consultar...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appleCardBackground)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            // Live Status Indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(store.isRefreshing ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: (store.isRefreshing ? Color.orange : Color.green).opacity(0.4), radius: 2)

                Text(store.isRefreshing ? "A sincronizar..." : "Sincronizado")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Lowest Quota Chip
            if let minPct = store.minRemainingPercent {
                HStack(spacing: 4) {
                    Text("Menor:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("\(minPct)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(appleQuotaColor(for: Double(minPct)))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(appleQuotaColor(for: Double(minPct)).opacity(0.12))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - Codex Profile Card (Apple Native Grouped Style)
struct CodexProfileCardView: View {
    let profile: UsageProfile
    let snapshot: UsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack(alignment: .center, spacing: 8) {
                // Mini profile avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.blue)
                }

                Text(profile.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if let plan = snapshot?.plan {
                    Text(plan.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                        )
                        .foregroundStyle(Color.blue)
                }
            }

            // Quota Rows
            if let err = snapshot?.error, snapshot?.windows.isEmpty ?? true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(err)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 2)
            } else if let windows = snapshot?.windows, !windows.isEmpty {
                VStack(spacing: 7) {
                    ForEach(windows) { window in
                        AppleQuotaRowView(window: window)
                    }
                }

                if let err = snapshot?.error {
                    Text(err)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.orange)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6)
                    Text("A consultar...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(11)
        .background(appleCardBackground)
    }
}

// MARK: - Antigravity Scope Card (Apple Native Grouped Style)
struct AntigravityScopeCardView: View {
    let scope: String
    let windows: [UsageWindow]

    private var scopeInfo: (icon: String, color: Color) {
        if scope.contains("Gemini") {
            return ("sparkles", Color.purple)
        } else if scope.contains("Claude") {
            return ("brain", Color.orange)
        } else {
            return ("cpu", Color.indigo)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Scope Header
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(scopeInfo.color.opacity(0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: scopeInfo.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(scopeInfo.color)
                }

                Text(scope)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Quotas
            VStack(spacing: 7) {
                ForEach(windows) { window in
                    AppleQuotaRowView(window: window)
                }
            }
        }
        .padding(11)
        .background(appleCardBackground)
    }
}

// MARK: - Apple Quota Row View
struct AppleQuotaRowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 8) {
                // Window Tag / Pill (e.g. "5h", "7d")
                Text(window.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .center)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                // Native Apple Progress Bar Track
                AppleProgressBar(percent: window.remainingPercent ?? 0)

                // Percentage Value
                Text(window.remainingPercent.map { "\(Int(round($0)))%" } ?? "--")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(appleQuotaColor(for: window.remainingPercent))
                    .frame(width: 40, alignment: .trailing)
            }

            // Reset Subtitle (Indented nicely past the label tag)
            if let reset = window.resetsAt {
                HStack(spacing: 4) {
                    Color.clear
                        .frame(width: 32 + 8, height: 1)

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Text(Formatters.resetDescription(for: reset))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.85))
                }
            }
        }
    }
}

// MARK: - Apple Native Progress Bar (Sleek Gradient Pill)
struct AppleProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0.0, min(100.0, percent))
            let fillWidth = geo.size.width * CGFloat(clamped / 100.0)

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 6.5)

                // Gradient Active Fill
                Capsule()
                    .fill(appleGradient(for: clamped))
                    .frame(width: max(fillWidth, clamped > 0 ? 5 : 0), height: 6.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clamped)
            }
        }
        .frame(minWidth: 90)
        .frame(height: 6.5)
    }

    private func appleGradient(for pct: Double) -> LinearGradient {
        if pct <= 15 {
            return LinearGradient(
                colors: [Color.red, Color(red: 1.0, green: 0.35, blue: 0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if pct <= 35 {
            return LinearGradient(
                colors: [Color.orange, Color(red: 1.0, green: 0.7, blue: 0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.8, blue: 0.44), Color(red: 0.2, green: 0.88, blue: 0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Semantic Apple Quota Color
func appleQuotaColor(for percent: Double?) -> Color {
    guard let pct = percent else { return .secondary }
    if pct <= 15 { return Color(nsColor: .systemRed) }
    if pct <= 35 { return Color(nsColor: .systemOrange) }
    return Color(nsColor: .systemGreen)
}

// MARK: - Apple Card Background
private var appleCardBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
}

// MARK: - Settings View (macOS System Settings Style)
public struct SettingsView: View {
    @Bindable var settings = SettingsStore.shared
    @State private var editingID: UUID?
    @State private var editName = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Section 1: Perfis Codex
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 7) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)

                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text("Perfis Codex")
                                .font(.system(size: 13, weight: .bold))
                        }

                        Spacer()

                        Button {
                            chooseCodexHome()
                        } label: {
                            Label("Adicionar Perfil", systemImage: "plus")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(spacing: 0) {
                        if settings.codexProfiles.isEmpty {
                            Text("Nenhum perfil configurado.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(Array(settings.codexProfiles.enumerated()), id: \.element.id) { index, profile in
                                VStack(spacing: 0) {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.blue)

                                        if editingID == profile.id {
                                            HStack(spacing: 8) {
                                                TextField("Nome do Perfil", text: $editName)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.system(size: 12))
                                                Button("Guardar") {
                                                    settings.renameProfile(id: profile.id, newName: editName)
                                                    editingID = nil
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                                Button("Cancelar") {
                                                    editingID = nil
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                        } else {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(profile.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text(profile.homePath ?? "Padrão (~/.codex)")
                                                    .font(.system(size: 10.5, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }

                                            Spacer()

                                            HStack(spacing: 6) {
                                                Button {
                                                    editingID = profile.id
                                                    editName = profile.name
                                                } label: {
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 11.5))
                                                }
                                                .buttonStyle(.borderless)
                                                .help("Renomear")

                                                Button {
                                                    settings.removeProfile(id: profile.id)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 11.5))
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.borderless)
                                                .help("Remover")
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)

                                    if index < settings.codexProfiles.count - 1 {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                    }
                    .background(appleCardBackground)
                }

                // Section 2: Executáveis
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.gray)
                                .frame(width: 20, height: 20)

                            Image(systemName: "terminal.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Caminhos dos Executáveis")
                            .font(.system(size: 13, weight: .bold))
                    }

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Codex CLI")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("Padrão: /opt/homebrew/bin/codex")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Deixar em branco para deteção automática", text: $settings.codexExecutableOverride)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Antigravity CLI (agy)")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("Padrão: ~/.local/bin/agy")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Deixar em branco para deteção automática", text: $settings.antigravityExecutableOverride)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    .padding(14)
                    .background(appleCardBackground)
                }

                // Section 3: Frequência
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.orange)
                                .frame(width: 20, height: 20)

                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Atualização Automática")
                            .font(.system(size: 13, weight: .bold))
                    }

                    HStack {
                        Text("Intervalo de sincronização:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $settings.refreshIntervalMinutes) {
                            Text("A cada 5 minutos").tag(5)
                            Text("A cada 10 minutos").tag(10)
                            Text("A cada 15 minutos").tag(15)
                            Text("A cada 30 minutos").tag(30)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                    }
                    .padding(14)
                    .background(appleCardBackground)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 490)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func chooseCodexHome() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Selecionar"
        panel.message = "Escolhe uma pasta CODEX_HOME (ex: ~/.codex ou ~/.codex-profiles/...)"

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
            return "Reset agora"
        }
        let minutes = Int(ceil(interval / 60.0))
        if minutes < 60 {
            return "Reset em \(minutes) min"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours < 12 {
            if remMinutes == 0 {
                return "Reset em \(hours) h"
            } else {
                return "Reset em \(hours) h \(remMinutes) min"
            }
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Reset hoje às \(timeStr)"
        }
        if calendar.isDateInTomorrow(date) {
            return "Reset amanhã às \(timeStr)"
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "pt_PT")
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: date).lowercased()
        let cleanWeekday = weekday.replacingOccurrences(of: "-feira", with: "")
        return "Reset \(cleanWeekday) às \(timeStr)"
    }

    public static func relativeUpdated(for date: Date?) -> String {
        guard let date = date else { return "Nunca atualizado" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "Atualizado agora"
        }
        let minutes = seconds / 60
        if minutes == 1 {
            return "Atualizado há 1 min"
        }
        return "Atualizado há \(minutes) min"
    }
}
