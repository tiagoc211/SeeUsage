import AppKit
import SwiftUI

@MainActor
public final class FloatingHUDManager: NSObject, NSWindowDelegate {
    public static let shared = FloatingHUDManager()

    private var panel: NSPanel?
    private static let framePrefKey = "app.seeusage.floatingHUDFrame"

    private override init() {
        super.init()
        setupDistributedObserver()
    }

    private func setupDistributedObserver() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.toggleHUD"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.showHUD"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.show()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.hideHUD"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.seeusage.hudSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applySettings()
            }
        }
    }

    public var isVisible: Bool {
        panel?.isVisible == true
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        SettingsStore.shared.hudEnabled = true

        if let p = panel {
            applySettings()
            p.orderFrontRegardless()
            return
        }

        createAndShowPanel()
    }

    public func hide() {
        SettingsStore.shared.hudEnabled = false
        savePanelPosition()
        panel?.orderOut(nil)
    }

    private func createAndShowPanel() {
        let hostingController = NSHostingController(rootView: FloatingHUDView())

        let p = NSPanel(
            contentRect: calculateInitialFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.contentViewController = hostingController
        p.isFloatingPanel = true
        p.level = SettingsStore.shared.hudAlwaysOnTop ? .floating : .normal
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.delegate = self
        p.hidesOnDeactivate = false

        self.panel = p
        applyContentSize(to: p)
        p.orderFrontRegardless()
    }

    public func applySettings() {
        guard let p = panel else {
            if SettingsStore.shared.hudEnabled {
                createAndShowPanel()
            }
            return
        }

        if !SettingsStore.shared.hudEnabled {
            p.orderOut(nil)
            return
        }

        applyContentSize(to: p)
        p.level = SettingsStore.shared.hudAlwaysOnTop ? .floating : .normal
        if !p.isVisible {
            p.orderFrontRegardless()
        }
    }

    private func calculateInitialFrame() -> NSRect {
        if let saved = UserDefaults.standard.string(forKey: Self.framePrefKey) {
            let rect = NSRectFromString(saved)
            if rect.width > 0 && rect.height > 0 {
                // Verify rect is on an available screen
                let isVisibleOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
                if isVisibleOnScreen {
                    return rect
                }
            }
        }

        // Default to top-right of main screen
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let size = desiredContentSize
        let defaultWidth = size.width
        let defaultHeight = size.height
        let x = screenRect.maxX - defaultWidth - 24
        let y = screenRect.maxY - defaultHeight - 24

        return NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight)
    }

    private var desiredContentSize: NSSize {
        SettingsStore.shared.hudCompactMode
            ? NSSize(width: 360, height: 64)
            : NSSize(width: 380, height: 300)
    }

    private func applyContentSize(to panel: NSPanel) {
        let size = desiredContentSize
        guard panel.frame.size != size else { return }
        var frame = panel.frame
        frame.size = size
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) }) {
            frame.origin.x = min(max(frame.origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - size.width)
            frame.origin.y = min(max(frame.origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - size.height)
        }
        panel.setFrame(frame, display: true, animate: true)
        savePanelPosition()
    }

    private func savePanelPosition() {
        guard let p = panel else { return }
        UserDefaults.standard.set(NSStringFromRect(p.frame), forKey: Self.framePrefKey)
    }

    // MARK: - NSWindowDelegate
    public func windowDidMove(_ notification: Notification) {
        savePanelPosition()
    }

    public func windowWillClose(_ notification: Notification) {
        savePanelPosition()
    }
}
