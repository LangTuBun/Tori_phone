import Foundation

// Codable mirrors of src/types/index.ts. Optional fields match the optional
// fields in the JSON (see the survey in the porting notes): a key that is
// absent on some entries is `Optional`, everything else is required so a
// corrupted data file fails loudly in the unit tests instead of silently.

enum Lang: String, Codable, CaseIterable, Identifiable, Sendable {
    case vi, en
    var id: String { rawValue }
    var label: String { self == .vi ? "Tiếng Việt" : "English" }
}

/// Which textbook ordering the vocabulary follows: Tori's own chapters (the
/// default) or the Minna no Nihongo lessons. Words that exist only in Minna
/// (category "Minna no Nihongo") belong to the Minna book alone.
enum Book: String, Codable, CaseIterable, Identifiable, Sendable {
    case tori, minna
    var id: String { rawValue }

    /// `category` of the words imported from Minna no Nihongo with no Tori chapter.
    static let minnaOnlyCategory = "Minna no Nihongo"

    func includes(_ v: VocabEntry) -> Bool {
        switch self {
        case .tori: v.category != Book.minnaOnlyCategory
        case .minna: v.minna != nil
        }
    }
}

/// `{ vi, en }` content field. `en` is "" on most entries, so lookups fall
/// back to Vietnamese on an empty string (same as `localize()` in i18n.ts).
struct LocalizedText: Codable, Hashable, Sendable {
    var vi: String
    var en: String

    init(vi: String = "", en: String = "") { self.vi = vi; self.en = en }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vi = try c.decodeIfPresent(String.self, forKey: .vi) ?? ""
        en = try c.decodeIfPresent(String.self, forKey: .en) ?? ""
    }

    func text(_ lang: Lang) -> String {
        let v = lang == .en ? en : vi
        return v.isEmpty ? vi : v
    }

    var isEmpty: Bool { vi.isEmpty && en.isEmpty }
}

struct SentenceExample: Codable, Hashable, Sendable {
    var ja: String
    var kana: String?
    var vi: String?
    var en: String?
    var jaRuby: String?

    var translation: LocalizedText { LocalizedText(vi: vi ?? "", en: en ?? "") }
}

// MARK: - Vocabulary

struct VocabEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let kanji: String
    let kana: String
    let meanings: LocalizedText
    let pos: String
    let verbGroup: Int?
    let adjType: String?
    let jlptLevel: String
    let chapter: Int?
    let category: String?
    let minna: Int?
    let tags: [String]
    let homophones: [String]
    let relatedWords: [String]
    let examples: [SentenceExample]
    /// Mora index after which pitch drops; 0 = heiban. nil = unknown.
    let pitch: Int?
}

// MARK: - Grammar

struct ConnectionRule: Codable, Hashable, Sendable {
    let pos: String
    let form: String
    let formVi: String?
    let formEn: String?
    let particle: String?
    let exampleStr: String

    func label(_ lang: Lang) -> String {
        (lang == .en ? formEn : formVi) ?? form
    }
}

struct Pragmatics: Codable, Hashable, Sendable {
    let tones: [String]
    let intent: LocalizedText?
    let emotionalNuance: LocalizedText?
    let speakerStance: LocalizedText?
}

struct PitfallExample: Codable, Hashable, Sendable {
    let incorrect: String
    let correct: String
    let explanation: LocalizedText?
}

struct GrammarPitfall: Codable, Hashable, Sendable {
    let type: String
    let title: LocalizedText
    let description: LocalizedText
    let examples: [PitfallExample]?
    let relatedGrammarId: String?
}

struct RichExample: Codable, Hashable, Sendable {
    let category: String
    let ja: String
    let jaRuby: String?
    let kana: String
    let romaji: String
    let vi: String
    let en: String
    let contextualExplanation: LocalizedText

    var translation: LocalizedText { LocalizedText(vi: vi, en: en) }
}

struct GrammarPoint: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let num: String
    let pattern: String
    let patternRomaji: String?
    let patternRuby: String?
    let meaning: LocalizedText
    let category: String
    let jlptLevel: String?
    let chapter: Int
    let order: Int
    let explanation: LocalizedText
    let examples: [SentenceExample]
    let relatedGrammar: [String]
    let tags: [String]
    let requiredVerbForm: [String]
    let formationRules: [ConnectionRule]?
    let pragmatics: Pragmatics?
    let notesAndPitfalls: [GrammarPitfall]?
    let richExamples: [RichExample]?
    let opposingGrammar: [String]?
}

struct SummaryExample: Codable, Hashable, Sendable {
    let pattern: String
    let ja: String
    let kana: String
    let vi: String
    let en: String
}

struct ChapterSummary: Codable, Hashable, Sendable {
    let vi: String
    let en: String
    let examples: [SummaryExample]?

    var text: LocalizedText { LocalizedText(vi: vi, en: en) }
}

struct GrammarCategory: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let romanNumeral: String
    let order: Int
    let title: LocalizedText
    let titleJa: String?
    let count: Int
    let summary: ChapterSummary?

    var id: String { slug }
}

// MARK: - Kanji

