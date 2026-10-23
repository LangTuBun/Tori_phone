import Foundation

struct VerbHalf: Decodable, Hashable, Sendable {
    let kanji: String
    let kana: String
    let meaning: LocalizedText
    let example: SentenceExample
}

struct TransitivityPattern: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let transitiveEnding: String
    let intransitiveEnding: String
    let description: LocalizedText
}

struct VerbPair: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let patternId: String
    let transitive: VerbHalf
    let intransitive: VerbHalf
    let note: LocalizedText?
}

/// 自動詞 / 他動詞 pairs, exported from src/data/transitivity.ts by
/// scripts/export-ios-data.mjs.
struct TransitivityData: Decodable, Sendable {
    let irregularPatternId: String
    let patterns: [TransitivityPattern]
    let pairs: [VerbPair]

    static func load(bundle: Bundle = .main) -> TransitivityData? {
        guard let url = bundle.url(forResource: "transitivity", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TransitivityData.self, from: data)
    }

    /// Pairs in pattern order, optionally narrowed to one pattern and a query
    /// matched against both verbs' kanji, kana and meanings.
    func pairs(pattern: String?, query: String) -> [VerbPair] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return patterns
            .filter { pattern == nil || $0.id == pattern }
            .flatMap { pt in
                pairs.filter { p in
                    guard p.patternId == pt.id else { return false }
                    guard !q.isEmpty else { return true }
                    let haystack = [p.transitive, p.intransitive].flatMap {
                        [$0.kanji, $0.kana, $0.meaning.vi, $0.meaning.en]
                    }.joined(separator: " ").lowercased()
                    return haystack.contains(q)
                }
            }
    }
}
