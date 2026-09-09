import SwiftUI
import AppKit

// MARK: - Single Instance Enforcement
final class SingleInstanceLock {
    private static var lockFileDescriptor: Int32 = -1

    @discardableResult
    static func acquire() -> Bool {
        let lockPath = ("~/.config/seeusage/app.lock" as NSString).expandingTildeInPath
        let folder = (lockPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return false }

        // Try non-blocking exclusive file lock
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }

        // Keep file descriptor open for process lifetime
        lockFileDescriptor = fd
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("SeeUsage Menu Bar Active")
        setupStatusItem()
        setupPopover()
        observeStore()
        observeOpenSettings()

        Task { @MainActor in
            await UsageStore.shared.refresh()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let button = statusItem?.button else { return true }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        SettingsWindowManager.shared.show()
        return true
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

    private func observeOpenSettings() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification),
            name: NSNotification.Name("app.seeusage.openSettings"),
            object: nil
        )
    }

    @objc private func handleOpenSettingsNotification() {
        SettingsWindowManager.shared.show()
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

        // Single instance check for GUI mode
        if !SingleInstanceLock.acquire() {
            let bundleID = Bundle.main.bundleIdentifier ?? "app.seeusage.SeeUsage"
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if #available(macOS 14.0, *) {
                others.first?.activate()
            } else {
                others.first?.activate(options: .activateIgnoringOtherApps)
            }
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("app.seeusage.openSettings"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            exit(0)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
