import Foundation
import Observation

/// A kanji from the textbook anchors or the wider readings dictionary,
/// with pre-folded keys for fast search (port of src/lib/kanji-search.ts).
struct KanjiRecord: Identifiable, Hashable, Sendable {
    let char: String
    let hanviet: String?
    let meaning: LocalizedText
    let on: [String]
    let kun: [String]
    let anchor: KanjiAnchor?
    let hvKey: String
    let textKey: String
    let kanaKey: String
    var id: String { char }
}

/// A textbook "leading kanji" with its group, level and chapter.
struct KanjiAnchor: Hashable, Sendable {
    let group: KanjiGroup
    let src: LevelSource
    let chapter: Int
}

struct Radical: Decodable, Identifiable, Hashable, Sendable {
    let glyph: String
    let hanviet: String
    let meaning: String
    let strokes: Int
    var id: String { glyph + hanviet }
}

enum KanjiText {
    /// Tone-insensitive fold: "Hán" -> "han", "Đức" -> "duc".
    static func stripTone(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    static func katakanaToHiragana(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            (0x30A1...0x30F6).contains(u.value) ? Unicode.Scalar(u.value - 0x60)! : u
        }))
    }

    static func isKanji(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
    }

    /// kanjiapi marks bound forms with a leading/trailing "-"; strip and dedupe.
    static func cleanReadings(_ readings: [String]) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for r in readings {
            var s = r
            if s.hasPrefix("-") { s.removeFirst() }
            if s.hasSuffix("-") { s.removeLast() }
            if seen.insert(s).inserted { out.append(s) }
        }
        return out
    }
}

struct RadicalName: Decodable, Hashable, Sendable {
    let hanviet: String
    let meaning: String
}

private struct ReadingsFallback: Decodable {
    let on: [String]
    let kun: [String]
    let meanings: LocalizedText
}

/// Kanji dictionary shared by Radicals, Kanji rules and Kanji lookup. Built
/// once, off the main thread, from the bundled JSON.
@MainActor @Observable
final class KanjiLibrary {
    private(set) var records: [KanjiRecord] = []
    private(set) var radicals: [Radical] = []
    /// bothu.pdf names for radicals and components (亻, 氵, ...), by glyph.
    private(set) var radicalNames: [String: RadicalName] = [:]
    /// Han Viet -> on'yomi rules, for "which rules does this kanji follow".
    private(set) var onyomi: OnyomiRules?
    /// Kanji the app has data for (anchors + readings), used for radical examples.
    private(set) var known: Set<String> = []
    /// Prev/next order: textbook anchors in chapter order, then everything else.
    private(set) var order: [String] = []
    private var byChar: [String: KanjiRecord] = [:]
    private(set) var ready = false
    private var loading = false

    func record(_ char: String) -> KanjiRecord? { byChar[char] }

    /// Han Viet for any kanji, including ones outside the app's kanji lists.
    func hanviet(_ char: String) -> String? { byChar[char]?.hanviet }