struct KanjiWord: Codable, Hashable, Sendable {
    let kanji: String
    let kana: String
    let hanviet: String
    let meaning: LocalizedText
    let onkun: String
    let curated: Bool?
}

struct KanjiGroup: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let anchor: String
    let kana: String?
    let hanviet: String?
    let meaning: LocalizedText?
    let onkun: String?
    let onyomi: [String]
    let kunyomi: [String]
    let words: [KanjiWord]
}

struct KanjiChapter: Codable, Hashable, Sendable {
    let chapter: Int
    let groupCount: Int
    let wordCount: Int
    let groups: [KanjiGroup]
}

struct KanjiFile: Codable, Sendable {
    let chapters: [KanjiChapter]
}

enum LevelSource: String, Codable, Sendable { case n5 = "N5", n4 = "N4" }

/// A kanji chapter tagged with its source level: N5 chapter 15 and N4 chapter
/// 15 reuse the same `k15_gN` group ids, so review-card ids carry the tag.
struct TaggedKanjiChapter: Identifiable, Hashable, Sendable {
    let src: LevelSource
    let chapter: KanjiChapter
    var id: String { "\(src.rawValue):\(chapter.chapter)" }
}

// MARK: - Counters

struct CounterRow: Codable, Hashable, Sendable {
    let number: String
    let kanji: String
    let kana: String
    let romaji: String?
    let meaning: LocalizedText?
    let note: LocalizedText?
    let isQuestion: Bool?
    let isException: Bool?
}

struct CounterCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: LocalizedText
    let shortTitle: LocalizedText
    let counter: String?
    let counterKana: String?
    let usage: LocalizedText?
    let columns: [String]
    let rows: [CounterRow]
    let footnote: LocalizedText?
    let wide: Bool?
}

struct CounterBigNumberExample: Codable, Hashable, Sendable {
    let kanji: String
    let kana: String
    let romaji: String
    let meaning: LocalizedText
}

struct CountersData: Codable, Sendable {
    let title: LocalizedText
    let intro: LocalizedText
    let categories: [CounterCategory]
    let bigNumberExamples: [CounterBigNumberExample]
}

// MARK: - Homophones

struct HomophoneWord: Codable, Hashable, Sendable {
    let vocabId: String
    let kanji: String
    let meaning: LocalizedText
}

struct HomophoneGroup: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let reading: String
    let words: [HomophoneWord]
    let difficultyScore: Int
}

// MARK: - Verb forms

/// `group` is an Int on most rows and a String ("neg", ...) on a few.
struct FlexID: Codable, Hashable, Sendable {
    let raw: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { raw = String(i) }
        else { raw = try c.decode(String.self) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

struct VerbGroupSample: Codable, Hashable, Sendable {
    let masu: String
    let masuRuby: String?
    let meaning: LocalizedText
}

struct VerbGroup: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: LocalizedText
    let note: LocalizedText
    let sample: [VerbGroupSample]
}

struct VerbFormRule: Codable, Hashable, Sendable {
    let group: FlexID
    let rule: LocalizedText
    let ruleRuby: LocalizedText?
    let note: LocalizedText
    let noteRuby: LocalizedText?
}

struct VerbFormExample: Codable, Hashable, Sendable {
    let group: FlexID
    let masu: String
    let masuRuby: String?
    let result: String
    let resultRuby: String?
    let resultNeg: String?
    let resultNegRuby: String?
}

struct VerbGroup1Ending: Codable, Hashable, Sendable {
    let endings: String
    let endingsRuby: String?
    let result: String
    let resultRuby: String?
    let example: String
    let exampleRuby: String?
}

struct VerbFormSentence: Codable, Hashable, Sendable {
    let ja: String
    let jaRuby: String?
    let meaning: LocalizedText
}

struct VerbForm: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: LocalizedText
    let titleJa: String
    let titleJaRuby: String?
    let meaning: LocalizedText
    let rules: [VerbFormRule]
    let group1Endings: [VerbGroup1Ending]?
    let examples: [VerbFormExample]
    let sentenceExamples: [VerbFormSentence]
    let exceptions: [LocalizedText]
}

struct CheatSheet: Codable, Hashable, Sendable {
    let headers: [LocalizedText]
    let rows: [[LocalizedText]]
}

struct VerbFormsData: Codable, Sendable {
    let groups: [VerbGroup]?
    let forms: [VerbForm]
    let cheatSheet: CheatSheet?
    let keyExceptions: [LocalizedText]?
}

// MARK: - SRS

enum SRSState: String, Codable, Sendable { case new, learning, review, mastered }

struct SRSCard: Codable, Hashable, Sendable {
    var vocabId: String
    var cardType: String
    var interval: Int
    var repetition: Int
    var easeFactor: Double
    var lastReview: Date?
    var nextReview: Date?
    var reviewCount: Int
    var lapseCount: Int
    var state: SRSState

    static func makeDefault(id: String, cardType: String = "kanji-meaning") -> SRSCard {
        SRSCard(vocabId: id, cardType: cardType, interval: 0, repetition: 0,
                easeFactor: 2.5, lastReview: nil, nextReview: nil,
                reviewCount: 0, lapseCount: 0, state: .new)
    }
}
