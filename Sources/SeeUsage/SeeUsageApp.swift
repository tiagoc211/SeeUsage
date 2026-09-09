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
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonContent()
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

    private func updateButtonContent() {
        guard let button = statusItem?.button else { return }
        let store = UsageStore.shared
        let settings = SettingsStore.shared
        let minPct = store.minRemainingPercent

        switch settings.menuBarDisplayMode {
        case .percent:
            if settings.menuBarShowIcon {
                let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
                button.image = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: "SeeUsage")?.withSymbolConfiguration(config)
                button.imagePosition = .imageLeading
            } else {
                button.image = nil
                button.imagePosition = .noImage
            }
            if let p = minPct {
                button.title = settings.menuBarShowIcon ? " \(p)%" : "\(p)%"
            } else {
                button.title = settings.menuBarShowIcon ? "" : "--%"
            }

        case .dual:
            let cxPct = store.codexLowestPercent
            let agPct = store.antigravityLowestPercent

            if settings.menuBarShowIcon {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                button.image = NSImage(systemSymbolName: "bolt.horizontal.fill", accessibilityDescription: "SeeUsage")?.withSymbolConfiguration(config)
                button.imagePosition = .imageLeading
            } else {
                button.image = nil
                button.imagePosition = .noImage
            }

            let cxStr = cxPct.map { "cx: \($0)%" } ?? "cx: --"
            let agStr = agPct.map { "ag: \($0)%" } ?? "ag: --"
            let dualText = "\(cxStr) · \(agStr)"
            button.title = settings.menuBarShowIcon ? " \(dualText)" : dualText

        case .gauge:
            let pct = minPct.map { Double($0) } ?? 100.0
            let gaugeImg = renderMicroGaugeImage(percent: pct)
            button.image = gaugeImg
            button.imagePosition = .imageLeading

            if let p = minPct {
                button.title = " \(p)%"
            } else {
                button.title = " --%"
            }

        case .iconOnly:
            let pct = minPct.map { Double($0) }
            let dotImg = renderStatusDotImage(percent: pct)
            button.image = dotImg
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    private func renderMicroGaugeImage(percent: Double) -> NSImage {
        let width: CGFloat = 28
        let height: CGFloat = 9
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            // Outer pill track
            let trackPath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
            NSColor.labelColor.withAlphaComponent(0.18).setFill()
            trackPath.fill()

            // Progress fill
            let clamped = max(0.0, min(100.0, percent))
            let fillWidth = max(clamped > 0 ? 2.5 : 0.0, (width - 1.0) * CGFloat(clamped / 100.0))
            let fillRect = NSRect(x: 0.5, y: 0.5, width: fillWidth, height: height - 1.0)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.0, yRadius: 2.0)

            let fillColor: NSColor
            if clamped <= 15.0 {
                fillColor = NSColor(Color(hex: "#f54752")) // Red
            } else if clamped <= 35.0 {
                fillColor = NSColor(Color(hex: "#fa9e2e")) // Amber
            } else {
                fillColor = NSColor(Color(hex: "#00e599")) // Green / Emerald
            }
            fillColor.setFill()
            fillPath.fill()

            // Subtle border
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            trackPath.lineWidth = 0.6
            trackPath.stroke()

            return true
        }
        img.isTemplate = false
        return img
    }

    private func renderStatusDotImage(percent: Double?) -> NSImage {
        let size: CGFloat = 16
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let dotDiameter: CGFloat = 8.5
            let dotRect = NSRect(
                x: (size - dotDiameter) / 2.0,
                y: (size - dotDiameter) / 2.0,
                width: dotDiameter,
                height: dotDiameter
            )
            let dotPath = NSBezierPath(ovalIn: dotRect)

            let dotColor: NSColor
            if let p = percent {
                if p <= 15.0 {
                    dotColor = NSColor(Color(hex: "#f54752"))
                } else if p <= 35.0 {
                    dotColor = NSColor(Color(hex: "#fa9e2e"))
                } else {
                    dotColor = NSColor(Color(hex: "#00e599"))
                }
            } else {
                dotColor = NSColor.secondaryLabelColor
            }

            // Outer soft glow ring
            let ringRect = dotRect.insetBy(dx: -1.8, dy: -1.8)
            let ringPath = NSBezierPath(ovalIn: ringRect)
            dotColor.withAlphaComponent(0.22).setFill()
            ringPath.fill()

            // Solid core dot
            dotColor.setFill()
            dotPath.fill()

            return true
        }
        img.isTemplate = false
        return img
    }

    private func observeStore() {
        NotificationCenter.default.addObserver(
            forName: .usageStoreDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonContent()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .menuBarSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonContent()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.menuBarSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonContent()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.themeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonContent()
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
