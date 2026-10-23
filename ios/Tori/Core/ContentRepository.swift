import Foundation
import Observation

/// Everything the app reads, decoded once from the bundled JSON.
struct StudyContent: Sendable {
    var vocabN5: [VocabEntry] = []
    var vocabN4: [VocabEntry] = []
    var grammarN5: [GrammarPoint] = []
    var grammarN4: [GrammarPoint] = []
    var categoriesN5: [GrammarCategory] = []
    var categoriesN4: [GrammarCategory] = []
    var kanjiN5: [KanjiChapter] = []
    var kanjiN4: [KanjiChapter] = []
    var verbFormsN5: VerbFormsData?
    var verbFormsN4: VerbFormsData?
    var counters: CountersData?
    var homophones: [HomophoneGroup] = []
    /// Lowercased romaji of each vocab entry's kana, precomputed at load so
    /// per-keystroke search is a dictionary lookup.
    var romaji: [String: String] = [:]
}

/// Seam for the data source. The app ships `BundledContentRepository` (the
/// web app's JSON, read straight from `src/data`); a networked source can be
/// dropped in later without touching any view.
protocol ContentRepository: Sendable {
    func load() throws -> StudyContent
}

enum ContentError: LocalizedError {
    case missing(String)
    case decoding(String, Error)

    var errorDescription: String? {
        switch self {
        case .missing(let p): "Missing bundled data file: \(p)"
        case .decoding(let p, let e): "Could not decode \(p): \(e)"
        }
    }
}

struct BundledContentRepository: ContentRepository, @unchecked Sendable {
    var bundle: Bundle = .main

    private func decode<T: Decodable>(_ type: T.Type, _ name: String, in dir: String) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: dir) else {
            throw ContentError.missing("\(dir)/\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw ContentError.decoding("\(dir)/\(name).json", error)
        }
    }

    private struct CategoriesFile: Decodable { let categories: [GrammarCategory] }

    func load() throws -> StudyContent {
        var c = StudyContent()
        c.vocabN5 = try decode([VocabEntry].self, "vocabulary", in: "n5")
        c.vocabN4 = try decode([VocabEntry].self, "vocabulary", in: "n4")
        c.grammarN5 = try decode([GrammarPoint].self, "grammar", in: "n5")
        c.grammarN4 = try decode([GrammarPoint].self, "grammar", in: "n4")
        c.categoriesN5 = try decode(CategoriesFile.self, "grammar-categories", in: "n5").categories
        c.categoriesN4 = try decode(CategoriesFile.self, "grammar-categories", in: "n4").categories
        c.kanjiN5 = try decode(KanjiFile.self, "kanji", in: "n5").chapters
        c.kanjiN4 = try decode(KanjiFile.self, "kanji", in: "n4").chapters
        c.verbFormsN5 = try decode(VerbFormsData.self, "verb-forms", in: "n5")
        c.verbFormsN4 = try decode(VerbFormsData.self, "verb-forms", in: "n4")
        c.counters = try decode(CountersData.self, "counters", in: "n5")
        c.homophones = try decode([HomophoneGroup].self, "homophones", in: "n5")
        for v in c.vocabN5 + c.vocabN4 {
            c.romaji[v.id] = Romaji.fromKana(v.kana).lowercased()
        }
        return c
    }
}

@MainActor @Observable
final class DataStore {
    enum State: Equatable { case loading, ready, failed(String) }

    private(set) var state: State = .loading
    private(set) var content = StudyContent()
    private(set) var vocabByID: [String: VocabEntry] = [:]
    private(set) var grammarByID: [String: GrammarPoint] = [:]

    private let repository: ContentRepository

    init(repository: ContentRepository = BundledContentRepository()) {
        self.repository = repository
    }

    /// Decodes ~5 MB of JSON off the main thread.
    func load() async {
        guard state != .ready else { return }
        let repo = repository
        do {
            let loaded = try await Task.detached(priority: .userInitiated) { try repo.load() }.value
            content = loaded
            vocabByID = Dictionary(uniqueKeysWithValues: (loaded.vocabN5 + loaded.vocabN4).map { ($0.id, $0) })
            grammarByID = Dictionary(uniqueKeysWithValues: (loaded.grammarN5 + loaded.grammarN4).map { ($0.id, $0) })
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: Level-scoped accessors

    func vocab(_ level: Level) -> [VocabEntry] {
        switch level {
        case .n5: content.vocabN5
        case .n4: content.vocabN4
        case .all: content.vocabN5 + content.vocabN4
        }
    }

    func grammar(_ level: Level) -> [GrammarPoint] {
        switch level {
        case .n5: content.grammarN5
        case .n4: content.grammarN4
        case .all: content.grammarN5 + content.grammarN4
        }
    }

    func categories(_ level: Level) -> [GrammarCategory] {
        switch level {
        case .n5: content.categoriesN5
        case .n4: content.categoriesN4
        case .all: content.categoriesN5 + content.categoriesN4
        }
    }

    func kanjiChapters(_ level: Level) -> [TaggedKanjiChapter] {
        let n5 = content.kanjiN5.map { TaggedKanjiChapter(src: .n5, chapter: $0) }
        let n4 = content.kanjiN4.map { TaggedKanjiChapter(src: .n4, chapter: $0) }
        switch level {
        case .n5: return n5
        case .n4: return n4
        case .all: return n5 + n4
        }
    }

    func verbForms(_ level: Level) -> [(label: String, data: VerbFormsData)] {
        var out: [(String, VerbFormsData)] = []
        if level != .n4, let d = content.verbFormsN5 { out.append(("N5", d)) }
        if level != .n5, let d = content.verbFormsN4 { out.append(("N4", d)) }
        return out
    }

    func romaji(of v: VocabEntry) -> String { content.romaji[v.id] ?? "" }
}