    /// Rules this kanji's Han Viet -> on'yomi follows (measured in build-onyomi-rules.mjs).
    func rules(for char: String) -> [OnyomiRule] {
        guard let onyomi, let ids = onyomi.kanjiRules[char] else { return [] }
        let byID = Dictionary(onyomi.rules.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
    }

    func load(chapters: [TaggedKanjiChapter]) async {
        guard !ready, !loading else { return }
        loading = true
        defer { loading = false }
        let built = await Task.detached(priority: .utility) { Self.build(chapters: chapters) }.value
        records = built.records
        radicals = built.radicals
        radicalNames = built.radicalNames
        onyomi = built.onyomi
        known = built.known
        order = built.order
        byChar = Dictionary(built.records.map { ($0.char, $0) }, uniquingKeysWith: { a, _ in a })
        ready = true
    }

    /// Kanji typed directly -> those kanji; otherwise Han Viet (toned or not),
    /// then readings (kana), then meaning text.
    func search(_ query: String, limit: Int = 60) -> [KanjiRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(records.prefix(limit)) }
        let typed = q.filter(KanjiText.isKanji).map(String.init)
        if !typed.isEmpty { return typed.compactMap { byChar[$0] } }
        let plain = KanjiText.stripTone(q)
        let kana = KanjiText.katakanaToHiragana(q)
        let toned = q.lowercased()
        let hasKana = kana.unicodeScalars.contains { (0x3041...0x3096).contains($0.value) }
        var scored: [(KanjiRecord, Int)] = []
        for r in records {
            var score = 0
            if let hv = r.hanviet, hv.lowercased() == toned { score = 100 }
            else if r.hvKey == plain { score = 90 }
            else if !plain.isEmpty, r.hvKey.hasPrefix(plain) { score = 60 }
            else if hasKana, r.kanaKey.split(separator: " ").contains(where: { $0 == kana || $0.hasPrefix(kana) }) { score = 50 }
            else if plain.count >= 2, r.textKey.contains(plain) { score = 30 }
            if score > 0 { scored.append((r, score)) }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    // MARK: Build

    private struct Built: Sendable {
        var records: [KanjiRecord]
        var radicals: [Radical]
        var radicalNames: [String: RadicalName]
        var onyomi: OnyomiRules?
        var known: Set<String>
        var order: [String]
    }

    nonisolated private static func resource<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    nonisolated private static func build(chapters: [TaggedKanjiChapter]) -> Built {
        let hanvietDict = resource("hanviet-dictionary", as: [String: String].self) ?? [:]
        let readings = resource("kanji-readings", as: [String: ReadingsFallback].self) ?? [:]
        let radicals = resource("radicals", as: [Radical].self) ?? []

        // Anchors: first occurrence wins (N5 chapters come before N4).
        var anchors: [String: KanjiAnchor] = [:]
        var anchorOrder: [String] = []
        var wordIndex: [String: String] = [:]
        func consider(_ kanji: String?, _ hanviet: String?) {
            guard let kanji, let hanviet else { return }
            let chars = kanji.filter(KanjiText.isKanji).map(String.init)
            let syl = hanviet.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard !chars.isEmpty, chars.count == syl.count else { return }
            for (c, s) in zip(chars, syl) where wordIndex[c] == nil { wordIndex[c] = s }
        }
        for tagged in chapters {
            for g in tagged.chapter.groups {
                if anchors[g.anchor] == nil {
                    anchors[g.anchor] = KanjiAnchor(group: g, src: tagged.src, chapter: tagged.chapter.chapter)
                    anchorOrder.append(g.anchor)
                }
                consider(g.anchor, g.hanviet)
                for w in g.words { consider(w.kanji, w.hanviet) }
            }
        }

        let chars = Set(hanvietDict.keys).union(readings.keys).union(anchors.keys)
        let records: [KanjiRecord] = chars.map { ch in
            let anchor = anchors[ch]
            let fb = readings[ch]
            let meaning = anchor?.group.meaning ?? fb?.meanings ?? LocalizedText()
            let on = KanjiText.cleanReadings(anchor?.group.onyomi ?? fb?.on ?? [])
            let kun = KanjiText.cleanReadings(anchor?.group.kunyomi ?? fb?.kun ?? [])
            let hv = hanvietDict[ch] ?? wordIndex[ch]
            return KanjiRecord(
                char: ch, hanviet: hv, meaning: meaning, on: on, kun: kun, anchor: anchor,
                hvKey: hv.map(KanjiText.stripTone) ?? "",
                textKey: KanjiText.stripTone("\(meaning.vi) \(meaning.en)"),
                kanaKey: KanjiText.katakanaToHiragana((on + kun).map { $0.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "") }.joined(separator: " ")))
        }
        // Stable order: anchors first (chapter order), the rest by code point.
        let anchorSet = Set(anchorOrder)
        let rest = chars.subtracting(anchorSet).sorted()
        let order = anchorOrder + rest
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return Built(records: records.sorted { rank[$0.char]! < rank[$1.char]! },
                     radicals: radicals,
                     radicalNames: resource("radical-names", as: [String: RadicalName].self) ?? [:],
                     onyomi: OnyomiRules.load(),
                     known: Set(anchors.keys).union(readings.keys),
                     order: order)
    }
}
