import SwiftUI
import Observation

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    // Backgrounds: painted scenes (glass has real detail to refract).
    case dusk, aurora, neon, sakura, ink
    // Gradients: soft colour fields.
    case glass, graphite, midnight

    var id: String { rawValue }
    var isScene: Bool { Self.scenes.contains(self) }
    var isDark: Bool { self == .midnight || self == .dusk || self == .aurora || self == .neon }

    static let scenes: [ThemeID] = [.dusk, .aurora, .neon, .sakura, .ink]
    static let gradients: [ThemeID] = [.glass, .graphite, .midnight]
}

/// The two ways to dress the app: a colour gradient, or a painted background.
enum BackgroundMode: String, CaseIterable, Identifiable {
    case gradient, scene
    var id: String { rawValue }
}

@MainActor @Observable
final class SettingsStore {
    var lang: Lang { didSet { defaults?.set(lang.rawValue, forKey: Keys.lang) } }
    var level: Level { didSet { defaults?.set(level.rawValue, forKey: Keys.level) } }
    var theme: ThemeID {
        didSet {
            defaults?.set(theme.rawValue, forKey: theme.isScene ? Keys.lastScene : Keys.lastGradient)
            defaults?.set(theme.rawValue, forKey: Keys.theme)
            Palette.current = Palette.make(theme)
        }
    }
    /// Tori's chapters by default; Minna no Nihongo only when chosen.
    var book: Book { didSet { defaults?.set(book.rawValue, forKey: Keys.book) } }

    private let defaults: UserDefaults?
    private let localizer: Localizer

    private enum Keys {
        static let lang = "tori-lang", level = "tori-level", theme = "tori-theme", book = "tori-book"
        static let lastScene = "tori-theme-scene", lastGradient = "tori-theme-gradient"
    }

    /// `defaults == nil` keeps settings in memory (tests / UI-test launches).
    init(defaults: UserDefaults? = .standard, localizer: Localizer = .shared) {
        self.defaults = defaults
        self.localizer = localizer
        lang = defaults?.string(forKey: Keys.lang).flatMap(Lang.init) ?? .vi
        level = defaults?.string(forKey: Keys.level).flatMap(Level.init) ?? .n5
        theme = defaults?.string(forKey: Keys.theme).flatMap(ThemeID.init) ?? .dusk
        book = defaults?.string(forKey: Keys.book).flatMap(Book.init) ?? .tori
        Palette.current = Palette.make(theme)
    }

    /// Gradient or painted background. Switching restores the last pick of that kind.
    var backgroundMode: BackgroundMode {
        get { theme.isScene ? .scene : .gradient }
        set {
            guard newValue != backgroundMode else { return }
            let key = newValue == .scene ? Keys.lastScene : Keys.lastGradient
            let remembered = defaults?.string(forKey: key).flatMap(ThemeID.init)
            theme = remembered ?? (newValue == .scene ? .dusk : .glass)
        }
    }

    /// Reads `lang`, so any view calling this re-renders when the language changes.
    func t(_ key: String, _ vars: [String: CustomStringConvertible] = [:]) -> String {
        localizer.t(lang, key, vars)
    }

    func text(_ value: LocalizedText?) -> String { value?.text(lang) ?? "" }
}

extension SettingsStore {
    /// Inline bilingual copy for screens ported from the web app, which keeps
    /// their text in the page (`L(vi, en)`) instead of in the locale files.
    func l(_ vi: String, _ en: String) -> String { lang == .en ? en : vi }
}
