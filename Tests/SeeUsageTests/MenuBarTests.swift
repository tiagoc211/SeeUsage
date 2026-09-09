import XCTest
@testable import SeeUsage

final class MenuBarTests: XCTestCase {
    @MainActor
    func testMenuBarDisplayModeProperties() {
        XCTAssertEqual(MenuBarDisplayMode.percent.id, "percent")
        XCTAssertEqual(MenuBarDisplayMode.dual.id, "dual")
        XCTAssertEqual(MenuBarDisplayMode.gauge.id, "gauge")
        XCTAssertEqual(MenuBarDisplayMode.iconOnly.id, "iconOnly")

        XCTAssertEqual(MenuBarDisplayMode.percent.title, "Lowest Quota")
        XCTAssertEqual(MenuBarDisplayMode.dual.title, "Dual Quotas")
        XCTAssertEqual(MenuBarDisplayMode.gauge.title, "Mini Gauge")
        XCTAssertEqual(MenuBarDisplayMode.iconOnly.title, "Icon Only")

        XCTAssertTrue(!MenuBarDisplayMode.percent.subtitle.isEmpty)
        XCTAssertTrue(!MenuBarDisplayMode.dual.subtitle.isEmpty)
        XCTAssertTrue(!MenuBarDisplayMode.gauge.subtitle.isEmpty)
        XCTAssertTrue(!MenuBarDisplayMode.iconOnly.subtitle.isEmpty)
    }

    @MainActor
    func testSettingsStoreMenuBarModePersistence() {
        let settings = SettingsStore.shared
        let originalMode = settings.menuBarDisplayMode

        settings.selectMenuBarMode(.dual)
        XCTAssertEqual(settings.menuBarDisplayMode, .dual)
        XCTAssertEqual(SettingsStore.defaults.string(forKey: "menuBarDisplayMode"), "dual")

        settings.selectMenuBarMode(.gauge)
        XCTAssertEqual(settings.menuBarDisplayMode, .gauge)
        XCTAssertEqual(SettingsStore.defaults.string(forKey: "menuBarDisplayMode"), "gauge")

        // Restore
        settings.selectMenuBarMode(originalMode)
    }

    @MainActor
    func testCLIHandlerModeCommand() async {
        let handledList = await CLIHandler.handle(arguments: ["seeusage", "mode"])
        XCTAssertTrue(handledList)

        let handledSet = await CLIHandler.handle(arguments: ["seeusage", "mode", "dual"])
        XCTAssertTrue(handledSet)
        XCTAssertEqual(SettingsStore.shared.menuBarDisplayMode, .dual)

        // Restore to percent
        let handledRestore = await CLIHandler.handle(arguments: ["seeusage", "mode", "percent"])
        XCTAssertTrue(handledRestore)
        XCTAssertEqual(SettingsStore.shared.menuBarDisplayMode, .percent)
    }
}
