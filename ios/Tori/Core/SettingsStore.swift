import SwiftUI
import Observation

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case glass, graphite, midnight
    var id: String { rawValue }
    var isDark: Bool { self == .midnight }
}

@MainActor @Observable
final class SettingsStore {
    var lang: Lang { didSet { defaults?.set(lang.rawValue, forKey: Keys.lang) } }
    var level: Level { didSet { defaults?.set(level.rawValue, forKey: Keys.level) } }
    var theme: ThemeID { didSet { defaults?.set(theme.rawValue, forKey: Keys.theme) } }

    private let defaults: UserDefaults?
    private let localizer: Localizer

    private enum Keys {
        static let lang = "tori-lang", level = "tori-level", theme = "tori-theme"
    }

    /// `defaults == nil` keeps settings in memory (tests / UI-test launches).
    init(defaults: UserDefaults? = .standard, localizer: Localizer = .shared) {
        self.defaults = defaults
        self.localizer = localizer
        lang = defaults?.string(forKey: Keys.lang).flatMap(Lang.init) ?? .vi
        level = defaults?.string(forKey: Keys.level).flatMap(Level.init) ?? .n5
        theme = defaults?.string(forKey: Keys.theme).flatMap(ThemeID.init) ?? .glass
    }

    /// Reads `lang`, so any view calling this re-renders when the language changes.
    func t(_ key: String, _ vars: [String: CustomStringConvertible] = [:]) -> String {
        localizer.t(lang, key, vars)
    }

    func text(_ value: LocalizedText?) -> String { value?.text(lang) ?? "" }
}
