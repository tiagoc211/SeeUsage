import SwiftUI

@main
struct SeeUsageApp: App {
    @State private var store = UsageStore.shared

    init() {
        if CommandLine.arguments.contains("--dump") {
            let sema = DispatchSemaphore(value: 0)
            Task { @MainActor in
                let settings = SettingsStore.shared
                print("=== SEEUSAGE LIVE QUOTA DUMP ===")
                print("Perfis Codex configurados: \(settings.codexProfiles.count)")
                for p in settings.codexProfiles {
                    print(" - Perfil: \(p.name) (\(p.homePath ?? ""))")
                }

                await UsageStore.shared.refresh()

                for profile in settings.codexProfiles {
                    print("\n--- CODEX: \(profile.name) ---")
                    if let snap = UsageStore.shared.snapshots[profile.id] {
                        if let plan = snap.plan {
                            print("Plano: \(plan)")
                        }
                        if let err = snap.error {
                            print("Erro: \(err)")
                        }
                        for w in snap.windows {
                            let pct = w.remainingPercent.map { "\(Int(round($0)))%" } ?? "--"
                            let reset = w.resetsAt.map { Formatters.resetDescription(for: $0) } ?? "sem reset"
                            print(" [\(w.label)] Restante: \(pct) | \(reset)")
                        }
                    }
                }

                let agyID = SettingsStore.antigravityProfileID
                print("\n--- ANTIGRAVITY ---")
                if let agySnap = UsageStore.shared.snapshots[agyID] {
                    if let err = agySnap.error {
                        print("Erro: \(err)")
                    }
                    for w in agySnap.windows {
                        let pct = w.remainingPercent.map { "\(Int(round($0)))%" } ?? "--"
                        let reset = w.resetsAt.map { Formatters.resetDescription(for: $0) } ?? "sem reset"
                        let scope = w.scope ?? "Geral"
                        print(" [\(scope) - \(w.label)] Restante: \(pct) | \(reset)")
                    }
                }

                if let minQuota = UsageStore.shared.minRemainingPercent {
                    print("\nMenor quota na Menu Bar: \(minQuota)%")
                }
                print("================================")
                sema.signal()
            }
            sema.wait()
            exit(0)
        }

        Task { @MainActor in
            await UsageStore.shared.refresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.needle")
                if let pct = store.minRemainingPercent {
                    Text("\(pct)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Definições", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
