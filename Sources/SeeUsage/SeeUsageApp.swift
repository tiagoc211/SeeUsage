import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("SeeUsage Menu Bar Active")
        setupStatusItem()
        setupPopover()
        observeStore()

        Task { @MainActor in
            await UsageStore.shared.refresh()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let img = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: "SeeUsage")?.withSymbolConfiguration(config)
            button.image = img
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonTitle()
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 460)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView())
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateButtonTitle() {
        guard let button = statusItem.button else { return }
        if let minPct = UsageStore.shared.minRemainingPercent {
            button.title = " \(minPct)%"
        } else {
            button.title = ""
        }
    }

    private func observeStore() {
        NotificationCenter.default.addObserver(
            forName: .usageStoreDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonTitle()
            }
        }
    }
}

@main
struct SeeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        if CommandLine.arguments.contains("--dump") {
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
                CFRunLoopStop(CFRunLoopGetMain())
            }
            CFRunLoopRun()
            exit(0)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
