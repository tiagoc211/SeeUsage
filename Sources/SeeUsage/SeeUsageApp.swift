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
        popover.contentSize = NSSize(width: 370, height: 460)
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
        let args = CommandLine.arguments
        let isInvokedFromCLI = args.count > 1 || (args.first?.hasSuffix("/seeusage") == true && isatty(fileno(stdout)) != 0)

        if isInvokedFromCLI {
            Task { @MainActor in
                _ = await CLIHandler.handle(arguments: args)
                CFRunLoopStop(CFRunLoopGetMain())
                exit(0)
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
