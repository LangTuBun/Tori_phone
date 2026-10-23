import Foundation

struct SynonymWord: Decodable, Identifiable, Hashable, Sendable {
    let kanji: String
    let kana: String
    let pos: String
    let verbGroup: String?
    let meaning: LocalizedText
    let nuance: LocalizedText
    let example: SentenceExample
    var id: String { kanji }
}

struct SynonymGroup: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let glossJa: String
    let title: LocalizedText
    let note: LocalizedText?
    let words: [SynonymWord]
}

struct CollocationVerb: Decodable, Hashable, Sendable {
    let kanji: String
    let kana: String
    let meaning: LocalizedText
}

struct CollocationEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let pattern: String
    let particle: String
    let verb: CollocationVerb
    let explanation: LocalizedText
    let example: SentenceExample
    let contrastId: String?
    let trap: LocalizedText?
}

struct CollocationGroup: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: LocalizedText
    let description: LocalizedText
    let entries: [CollocationEntry]
}

struct AuxiliaryVerb: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let pattern: String
    let colloquial: String?
    let meaning: LocalizedText
    let nuance: LocalizedText
    let examples: [SentenceExample]
    let trap: LocalizedText?
    let grammarIds: [String]?
}

/// Similar words, verb + particle pairs and 〜て auxiliaries, exported from
/// src/data/usage.ts by scripts/export-ios-data.mjs.
struct UsageData: Decodable, Sendable {
    let synonymGroups: [SynonymGroup]
    let collocationGroups: [CollocationGroup]
    let auxiliaryVerbs: [AuxiliaryVerb]

    static func load(bundle: Bundle = .main) -> UsageData? {
        guard let url = bundle.url(forResource: "usage", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UsageData.self, from: data)
    }

    private static func hay(_ parts: [String?]) -> String { parts.compactMap { $0 }.joined(separator: " ").lowercased() }

    /// Searching looks across every group and keeps only matching words;
    /// without a query the chosen group is shown whole.
    func synonyms(group: String, query: String) -> [SynonymGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return synonymGroups.filter { $0.id == group } }
        return synonymGroups.compactMap { g in
            let words = g.words.filter {
                Self.hay([$0.kanji, $0.kana, $0.meaning.vi, $0.meaning.en, $0.nuance.vi, $0.nuance.en]).contains(q)
            }
            return words.isEmpty ? nil : SynonymGroup(id: g.id, glossJa: g.glossJa, title: g.title, note: g.note, words: words)
        }
    }

    func collocations(group: String, query: String) -> [CollocationGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return collocationGroups.filter { $0.id == group } }
        return collocationGroups.compactMap { g in
            let entries = g.entries.filter {
                Self.hay([$0.pattern, $0.verb.kanji, $0.verb.kana, $0.verb.meaning.vi, $0.verb.meaning.en,
                          $0.explanation.vi, $0.explanation.en]).contains(q)
            }
            return entries.isEmpty ? nil : CollocationGroup(id: g.id, title: g.title, description: g.description, entries: entries)
        }
    }

    func auxiliaries(query: String) -> [AuxiliaryVerb] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return auxiliaryVerbs }
        return auxiliaryVerbs.filter {
            Self.hay([$0.pattern, $0.colloquial, $0.meaning.vi, $0.meaning.en, $0.nuance.vi, $0.nuance.en]).contains(q)
        }
    }

    func collocationPattern(id: String) -> String? {
        collocationGroups.lazy.flatMap(\.entries).first { $0.id == id }?.pattern
    }
}
