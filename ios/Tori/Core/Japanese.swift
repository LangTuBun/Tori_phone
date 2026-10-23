import Foundation

enum Level: String, Codable, CaseIterable, Identifiable, Sendable {
    case n5 = "N5", n4 = "N4", all = "all"
    var id: String { rawValue }
    var label: String { self == .all ? "N5+N4" : rawValue }
}

/// Ports of the helpers in src/lib/japanese.ts and src/lib/vocab-grouping.ts.
enum Japanese {
    static func isKanji(_ ch: Character) -> Bool {
        ch.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || $0.value == 0x3005 }
    }

    static func hasKanji(_ s: String) -> Bool { s.contains(where: isKanji) }

    static func posLabel(_ pos: String) -> String {
        let map = [
            "noun": "N", "verb-group1": "V1", "verb-group2": "V2", "verb-group3": "V3",
            "adj-i": "i-adj", "adj-na": "na-adj", "adverb": "Adv", "pronoun": "Pron",
            "conjunction": "Conj", "expression": "Exp", "interjection": "Int",
            "suffix": "Suf", "determiner": "Det", "unknown": "?",
        ]
        return map[pos] ?? pos
    }

    // MARK: Pitch accent

    private static let smallKana: Set<Character> = Set("ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ")

    /// Small kana attach to the preceding character; ん/っ/ー are their own mora.
    static func splitMorae(_ kana: String) -> [String] {
        var morae: [String] = []
        for ch in kana {
            if smallKana.contains(ch), !morae.isEmpty {
                morae[morae.count - 1].append(ch)
            } else {
                morae.append(String(ch))
            }
        }
        return morae
    }

    /// Per-mora high/low for a Tokyo-dialect pattern, plus the level of the
    /// mora after the word (heiban stays high, odaka drops).
    static func pitchLevels(moraCount: Int, pitch: Int) -> (levels: [Bool], afterHigh: Bool) {
        var levels: [Bool] = []
        for i in 1...max(moraCount, 1) where moraCount > 0 {
            if pitch == 0 { levels.append(i != 1) }
            else if pitch == 1 { levels.append(i == 1) }
            else { levels.append(i != 1 && i <= pitch) }
        }
        return (levels, pitch == 0)
    }

    enum PitchType: String { case heiban, atamadaka, nakadaka, odaka }

    static func classifyPitch(_ pitch: Int, moraCount: Int) -> PitchType {
        if pitch == 0 { return .heiban }
        if pitch == 1 { return .atamadaka }
        if pitch == moraCount { return .odaka }
        return .nakadaka
    }

    // MARK: Vocab grouping

    /// Chapter number where one exists, thematic category otherwise, "?" if neither.
    static func groupKey(_ v: VocabEntry) -> String {
        if let c = v.chapter, c > 0 { return String(c) }
        return v.category ?? "?"
    }

    static func isChapterKey(_ k: String) -> Bool { !k.isEmpty && k != "?" && Int(k) != nil }

    /// Chapter numbers first (numeric), then category names, "?" last.
    static func compareGroupKeys(_ a: String, _ b: String) -> Bool {
        if a == "?" { return false }
        if b == "?" { return true }
        switch (Int(a), Int(b)) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.localizedCompare(b) == .orderedAscending
        }
    }
}

// MARK: - Ruby (furigana) markup

struct RubySegment: Hashable, Identifiable {
    let id: Int
    let base: String
    let reading: String?
}

/// Parses the `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>` markup the
/// data files use (`jaRuby`, `patternRuby`, ...). Plain runs are split per
/// character so a flow layout can wrap Japanese text anywhere.
enum RubyParser {
    static func parse(_ html: String) -> [RubySegment] {
        var raw: [(String, String?)] = []
        var rest = Substring(html)
        while !rest.isEmpty {
            guard let open = rest.range(of: "<ruby>") else {
                raw.append((String(rest), nil)); break
            }
            let plain = rest[..<open.lowerBound]
            if !plain.isEmpty { raw.append((String(plain), nil)) }
            rest = rest[open.upperBound...]
            let close = rest.range(of: "</ruby>")
            let inner = close.map { rest[..<$0.lowerBound] } ?? rest
            rest = close.map { rest[$0.upperBound...] } ?? ""
            raw += parseInner(String(inner))
        }
        var out: [RubySegment] = []
        for (base, reading) in raw {
            if let reading {
                out.append(RubySegment(id: out.count, base: base, reading: reading))
            } else {
                for ch in base { out.append(RubySegment(id: out.count, base: String(ch), reading: nil)) }
            }
        }
        return out
    }

    private static func parseInner(_ inner: String) -> [(String, String?)] {
        var s = Substring(stripping(inner, open: "<rp>", close: "</rp>"))
        var result: [(String, String?)] = []
        while let rt = s.range(of: "<rt>") {
            let base = String(s[..<rt.lowerBound])
            let after = s[rt.upperBound...]
            guard let end = after.range(of: "</rt>") else { break }
            result.append((base, String(after[..<end.lowerBound])))
            s = after[end.upperBound...]
        }
        if !s.isEmpty { result.append((String(s), nil)) }
        return result
    }

    private static func stripping(_ s: String, open: String, close: String) -> String {
        var out = s
        while let o = out.range(of: open), let c = out.range(of: close, range: o.upperBound..<out.endIndex) {
            out.removeSubrange(o.lowerBound..<c.upperBound)
        }
        return out
    }

    /// The text with all markup removed (used for plain-text fallbacks).
    static func plain(_ html: String) -> String {
        parse(html).map(\.base).joined()
    }

    static func hasRuby(_ html: String) -> Bool { html.contains("<ruby>") }
}
