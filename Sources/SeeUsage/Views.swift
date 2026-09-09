import SwiftUI
import AppKit

public struct UsagePopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var store = UsageStore.shared
    @State private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main Content
            if store.snapshots.isEmpty && store.isRefreshing {
                loadingView
            } else {
                contentScrollView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task {
                await store.refresh()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "gauge.with.needle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("SeeUsage")
                    .font(.system(size: 14, weight: .bold))
                Text(Formatters.relativeUpdated(for: store.lastUpdated))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Refresh Button
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(
                        store.isRefreshing
                            ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                            : .default,
                        value: store.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .help("Atualizar quotas agora")

            // Settings Button
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Definições")

            // Quit Button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Fechar SeeUsage")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("A obter quotas dos perfis...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // CODEX SECTION
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 10))
                        Text("CODEX")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.secondary)

                    if settings.codexProfiles.isEmpty {
                        Text("Nenhum perfil configurado.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(settings.codexProfiles) { profile in
                            ProfileCardView(
                                title: profile.name,
                                iconName: "person.crop.circle",
                                snapshot: store.snapshots[profile.id]
                            )
                        }
                    }
                }

                Divider()

                // ANTIGRAVITY SECTION
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("ANTIGRAVITY")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.secondary)

                    let agySnapshot = store.snapshots[SettingsStore.antigravityProfileID]
                    if let err = agySnapshot?.error, agySnapshot?.windows.isEmpty ?? true {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground)
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
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                Text(err)
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.6)
                            Text("A consultar...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxHeight: 480)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.isRefreshing ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(store.isRefreshing ? "A sincronizar..." : "Pronto")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let minPct = store.minRemainingPercent {
                HStack(spacing: 4) {
                    Text("Menor quota:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(minPct)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(quotaColor(for: Double(minPct)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Profile Card View (Codex)
struct ProfileCardView: View {
    let title: String
    let iconName: String
    let snapshot: UsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title & Plan Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }

                Spacer()

                if let plan = snapshot?.plan {
                    Text(plan)
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Body
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
                VStack(spacing: 6) {
                    ForEach(windows) { window in
                        QuotaRowView(window: window)
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Antigravity Scope Card
struct AntigravityScopeCardView: View {
    let scope: String
    let windows: [UsageWindow]

    private var scopeIcon: String {
        if scope.contains("Gemini") { return "sparkles" }
        return "cpu"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: scopeIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(scope)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(windows) { window in
                    QuotaRowView(window: window)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quota Row View (Pixel-Perfect Column Alignment)
struct QuotaRowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                // Column 1: Window Label (Fixed 48pt)
                Text(window.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                // Column 2: Progress Bar (Expands evenly)
                ModernProgressBar(percent: window.remainingPercent ?? 0)
                    .frame(height: 7)

                // Column 3: Percentage (Fixed 42pt)
                Text(window.remainingPercent.map { "\(Int(round($0)))%" } ?? "--")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(quotaColor(for: window.remainingPercent))
                    .frame(width: 42, alignment: .trailing)
            }

            // Reset Subtitle (Indented by label width + spacing = 56pt)
            if let reset = window.resetsAt {
                HStack(spacing: 3) {
                    Color.clear
                        .frame(width: 48 + 8, height: 1)

                    Image(systemName: "clock")
                        .font(.system(size: 8.5))
                    Text(Formatters.resetDescription(for: reset))
                        .font(.system(size: 9.5))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Modern Progress Bar
struct ModernProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0.0, min(100.0, percent))
            let fillWidth = geo.size.width * CGFloat(clamped / 100.0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(quotaColor(for: clamped))
                    .frame(width: max(fillWidth, clamped > 0 ? 3 : 0))
            }
        }
    }
}

func quotaColor(for percent: Double?) -> Color {
    guard let pct = percent else { return .secondary }
    if pct <= 15 { return .red }
    if pct <= 35 { return .orange }
    return Color.accentColor
}

// MARK: - Settings View (Modern macOS Settings UI)
public struct SettingsView: View {
    @Bindable var settings = SettingsStore.shared
    @State private var editingID: UUID?
    @State private var editName = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Perfis Codex
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Perfis Codex", systemImage: "person.2.fill")
                            .font(.system(size: 13, weight: .bold))
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
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.accentColor)

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
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Button {
                                                    editingID = profile.id
                                                    editName = profile.name
                                                } label: {
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 12))
                                                }
                                                .buttonStyle(.borderless)
                                                .help("Renomear")

                                                Button {
                                                    settings.removeProfile(id: profile.id)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 12))
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
                                            .padding(.leading, 42)
                                    }
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                Divider()

                // Section 2: Executáveis
                VStack(alignment: .leading, spacing: 10) {
                    Label("Caminhos dos Executáveis", systemImage: "terminal")
                        .font(.system(size: 13, weight: .bold))

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
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                Divider()

                // Section 3: Frequência de Atualização
                VStack(alignment: .leading, spacing: 10) {
                    Label("Atualização Automática", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .bold))

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
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 460)
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
