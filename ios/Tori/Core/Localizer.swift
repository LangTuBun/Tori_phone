import Foundation

/// Dot-path string lookup into the web app's `src/locales/{vi,en}.json`
/// (bundled as-is), plus a few iOS-only strings. Falls back to Vietnamese,
/// then to the key itself so a missing translation stays visible.
final class Localizer: @unchecked Sendable {
    static let shared = Localizer()

    private var tables: [Lang: [String: String]] = [:]

    init(bundle: Bundle = .main) {
        for lang in Lang.allCases {
            var flat: [String: String] = [:]
            if let url = bundle.url(forResource: lang.rawValue, withExtension: "json", subdirectory: "locales"),
               let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                Self.flatten(obj, prefix: "", into: &flat)
            }
            for (k, v) in Self.extra[lang] ?? [:] { flat[k] = v }
            tables[lang] = flat
        }
    }

    private static func flatten(_ obj: Any, prefix: String, into out: inout [String: String]) {
        if let dict = obj as? [String: Any] {
            for (k, v) in dict { flatten(v, prefix: prefix.isEmpty ? k : prefix + "." + k, into: &out) }
        } else if let s = obj as? String {
            out[prefix] = s
        }
    }

    func t(_ lang: Lang, _ key: String, _ vars: [String: CustomStringConvertible] = [:]) -> String {
        var s = tables[lang]?[key] ?? tables[.vi]?[key] ?? key
        for (name, value) in vars { s = s.replacingOccurrences(of: "{\(name)}", with: String(describing: value)) }
        return s
    }

    // iOS-only strings (tab bar, themes, rating buttons, ...). The web locale
    // files remain the source of truth for everything they already contain.
    private static let extra: [Lang: [String: String]] = [
        .vi: [
            "ios.more": "Thêm",
            "ios.greeting.morning": "おはよう", "ios.greeting.day": "こんにちは", "ios.greeting.evening": "こんばんは",
            "ios.rating.again": "Quên", "ios.rating.hard": "Khó", "ios.rating.good": "Tốt", "ios.rating.easy": "Dễ",
            "ios.theme.glass": "Glass", "ios.theme.graphite": "Graphite", "ios.theme.midnight": "Midnight", "ios.theme.dusk": "Dusk", "ios.theme.aurora": "Aurora", "ios.theme.neon": "Neon", "ios.theme.sakura": "Sakura", "ios.theme.ink": "Ink",
            "ios.settings.title": "Cài đặt",
            "ios.settings.theme": "Giao diện",
            "ios.settings.themeDescription": "Ba tông kính mờ. Midnight là chế độ tối.",
            "ios.settings.data": "Dữ liệu học",
            "ios.settings.resetProgress": "Xoá toàn bộ tiến độ",
            "ios.settings.resetConfirm": "Xoá toàn bộ thẻ ôn tập và mẫu ngữ pháp đã học trên thiết bị này?",
            "ios.settings.cancel": "Huỷ",
            "ios.settings.reviewed": "Đã ôn {n} lượt",
            "ios.loading": "Đang tải dữ liệu…",
            "ios.loadFailed": "Không tải được dữ liệu",
            "ios.noResults": "Không có kết quả",
            "ios.showFurigana": "Furigana",
            "ios.counters.title": "Đếm số",
            "ios.homophones.reveal": "Hiện đáp án",
            "ios.homophones.challenge": "Thử thách",
            "ios.verbForms.title": "Chia động từ",
            "ios.verbForms.groups": "Nhóm động từ",
            "ios.verbForms.forms": "Các thể",
            "ios.verbForms.rules": "Quy tắc",
            "ios.verbForms.examples": "Ví dụ",
            "ios.dueToday": "thẻ cần ôn",
            "ios.vocab.allGroups": "Tất cả chương/chủ đề",
            "ios.vocab.count": "{n} từ",
            "ios.kanji.words": "{n} từ",
            "ios.kanji.onyomi": "Âm On",
            "ios.kanji.kunyomi": "Âm Kun",
            "ios.counters.n5only": "Chỉ có dữ liệu N5",
            "ios.done": "Xong",
        ],
        .en: [
            "ios.more": "More",
            "ios.greeting.morning": "おはよう", "ios.greeting.day": "こんにちは", "ios.greeting.evening": "こんばんは",
            "ios.rating.again": "Again", "ios.rating.hard": "Hard", "ios.rating.good": "Good", "ios.rating.easy": "Easy",
            "ios.theme.glass": "Glass", "ios.theme.graphite": "Graphite", "ios.theme.midnight": "Midnight", "ios.theme.dusk": "Dusk", "ios.theme.aurora": "Aurora", "ios.theme.neon": "Neon", "ios.theme.sakura": "Sakura", "ios.theme.ink": "Ink",
            "ios.settings.title": "Settings",
            "ios.settings.theme": "Appearance",
            "ios.settings.themeDescription": "Three frosted-glass tones. Midnight is the dark mode.",
            "ios.settings.data": "Study data",
            "ios.settings.resetProgress": "Erase all progress",
            "ios.settings.resetConfirm": "Erase every review card and learned grammar point on this device?",
            "ios.settings.cancel": "Cancel",
            "ios.settings.reviewed": "{n} reviews done",
            "ios.loading": "Loading data…",
            "ios.loadFailed": "Could not load data",
            "ios.noResults": "No results",
            "ios.showFurigana": "Furigana",
            "ios.counters.title": "Counters",
            "ios.homophones.reveal": "Reveal",
            "ios.homophones.challenge": "Challenge",
            "ios.verbForms.title": "Verb forms",
            "ios.verbForms.groups": "Verb groups",
            "ios.verbForms.forms": "Forms",
            "ios.verbForms.rules": "Rules",
            "ios.verbForms.examples": "Examples",
            "ios.dueToday": "cards due",
            "ios.vocab.allGroups": "All chapters/categories",
            "ios.vocab.count": "{n} words",
            "ios.kanji.words": "{n} words",
            "ios.kanji.onyomi": "On readings",
            "ios.kanji.kunyomi": "Kun readings",
            "ios.counters.n5only": "N5 data only",
            "ios.done": "Done",
        ],
    ]
}
