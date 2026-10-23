import Foundation

/// Pure filtering used by the browse screens (kept out of the views so it is unit-tested).
enum Search {
    /// Case- and diacritic-insensitive containment, so "viet nam" finds "Việt Nam".
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func vocab(_ list: [VocabEntry], query: String, group: String?, pos: String?,
                      romaji: (VocabEntry) -> String) -> [VocabEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = fold(q)
        return list.filter { v in
            if let group, Japanese.groupKey(v) != group { return false }
            if let pos, v.pos != pos { return false }
            if q.isEmpty { return true }
            return v.kanji.contains(q) || v.kana.contains(q)
                || romaji(v).contains(q.lowercased())
                || fold(v.meanings.vi).contains(folded) || fold(v.meanings.en).contains(folded)
        }
    }

    static func grammar(_ list: [GrammarPoint], query: String) -> [GrammarPoint] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return list }
        let folded = fold(q)
        return list.filter { g in
            g.pattern.contains(q) || g.num.contains(q)
                || fold(g.patternRomaji ?? "").contains(folded)
                || fold(g.meaning.vi).contains(folded) || fold(g.meaning.en).contains(folded)
                || g.tags.contains { fold($0).contains(folded) }
        }
    }

    static func kanjiGroup(_ g: KanjiGroup, matches query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let folded = fold(q)
        if g.anchor.contains(q) || fold(g.hanviet ?? "").contains(folded) { return true }
        if let m = g.meaning, fold(m.vi).contains(folded) || fold(m.en).contains(folded) { return true }
        if g.onyomi.contains(where: { $0.contains(q) }) || g.kunyomi.contains(where: { $0.contains(q) }) { return true }
        return g.words.contains { w in
            w.kanji.contains(q) || w.kana.contains(q) || fold(w.hanviet).contains(folded)
                || fold(w.meaning.vi).contains(folded) || fold(w.meaning.en).contains(folded)
        }
    }
}
