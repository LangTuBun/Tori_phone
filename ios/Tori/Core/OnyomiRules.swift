import Foundation

struct OnyomiExample: Decodable, Hashable, Sendable {
    let kanji: String
    let hanviet: String
    let on: [String]
}

struct OnyomiRule: Decodable, Identifiable, Hashable, Sendable {
    enum Group: String, Decodable, Sendable { case final, initial }
    let id: String
    let group: Group
    let vi: String
    let ja: String
    let total: Int
    let matched: Int
    let rate: Int
    let examples: [OnyomiExample]
    let exceptions: [OnyomiExample]

    private enum CodingKeys: String, CodingKey { case id, group, vi, ja, total, matched, rate, examples, exceptions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        group = try c.decode(Group.self, forKey: .group)
        vi = try c.decode(String.self, forKey: .vi)
        ja = try c.decode(String.self, forKey: .ja)
        total = try c.decode(Int.self, forKey: .total)
        matched = try c.decode(Int.self, forKey: .matched)
        rate = try c.decode(Int.self, forKey: .rate)
        examples = try c.decodeIfPresent([OnyomiExample].self, forKey: .examples) ?? []
        exceptions = try c.decodeIfPresent([OnyomiExample].self, forKey: .exceptions) ?? []
    }
}

/// Han Viet -> on'yomi correspondence rules, measured on the app's own kanji
/// (scripts/build-onyomi-rules.mjs).
struct OnyomiRules: Decodable, Sendable {
    let rules: [OnyomiRule]
    let kanjiRules: [String: [String]]

    static func load(bundle: Bundle = .main) -> OnyomiRules? {
        guard let url = bundle.url(forResource: "onyomi-rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OnyomiRules.self, from: data)
    }

    var finals: [OnyomiRule] { rules.filter { $0.group == .final } }
    var initials: [OnyomiRule] { rules.filter { $0.group == .initial } }

    /// Distinct examples from every rule, the pool the quiz draws from.
    var quizPool: [OnyomiExample] {
        var seen = Set<String>(), out: [OnyomiExample] = []
        for r in rules { for ex in r.examples where seen.insert(ex.kanji).inserted { out.append(ex) } }
        return out
    }

    struct Question: Equatable {
        let example: OnyomiExample
        let options: [String]
    }

    /// "Han Viet Khoa (科) -> which on'yomi?": one right answer, three wrong.
    func makeQuestion(using rng: inout some RandomNumberGenerator) -> Question? {
        let pool = quizPool
        guard let ex = pool.randomElement(using: &rng), let answer = ex.on.first else { return nil }
        let wrong = Array(Set(pool.flatMap(\.on)).subtracting(ex.on)).sorted().shuffled(using: &rng).prefix(3)
        return Question(example: ex, options: ([answer] + wrong).shuffled(using: &rng))
    }
}
