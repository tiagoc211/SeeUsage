import Foundation
import Observation

@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    public static let antigravityProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public var refreshIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes")
        }
    }

    public var codexExecutableOverride: String {
        didSet {
            UserDefaults.standard.set(codexExecutableOverride, forKey: "codexExecutableOverride")
        }
    }

    public var antigravityExecutableOverride: String {
        didSet {
            UserDefaults.standard.set(antigravityExecutableOverride, forKey: "antigravityExecutableOverride")
        }
    }

    public var codexProfiles: [UsageProfile] {
        didSet {
            saveProfiles()
        }
    }

    public init() {
        let defaults = UserDefaults.standard

        let interval = defaults.integer(forKey: "refreshIntervalMinutes")
        self.refreshIntervalMinutes = interval > 0 ? interval : 5

        self.codexExecutableOverride = defaults.string(forKey: "codexExecutableOverride") ?? ""
        self.antigravityExecutableOverride = defaults.string(forKey: "antigravityExecutableOverride") ?? ""

        if let data = defaults.data(forKey: "codexProfiles"),
           let profiles = try? JSONDecoder().decode([UsageProfile].self, from: data) {
            self.codexProfiles = profiles
        } else {
            self.codexProfiles = Self.discoverCodexProfiles()
            if let data = try? JSONEncoder().encode(self.codexProfiles) {
                defaults.set(data, forKey: "codexProfiles")
            }
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(codexProfiles) {
            UserDefaults.standard.set(data, forKey: "codexProfiles")
        }
    }

    public func addProfile(name: String, path: String) {
        let profile = UsageProfile(
            id: UUID(),
            provider: .codex,
            name: name.trimmingCharacters(in: .whitespaces),
            homePath: path.trimmingCharacters(in: .whitespaces)
        )
        codexProfiles.append(profile)
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
        var discovered: [UsageProfile] = []

        let profilesDir = "\(home)/.codex-profiles"
        if let items = try? fm.contentsOfDirectory(atPath: profilesDir) {
            for item in items.sorted() {
                let fullPath = "\(profilesDir)/\(item)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    if isCodexHome(path: fullPath) {
                        discovered.append(UsageProfile(
                            id: UUID(),
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
                    id: UUID(),
                    provider: .codex,
                    name: "Principal",
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
