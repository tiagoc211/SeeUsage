import SwiftUI
import AppKit

public struct UsagePopoverView: View {
    @Environment(\.openWindow) private var openWindow
    var store = UsageStore.shared
    var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SeeUsage")
                        .font(.headline)
                    Text(Formatters.relativeUpdated(for: store.lastUpdated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                        .animation(store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
                }
                .buttonStyle(.plain)
                .help("Atualizar quotas")

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Definições")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Main Content Scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // CODEX SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CODEX")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)

                        if settings.codexProfiles.isEmpty {
                            Text("Nenhum perfil Codex configurado.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(settings.codexProfiles) { profile in
                                ProfileBlockView(
                                    title: profile.name,
                                    snapshot: store.snapshots[profile.id]
                                )
                            }
                        }
                    }

                    Divider()

                    // ANTIGRAVITY SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ANTIGRAVITY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)

                        let agySnapshot = store.snapshots[SettingsStore.antigravityProfileID]
                        if let err = agySnapshot?.error, agySnapshot?.windows.isEmpty ?? true {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let snapshot = agySnapshot {
                            let grouped = Dictionary(grouping: snapshot.windows) { $0.scope ?? "Antigravity" }
                            let keys = grouped.keys.sorted { lhs, rhs in
                                if lhs.contains("Gemini") { return true }
                                if rhs.contains("Gemini") { return false }
                                return lhs < rhs
                            }

                            ForEach(keys, id: \.self) { scope in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(scope)
                                        .font(.system(size: 12, weight: .semibold))

                                    ForEach(grouped[scope] ?? []) { window in
                                        WindowRowView(window: window)
                                    }
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }

                            if let err = agySnapshot?.error {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 460)

            Divider()

            // Footer
            HStack {
                Button("Sair") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if store.isRefreshing {
                    Text("A atualizar...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}

struct ProfileBlockView: View {
    let title: String
    let snapshot: UsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let plan = snapshot?.plan {
                    Text(plan)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if let err = snapshot?.error, snapshot?.windows.isEmpty ?? true {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let windows = snapshot?.windows, !windows.isEmpty {
                ForEach(windows) { window in
                    WindowRowView(window: window)
                }
                if let err = snapshot?.error {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }
}

struct WindowRowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                UsageBar(percent: window.remainingPercent ?? 0)

                Text(window.remainingPercent.map { "\(Int(round($0)))%" } ?? "--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }

            if let reset = window.resetsAt {
                Text(Formatters.resetDescription(for: reset))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 48)
            }
        }
    }
}

struct UsageBar: View {
    let percent: Double

    private var barColor: Color {
        if percent <= 15 { return .red }
        if percent <= 35 { return .orange }
        return .accentColor
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.12))
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(percent / 100.0))))
            }
        }
        .frame(height: 6)
    }
}

public struct SettingsView: View {
    @Bindable var settings = SettingsStore.shared
    @State private var newProfileName = ""
    @State private var editingID: UUID?
    @State private var editName = ""

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Perfis Codex").font(.headline)) {
                List {
                    ForEach(settings.codexProfiles) { profile in
                        HStack {
                            if editingID == profile.id {
                                TextField("Nome", text: $editName)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        settings.renameProfile(id: profile.id, newName: editName)
                                        editingID = nil
                                    }
                                Button("Guardar") {
                                    settings.renameProfile(id: profile.id, newName: editName)
                                    editingID = nil
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(profile.homePath ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    editingID = profile.id
                                    editName = profile.name
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .help("Renomear perfil")

                                Button {
                                    settings.removeProfile(id: profile.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .help("Remover da SeeUsage")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(height: 120)

                Button("+ Adicionar perfil Codex...") {
                    chooseCodexHome()
                }
            }

            Section(header: Text("Executáveis").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Codex:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Automático (/opt/homebrew/bin/codex)", text: $settings.codexExecutableOverride)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Antigravity:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Automático (~/.local/bin/agy)", text: $settings.antigravityExecutableOverride)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Section(header: Text("Atualização").font(.headline)) {
                Picker("Intervalo de refresh:", selection: $settings.refreshIntervalMinutes) {
                    Text("5 minutos").tag(5)
                    Text("10 minutos").tag(10)
                    Text("15 minutos").tag(15)
                    Text("30 minutos").tag(30)
                }
                .pickerStyle(.menu)
            }
        }
        .padding(20)
        .frame(width: 440, height: 380)
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
