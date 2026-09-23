import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?

    private override init() {
        super.init()
    }

    public func show(tab: SettingsTab = .general) {
        if let window {
            NotificationCenter.default.post(
                name: NSNotification.Name("app.seeusage.selectSettingsTab"),
                object: tab.rawValue
            )
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "SeeUsage Settings"
        panel.contentMinSize = NSSize(width: 560, height: 440)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentViewController = NSHostingController(rootView: SettingsView(initialTab: tab))
        panel.center()
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

public enum SettingsTab: String, Sendable {
    case general, profiles
}

private struct PendingReset: Identifiable {
    let profile: UsageProfile
    let credit: BankedResetCredit
    var id: String { "\(profile.id.uuidString):\(credit.id)" }
}

public enum Formatters {
    public static func dayMonth(_ date: Date) -> String {
        dateString(date, format: "d/M")
    }

    public static func dayMonthName(_ date: Date) -> String {
        dateString(date, format: "d MMM")
    }

    public static func dayMonthYear(_ date: Date) -> String {
        dateString(date, format: "d MMM yyyy")
    }

    public static func longDayMonthYear(_ date: Date) -> String {
        dateString(date, format: "d MMMM yyyy")
    }

    public static func dayMonthTime(_ date: Date) -> String {
        dateString(date, format: "d MMM, HH:mm")
    }

    public static func resetDescription(for date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return "now" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "in \(days)d \(hours)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(max(1, minutes))m"
    }

    private static func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    public static func bankedCreditTitle(_ credit: BankedResetCredit) -> String {
        let title = credit.title ?? "Available reset credit"
        guard let expiration = credit.expiresAt else { return title }
        return "\(title) — expires on \(dayMonth(expiration))"
    }
}

public struct UsagePopoverView: View {
    @Bindable private var store = UsageStore.shared
    @Bindable private var settings = SettingsStore.shared
    @Bindable private var analytics = AnalyticsManager.shared
    @State private var pendingReset: PendingReset?
    @State private var isConfirmingReset = false
    @State private var resultMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if settings.codexProfiles.isEmpty {
                        ContentUnavailableView {
                            Label("No Codex profiles", systemImage: "person.crop.circle.badge.questionmark")
                        } description: {
                            Text("Add a Codex profile in Settings to see its usage.")
                        } actions: {
                            Button("Open Settings") { SettingsWindowManager.shared.show(tab: .profiles) }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        ForEach(settings.codexProfiles) { profile in
                            profileSection(profile: profile, snapshot: store.snapshots[profile.id], provider: "Codex")
                            Divider()
                        }
                    }

                    if let antigravity = store.snapshots[SettingsStore.antigravityProfileID] {
                        profileSection(profile: UsageProfile(
                            id: SettingsStore.antigravityProfileID,
                            provider: .antigravity,
                            name: "Antigravity"
                        ), snapshot: antigravity, provider: "Antigravity")
                    }

                    if store.snapshots.isEmpty && !store.isRefreshing {
                        Text("Usage will appear here after the first refresh.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    }

                    if !analytics.snapshots.isEmpty {
                        ActivityHeatmap(
                            dailyConsumption: analytics.computeDailyConsumption(days: 85),
                            accent: settings.currentTheme.accent
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            Divider()
            footer
        }
        .frame(width: 360, height: 470)
        .background(.background)
        .confirmationDialog(
            "Use a banked reset?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Use Reset", role: .destructive) {
                if let pendingReset { activate(pendingReset) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will use one reset credit on \(pendingReset?.profile.name ?? "this profile").")
        }
        .alert("Banked Reset", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("OK") { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .tint(settings.currentTheme.accent)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SeeUsage").font(.headline)
                Text("Remaining quota").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh(forceAfterCurrent: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Refresh usage")
            }
            Button {
                SettingsWindowManager.shared.show()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Settings")
        }
        .padding(14)
    }

    @ViewBuilder
    private func profileSection(profile: UsageProfile, snapshot: UsageSnapshot?, provider: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(profile.name).font(.headline)
                Spacer()
                if let plan = snapshot?.plan { Text(plan).font(.caption).foregroundStyle(.secondary) }
            }

            if let snapshot {
                if let error = snapshot.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if snapshot.isStale {
                    Label("Showing old data", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(snapshot.windows) { window in
                    quotaRow(window, provider: provider)
                }

                if provider == "Codex" {
                    let credits = snapshot.bankedCredits.filter { $0.status.lowercased() == "available" }
                    let creditCount = max(snapshot.availableResetCredits ?? 0, credits.count)
                    if creditCount > 0 {
                        Menu {
                            ForEach(credits) { credit in
                                Button(Formatters.bankedCreditTitle(credit)) {
                                    pendingReset = PendingReset(profile: profile, credit: credit)
                                    isConfirmingReset = true
                                }
                            }
                        } label: {
                            Label("Use banked reset (\(creditCount))", systemImage: "bolt.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(snapshot.error != nil || snapshot.isStale)
                    }
                }

                if snapshot.windows.isEmpty && snapshot.error == nil {
                    Text("No quota windows returned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if store.isRefreshing {
                ProgressView("Loading usage…").controlSize(.small)
            } else {
                Text("No usage data yet.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func quotaRow(_ window: UsageWindow, provider: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text([window.scope, window.label].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                Spacer()
                if let percent = window.remainingPercent {
                    Text("\(Int(percent.rounded()))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(percent <= 15 ? .red : (percent <= 35 ? .orange : .primary))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            if let percent = window.remainingPercent {
                ProgressView(value: max(0, min(100, percent)), total: 100)
                    .tint(percent <= 15 ? .red : (percent <= 35 ? .orange : .accentColor))
            }
            if let reset = window.resetsAt {
                Text("Resets \(Formatters.resetDescription(for: reset))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack {
            if let date = store.lastUpdated {
                Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not updated yet").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit SeeUsage") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func activate(_ item: PendingReset) {
        Task {
            let result = await store.consumeBankedReset(
                for: item.profile,
                creditId: item.credit.serverCreditID
            )
            resultMessage = result.message
        }
    }
}

private struct ActivityHeatmap: View {
    let dailyConsumption: [DailyConsumption]
    let accent: Color
    @State private var hoveredDate: Date?
    @State private var selectedDate: Date?

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -11, to: currentWeekStart) ?? currentWeekStart
        let usageByDay = Dictionary(grouping: dailyConsumption) {
            calendar.startOfDay(for: $0.date)
        }.mapValues { entries in
            entries.reduce(0) { $0 + $1.consumptionPercent }
        }
        let peakUsage = usageByDay.values.max() ?? 0
        let selectedProfileUsage = selectedDate.map { selectedDate in
            dailyConsumption
                .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
                .sorted { $0.consumptionPercent > $1.consumptionPercent }
        } ?? []
        let hoverSummary = hoveredDate.map { date in
            activitySummary(for: date, usage: usageByDay[calendar.startOfDay(for: date)] ?? 0)
        } ?? "Last 12 weeks"

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(hoverSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { day in
                            let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstWeekStart) ?? today
                            let usage = usageByDay[date] ?? 0
                            let intensity = activityIntensity(for: usage, peak: peakUsage)

                            Button {
                                selectedDate = selectedDate == date ? nil : date
                            } label: {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(activityColor(for: intensity))
                                    .overlay {
                                        if selectedDate == date {
                                            RoundedRectangle(cornerRadius: 2)
                                                .strokeBorder(Color.primary.opacity(0.8), lineWidth: 1)
                                        }
                                    }
                                    .frame(width: 12, height: 12)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .onHover { isHovering in
                                if isHovering { hoveredDate = date }
                            }
                            .accessibilityLabel(activityDescription(for: date, usage: usage))
                            .accessibilityHint("Show usage by profile")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let selectedDate {
                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(Formatters.dayMonthYear(selectedDate))
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button {
                            self.selectedDate = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Close activity details")
                    }

                    if selectedProfileUsage.isEmpty {
                        Text("No recorded usage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedProfileUsage) { entry in
                            HStack {
                                Text(entry.profileName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.consumptionPercent.formatted(.number.precision(.fractionLength(0...1)))) quota pts")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 2)
    }

    private func activityIntensity(for usage: Double, peak: Double) -> Int {
        guard usage > 0, peak > 0 else { return 0 }
        return min(4, max(1, Int(ceil(usage / peak * 4))))
    }

    private func activityColor(for intensity: Int) -> Color {
        switch intensity {
        case 1: accent.opacity(0.22)
        case 2: accent.opacity(0.42)
        case 3: accent.opacity(0.68)
        case 4: accent
        default: Color.primary.opacity(0.07)
        }
    }

    private func activitySummary(for date: Date, usage: Double) -> String {
        let dateLabel = Formatters.dayMonthName(date)
        guard usage > 0 else { return "\(dateLabel) · no use" }
        let usageLabel = usage.formatted(.number.precision(.fractionLength(0...1)))
        return "\(dateLabel) · \(usageLabel) quota pts"
    }

    private func activityDescription(for date: Date, usage: Double) -> String {
        let dateLabel = Formatters.longDayMonthYear(date)
        guard usage > 0 else { return "\(dateLabel) · No recorded usage" }
        let usageLabel = usage.formatted(.number.precision(.fractionLength(0...1)))
        return "\(dateLabel) · \(usageLabel) quota points used"
    }
}

private enum PreferenceTab: String, CaseIterable, Identifiable {
    case general, profiles
    var id: String { rawValue }
}

public struct SettingsView: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var selectedTab: PreferenceTab

    public init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab == .profiles ? .profiles : .general)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            generalPreferences
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(PreferenceTab.general)
            profilePreferences
                .tabItem { Label("Profiles", systemImage: "person.crop.circle") }
                .tag(PreferenceTab.profiles)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 440)
        .tint(settings.currentTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("app.seeusage.selectSettingsTab"))) { note in
            if (note.object as? String) == SettingsTab.profiles.rawValue {
                selectedTab = .profiles
            } else {
                selectedTab = .general
            }
        }
    }

    private var generalPreferences: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show SeeUsage icon", isOn: $settings.menuBarShowIcon)
                Picker("Update interval", selection: $settings.refreshIntervalMinutes) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Appearance") {
                Picker("Accent color", selection: $settings.selectedThemeID) {
                    ForEach(appearancePickerThemes) { theme in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 10, height: 10)
                            Text(theme.name)
                        }
                        .tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled { NotificationManager.shared.requestAuthorization() }
                    }
                Toggle("Alert when quota is low", isOn: $settings.notifyOnCritical)
                    .disabled(!settings.notificationsEnabled)
                HStack {
                    Text("Low quota threshold")
                    Slider(value: Binding(
                        get: { Double(settings.criticalThresholdPercent) },
                        set: { settings.criticalThresholdPercent = Int($0.rounded()) }
                    ), in: 5...50, step: 5)
                    Text("\(settings.criticalThresholdPercent)%")
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .disabled(!settings.notificationsEnabled || !settings.notifyOnCritical)
                Toggle("Notify when quotas reset", isOn: $settings.notifyOnReset)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Play notification sounds", isOn: $settings.notificationSoundEnabled)
                    .disabled(!settings.notificationsEnabled)
            }

            DisclosureGroup("Command line tools") {
                TextField("Codex executable path", text: $settings.codexExecutableOverride)
                TextField("Antigravity executable path", text: $settings.antigravityExecutableOverride)
            }

            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0")
        }
        .formStyle(.grouped)
        .tabItem { Label("General", systemImage: "gearshape") }
    }

    private var appearancePickerThemes: [AppTheme] {
        let themes = ThemeRegistry.appearanceThemes
        guard !themes.contains(where: { $0.id == settings.selectedThemeID }) else { return themes }
        return [settings.currentTheme] + themes
    }

    private var profilePreferences: some View {
        Form {
            Section("Codex profiles") {
                if settings.codexProfiles.isEmpty {
                    Text("No profiles configured.").foregroundStyle(.secondary)
                }
                ForEach(settings.codexProfiles) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.name)
                            Text(profile.homePath ?? "No CODEX_HOME path")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Remove", role: .destructive) {
                            settings.removeProfile(id: profile.id)
                        }
                        .controlSize(.small)
                    }
                }
                Button {
                    addProfileFromFolderPicker()
                } label: {
                    Label("Add Profile…", systemImage: "plus")
                }
            }
            Section {
                Text("SeeUsage reads usage from each selected Codex home. Your credentials stay in the Codex configuration folders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Profiles", systemImage: "person.crop.circle") }
    }

    private func addProfileFromFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Codex profile folder"
        panel.message = "Select a folder containing Codex account data."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.addProfile(name: url.lastPathComponent.capitalized, path: url.path)
    }
}
