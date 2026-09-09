import Foundation
import XCTest
@testable import SeeUsage

final class ThemeTests {
    func testThemesRegistration() {
        XCTAssertEqual(ThemeRegistry.allThemes.count, 10)

        let ids = ThemeRegistry.allThemes.map(\.id)
        XCTAssertTrue(ids.contains("t3-default"))
        XCTAssertTrue(ids.contains("t3-ocean"))
        XCTAssertTrue(ids.contains("t3-grove"))
        XCTAssertTrue(ids.contains("t3-iris"))
        XCTAssertTrue(ids.contains("t3-ember"))
        XCTAssertTrue(ids.contains("tokyo-night"))
        XCTAssertTrue(ids.contains("cyberpunk"))
        XCTAssertTrue(ids.contains("palenight"))
        XCTAssertTrue(ids.contains("dracula"))
        XCTAssertTrue(ids.contains("solarized"))
    }

    func testThemeLookupAndFallback() {
        let ocean = ThemeRegistry.theme(for: "t3-ocean")
        XCTAssertEqual(ocean.name, "Ocean")
        XCTAssertEqual(ocean.category, "Core Themes")

        let oceanAlias = ThemeRegistry.theme(for: "ocean")
        XCTAssertEqual(oceanAlias.id, "t3-ocean")

        let emeraldAlias = ThemeRegistry.theme(for: "emerald")
        XCTAssertEqual(emeraldAlias.id, "t3-default")

        let unknown = ThemeRegistry.theme(for: "non-existent-theme")
        XCTAssertEqual(unknown.id, "t3-default")
        XCTAssertEqual(unknown.name, "Emerald")
    }

    func testSettingsStoreThemeSelection() {
        let store = SettingsStore.shared
        let original = store.selectedThemeID

        store.selectTheme("t3-grove")
        XCTAssertEqual(store.selectedThemeID, "t3-grove")
        XCTAssertEqual(store.currentTheme.name, "Grove")
        XCTAssertEqual(SettingsStore.defaults.string(forKey: "selectedThemeID"), "t3-grove")

        // Restore original
        store.selectTheme(original)
    }
}
