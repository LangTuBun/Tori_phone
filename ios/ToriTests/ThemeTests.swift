import XCTest
import SwiftUI
@testable import Tori

@MainActor
final class ThemeTests: XCTestCase {
    private func store(_ name: String) -> (SettingsStore, UserDefaults) {
        let d = UserDefaults(suiteName: "tori.tests.\(name)")!
        d.removePersistentDomain(forName: "tori.tests.\(name)")
        return (SettingsStore(defaults: d), d)
    }

    func testEveryThemeIsInExactlyOneMode() {
        XCTAssertEqual(Set(ThemeID.scenes).union(ThemeID.gradients), Set(ThemeID.allCases))
        XCTAssertTrue(Set(ThemeID.scenes).isDisjoint(with: ThemeID.gradients))
        XCTAssertEqual(ThemeID.scenes.count, 5)
        XCTAssertEqual(ThemeID.gradients.count, 3)
    }

    func testDefaultsToTheDuskBackground() {
        let (s, _) = store("default")
        XCTAssertEqual(s.theme, .dusk)
        XCTAssertEqual(s.backgroundMode, .scene)
    }

    func testSwitchingModeRestoresTheLastPickOfThatKind() {
        let (s, d) = store("modes")
        s.theme = .neon                                  // a scene
        s.backgroundMode = .gradient
        XCTAssertEqual(s.theme, .glass, "first time in gradient mode: the default gradient")
        s.theme = .graphite
        s.backgroundMode = .scene
        XCTAssertEqual(s.theme, .neon, "back to the scene that was chosen")
        s.backgroundMode = .gradient
        XCTAssertEqual(s.theme, .graphite)
        XCTAssertEqual(SettingsStore(defaults: d).theme, .graphite, "the choice persists")
    }

    func testPaletteTracksTheChosenThemeForPresentedSheets() {
        let (s, _) = store("palette")
        s.theme = .sakura
        XCTAssertEqual(EnvironmentValues().palette.text, Palette.make(.sakura).text)
        s.theme = .aurora
        XCTAssertEqual(EnvironmentValues().palette.text, Palette.make(.aurora).text)
    }

    func testDarkScenesUseLightTextAndClearGlass() {
        for id in [ThemeID.dusk, .aurora, .neon] {
            XCTAssertTrue(id.isDark)
            XCTAssertTrue(Palette.make(id).clearGlass, "\(id)")
        }
        for id in [ThemeID.sakura, .ink, .glass] { XCTAssertFalse(id.isDark, "\(id)") }
    }
}
