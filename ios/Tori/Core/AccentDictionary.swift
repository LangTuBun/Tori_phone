import Foundation

struct AccentRow: Identifiable, Hashable, Sendable {
    let id: Int
    let surface: String
    let reading: String
    /// Comma-separated alternatives in the source; the first is the primary.
    let pitches: [Int]
    /// `reading` in hiragana, folded once at load so search never re-folds.
    let readingKey: String
}

/// Pitch-accent dictionary over the Kanjium dataset (CC BY-SA, compiled from
/// NHK's accent dictionary and Wadoku): ~124k headwords, a separate resource
/// only the Accent screen loads.
struct AccentDictionary: Sendable {
    let rows: [AccentRow]

    static let maxResults = 60

    static func parse(_ tsv: String) -> AccentDictionary {
        var rows: [AccentRow] = []
        rows.reserveCapacity(125_000)
        for line in tsv.split(whereSeparator: \.isNewline) {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 3, !cols[0].isEmpty, !cols[2].isEmpty else { continue }
            let pitches = cols[2].split(separator: ",").compactMap { Int($0) }
            guard !pitches.isEmpty else { continue }
            let surface = String(cols[0])
            let reading = cols[1].isEmpty ? surface : String(cols[1])
            rows.append(AccentRow(id: rows.count, surface: surface, reading: reading, pitches: pitches,
                                  readingKey: KanjiText.katakanaToHiragana(reading)))
        }
        return AccentDictionary(rows: rows)
    }

    static func load(bundle: Bundle = .main) -> AccentDictionary? {
        guard let url = bundle.url(forResource: "kanjium-accents", withExtension: "tsv"),
              let tsv = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(tsv)
    }

    /// Exact match first, then prefix, then substring; shorter readings win ties.
    func search(_ query: String, limit: Int = AccentDictionary.maxResults) -> [AccentRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let qk = KanjiText.katakanaToHiragana(q)
        var scored: [(score: Int, row: AccentRow)] = []
        for r in rows {
            let score: Int
            if r.surface == q || r.readingKey == qk { score = 0 }
            else if r.surface.hasPrefix(q) || r.readingKey.hasPrefix(qk) { score = 1 }
            else if r.surface.contains(q) || r.readingKey.contains(qk) { score = 2 }
            else { continue }
            scored.append((score, r))
        }
        scored.sort { $0.score != $1.score ? $0.score < $1.score : $0.row.reading.count < $1.row.reading.count }
        return scored.prefix(limit).map(\.row)
    }
}
