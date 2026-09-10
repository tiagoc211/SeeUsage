import XCTest
import Foundation
@testable import SeeUsage

@MainActor
final class FloatingHUDTests: XCTestCase {
    func testHUDSettingsPersistence() {
        let settings = SettingsStore.shared
        let originalEnabled = settings.hudEnabled
        let originalOnTop = settings.hudAlwaysOnTop
        let originalCompact = settings.hudCompactMode
        let originalOpacity = settings.hudOpacity

        defer {
            settings.hudEnabled = originalEnabled
            settings.hudAlwaysOnTop = originalOnTop
            settings.hudCompactMode = originalCompact
            settings.hudOpacity = originalOpacity
        }

        settings.hudEnabled = true
        XCTAssertEqual(settings.hudEnabled, true)

        settings.hudEnabled = false
        XCTAssertEqual(settings.hudEnabled, false)

        settings.hudAlwaysOnTop = false
        XCTAssertEqual(settings.hudAlwaysOnTop, false)

        settings.hudAlwaysOnTop = true
        XCTAssertEqual(settings.hudAlwaysOnTop, true)

        settings.hudCompactMode = true
        XCTAssertEqual(settings.hudCompactMode, true)

        settings.hudCompactMode = false
        XCTAssertEqual(settings.hudCompactMode, false)

        settings.hudOpacity = 0.75
        XCTAssertEqual(settings.hudOpacity, 0.75)
    }

    func testCLIHUDCommands() async {
        let handledStatus = await CLIHandler.handle(arguments: ["seeusage", "hud"])
        XCTAssertTrue(handledStatus)

        let handledOn = await CLIHandler.handle(arguments: ["seeusage", "hud", "on"])
        XCTAssertTrue(handledOn)
        XCTAssertEqual(SettingsStore.shared.hudEnabled, true)

        let handledCompact = await CLIHandler.handle(arguments: ["seeusage", "hud", "compact"])
        XCTAssertTrue(handledCompact)
        XCTAssertEqual(SettingsStore.shared.hudCompactMode, true)

        let handledFull = await CLIHandler.handle(arguments: ["seeusage", "hud", "full"])
        XCTAssertTrue(handledFull)
        XCTAssertEqual(SettingsStore.shared.hudCompactMode, false)

        let handledPin = await CLIHandler.handle(arguments: ["seeusage", "hud", "pin"])
        XCTAssertTrue(handledPin)
        XCTAssertEqual(SettingsStore.shared.hudAlwaysOnTop, true)

        let handledOpacity = await CLIHandler.handle(arguments: ["seeusage", "hud", "80"])
        XCTAssertTrue(handledOpacity)
        XCTAssertEqual(SettingsStore.shared.hudOpacity, 0.8)

        let handledOff = await CLIHandler.handle(arguments: ["seeusage", "hud", "off"])
        XCTAssertTrue(handledOff)
        XCTAssertEqual(SettingsStore.shared.hudEnabled, false)
    }

    func testFloatingHUDManager() {
        let manager = FloatingHUDManager.shared
        manager.show()
        XCTAssertEqual(SettingsStore.shared.hudEnabled, true)

        manager.applySettings()

        manager.hide()
        XCTAssertEqual(SettingsStore.shared.hudEnabled, false)

        manager.toggle()
        XCTAssertEqual(SettingsStore.shared.hudEnabled, true)

        manager.toggle()
        XCTAssertEqual(SettingsStore.shared.hudEnabled, false)
    }
}
