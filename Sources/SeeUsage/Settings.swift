import Foundation
import Observation
import ServiceManagement

public extension Notification.Name {
    static let menuBarSettingsChanged = Notification.Name("app.seeusage.menuBarSettingsChanged")
}

@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    public static let antigravityProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public static let suiteName = "app.seeusage.SeeUsage"
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public var selectedThemeID: String {
        didSet {
            Self.defaults.set(selectedThemeID, forKey: "selectedThemeID")
            UserDefaults.standard.set(selectedThemeID, forKey: "selectedThemeID")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.themeChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var currentTheme: AppTheme {
        ThemeRegistry.theme(for: selectedThemeID)
    }

    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            Self.defaults.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
            NotificationCenter.default.post(name: .menuBarSettingsChanged, object: nil)
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.menuBarSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var menuBarShowIcon: Bool {
        didSet {
            Self.defaults.set(menuBarShowIcon, forKey: "menuBarShowIcon")
            UserDefaults.standard.set(menuBarShowIcon, forKey: "menuBarShowIcon")
            NotificationCenter.default.post(name: .menuBarSettingsChanged, object: nil)
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.menuBarSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    public var notificationsEnabled: Bool {
        didSet {
            Self.defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    public var notifyOnCritical: Bool {
        didSet {
            Self.defaults.set(notifyOnCritical, forKey: "notifyOnCritical")
            UserDefaults.standard.set(notifyOnCritical, forKey: "notifyOnCritical")
        }
    }

    public var criticalThresholdPercent: Int {
        didSet {
            Self.defaults.set(criticalThresholdPercent, forKey: "criticalThresholdPercent")
            UserDefaults.standard.set(criticalThresholdPercent, forKey: "criticalThresholdPercent")
        }
    }

    public var notifyOnReset: Bool {
        didSet {
            Self.defaults.set(notifyOnReset, forKey: "notifyOnReset")
            UserDefaults.standard.set(notifyOnReset, forKey: "notifyOnReset")
        }
    }

    public var notificationSoundEnabled: Bool {
        didSet {
            Self.defaults.set(notificationSoundEnabled, forKey: "notificationSoundEnabled")
            UserDefaults.standard.set(notificationSoundEnabled, forKey: "notificationSoundEnabled")
        }
    }

    public var hudEnabled: Bool {
        didSet {
            Self.defaults.set(hudEnabled, forKey: "hudEnabled")
            UserDefaults.standard.set(hudEnabled, forKey: "hudEnabled")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.hudSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var hudAlwaysOnTop: Bool {
        didSet {
            Self.defaults.set(hudAlwaysOnTop, forKey: "hudAlwaysOnTop")
            UserDefaults.standard.set(hudAlwaysOnTop, forKey: "hudAlwaysOnTop")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.hudSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var hudCompactMode: Bool {
        didSet {
            Self.defaults.set(hudCompactMode, forKey: "hudCompactMode")
            UserDefaults.standard.set(hudCompactMode, forKey: "hudCompactMode")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.hudSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var hudOpacity: Double {
        didSet {
            Self.defaults.set(hudOpacity, forKey: "hudOpacity")
            UserDefaults.standard.set(hudOpacity, forKey: "hudOpacity")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.hudSettingsChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    public var refreshIntervalMinutes: Int {
        didSet {
            Self.defaults.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes")
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes")
        }
    }

    public var codexExecutableOverride: String {
        didSet {
            Self.defaults.set(codexExecutableOverride, forKey: "codexExecutableOverride")
            UserDefaults.standard.set(codexExecutableOverride, forKey: "codexExecutableOverride")
        }
    }

    public var antigravityExecutableOverride: String {
        didSet {
            Self.defaults.set(antigravityExecutableOverride, forKey: "antigravityExecutableOverride")
            UserDefaults.standard.set(antigravityExecutableOverride, forKey: "antigravityExecutableOverride")
        }
    }

    public var codexProfiles: [UsageProfile] {
        didSet {
            saveProfiles()
        }
    }

    public init() {
        let prefs = Self.defaults
        let fallback = UserDefaults.standard

        self.selectedThemeID = prefs.string(forKey: "selectedThemeID")
            ?? fallback.string(forKey: "selectedThemeID")
            ?? "t3-default"

        let rawMode = prefs.string(forKey: "menuBarDisplayMode")
            ?? fallback.string(forKey: "menuBarDisplayMode")
            ?? "percent"
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: rawMode) ?? .percent

        let showIcon = prefs.object(forKey: "menuBarShowIcon") as? Bool
            ?? fallback.object(forKey: "menuBarShowIcon") as? Bool
            ?? true
        self.menuBarShowIcon = showIcon

        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = false
        }

        self.notificationsEnabled = prefs.object(forKey: "notificationsEnabled") as? Bool
            ?? fallback.object(forKey: "notificationsEnabled") as? Bool
            ?? true

        self.notifyOnCritical = prefs.object(forKey: "notifyOnCritical") as? Bool
            ?? fallback.object(forKey: "notifyOnCritical") as? Bool
            ?? true

        let thresh = prefs.integer(forKey: "criticalThresholdPercent") != 0
            ? prefs.integer(forKey: "criticalThresholdPercent")
            : fallback.integer(forKey: "criticalThresholdPercent")
        self.criticalThresholdPercent = thresh > 0 ? thresh : 15

        self.notifyOnReset = prefs.object(forKey: "notifyOnReset") as? Bool
            ?? fallback.object(forKey: "notifyOnReset") as? Bool
            ?? true

        self.notificationSoundEnabled = prefs.object(forKey: "notificationSoundEnabled") as? Bool
            ?? fallback.object(forKey: "notificationSoundEnabled") as? Bool
            ?? true

        self.hudEnabled = prefs.object(forKey: "hudEnabled") as? Bool
            ?? fallback.object(forKey: "hudEnabled") as? Bool
            ?? false

        self.hudAlwaysOnTop = prefs.object(forKey: "hudAlwaysOnTop") as? Bool
            ?? fallback.object(forKey: "hudAlwaysOnTop") as? Bool
            ?? true

        self.hudCompactMode = prefs.object(forKey: "hudCompactMode") as? Bool
            ?? fallback.object(forKey: "hudCompactMode") as? Bool
            ?? false

        let op = prefs.double(forKey: "hudOpacity") != 0
            ? prefs.double(forKey: "hudOpacity")
            : fallback.double(forKey: "hudOpacity")
        self.hudOpacity = op > 0 ? op : 0.88

        let interval = prefs.integer(forKey: "refreshIntervalMinutes") != 0
            ? prefs.integer(forKey: "refreshIntervalMinutes")
            : fallback.integer(forKey: "refreshIntervalMinutes")
        self.refreshIntervalMinutes = interval > 0 ? interval : 5

        self.codexExecutableOverride = prefs.string(forKey: "codexExecutableOverride")
            ?? fallback.string(forKey: "codexExecutableOverride")
            ?? ""
        self.antigravityExecutableOverride = prefs.string(forKey: "antigravityExecutableOverride")
            ?? fallback.string(forKey: "antigravityExecutableOverride")
            ?? ""

        let profileData = prefs.data(forKey: "codexProfiles") ?? fallback.data(forKey: "codexProfiles")
        if let data = profileData,
           let profiles = try? JSONDecoder().decode([UsageProfile].self, from: data),
           !profiles.isEmpty {
            self.codexProfiles = profiles
        } else {
            self.codexProfiles = Self.discoverCodexProfiles()
            if let data = try? JSONEncoder().encode(self.codexProfiles) {
                prefs.set(data, forKey: "codexProfiles")
                fallback.set(data, forKey: "codexProfiles")
            }
        }

        // Listen for live theme updates across processes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.themeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let newTheme = Self.defaults.string(forKey: "selectedThemeID"),
               newTheme != self?.selectedThemeID {
                self?.selectedThemeID = newTheme
            }
        }

        // Listen for live menu bar settings updates across processes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.menuBarSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let raw = Self.defaults.string(forKey: "menuBarDisplayMode"),
               let mode = MenuBarDisplayMode(rawValue: raw),
               mode != self.menuBarDisplayMode {
                self.menuBarDisplayMode = mode
            }
            if let icon = Self.defaults.object(forKey: "menuBarShowIcon") as? Bool,
               icon != self.menuBarShowIcon {
                self.menuBarShowIcon = icon
            }
        }

        // Listen for live HUD settings updates across processes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.hudSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let enabled = Self.defaults.object(forKey: "hudEnabled") as? Bool,
               enabled != self.hudEnabled {
                self.hudEnabled = enabled
            }
            if let onTop = Self.defaults.object(forKey: "hudAlwaysOnTop") as? Bool,
               onTop != self.hudAlwaysOnTop {
                self.hudAlwaysOnTop = onTop
            }
            if let compact = Self.defaults.object(forKey: "hudCompactMode") as? Bool,
               compact != self.hudCompactMode {
                self.hudCompactMode = compact
            }
            if let opacity = Self.defaults.object(forKey: "hudOpacity") as? Double,
               opacity != self.hudOpacity {
                self.hudOpacity = opacity
            }
        }
    }

    public func selectTheme(_ id: String) {
        self.selectedThemeID = id
    }

    public func selectMenuBarMode(_ mode: MenuBarDisplayMode) {
        self.menuBarDisplayMode = mode
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Could not update Launch at Login: \(error)")
            }
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(codexProfiles) {
            Self.defaults.set(data, forKey: "codexProfiles")
            UserDefaults.standard.set(data, forKey: "codexProfiles")
        }
    }

    public func addProfile(name: String, path: String) {
        let cleanedPath = path.trimmingCharacters(in: .whitespaces)
        let profile = UsageProfile(
            id: UUIDHelper.deterministic(for: "codex:\(cleanedPath)"),
            provider: .codex,
            name: name.trimmingCharacters(in: .whitespaces),
            homePath: cleanedPath
        )
        if !codexProfiles.contains(where: { $0.id == profile.id }) {
            codexProfiles.append(profile)
        }
    }

    public func removeProfile(id: UUID) {
        codexProfiles.removeAll { $0.id == id }
    }

    public func renameProfile(id: UUID, newName: String) {
        if let index = codexProfiles.firstIndex(where: { $0.id == id }) {
            codexProfiles[index].name = newName.trimmingCharacters(in: .whitespaces)
        }
    }

    public static func discoverCodexProfiles() -> [UsageProfile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let baseDir = "\(home)/.codex-profiles"
        var discovered: [UsageProfile] = []

        if let items = try? fm.contentsOfDirectory(atPath: baseDir) {
            for item in items.sorted() {
                let fullPath = "\(baseDir)/\(item)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    if isCodexHome(path: fullPath) {
                        discovered.append(UsageProfile(
                            id: UUIDHelper.deterministic(for: "codex:\(fullPath)"),
                            provider: .codex,
                            name: item.capitalized,
                            homePath: fullPath
                        ))
                    }
                }
            }
        }

        if discovered.isEmpty {
            let defaultCodex = "\(home)/.codex"
            if fm.fileExists(atPath: defaultCodex) && isCodexHome(path: defaultCodex) {
                discovered.append(UsageProfile(
                    id: UUIDHelper.deterministic(for: "codex:\(defaultCodex)"),
                    provider: .codex,
                    name: "Main",
                    homePath: defaultCodex
                ))
            }
        }

        return discovered
    }

    private static func isCodexHome(path: String) -> Bool {
        let fm = FileManager.default
        let markers = ["auth.json", "config.toml", "state.sqlite", "sessions"]
        for marker in markers {
            if fm.fileExists(atPath: "\(path)/\(marker)") {
                return true
            }
        }
        return false
    }
}
