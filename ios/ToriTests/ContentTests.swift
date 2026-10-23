import XCTest
@testable import Tori

/// Loads the real bundled JSON (the web app's `src/data`) and checks it decodes and is internally consistent.
final class ContentTests: XCTestCase {
    private static var content: StudyContent!

    override class func setUp() {
        super.setUp()
        content = try? BundledContentRepository(bundle: Bundle(for: DataStore.self)).load()
    }

    private var c: StudyContent { Self.content }

    func testEverythingDecodes() throws {
        let loaded = try BundledContentRepository(bundle: Bundle(for: DataStore.self)).load()
        XCTAssertEqual(loaded.vocabN5.count, 1402)
        XCTAssertEqual(loaded.vocabN4.count, 1463)
        XCTAssertEqual(loaded.grammarN5.count, 135)
        XCTAssertEqual(loaded.grammarN4.count, 135)
        XCTAssertEqual(loaded.categoriesN5.count, 14)
        XCTAssertEqual(loaded.categoriesN4.count, 18)
        XCTAssertEqual(loaded.kanjiN5.flatMap(\.groups).count, 160)
        XCTAssertEqual(loaded.kanjiN4.flatMap(\.groups).count, 191)
        XCTAssertEqual(loaded.counters?.categories.count, 14)
        XCTAssertEqual(loaded.homophones.count, 14)
        XCTAssertFalse(loaded.verbFormsN5?.forms.isEmpty ?? true)
        XCTAssertFalse(loaded.verbFormsN4?.forms.isEmpty ?? true)
        XCTAssertFalse(loaded.verbFormsN5?.groups?.isEmpty ?? true)
    }

    func testVocabIDsAreUniqueAcrossLevels() {
        let ids = (c.vocabN5 + c.vocabN4).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testRomajiPrecomputedForEveryEntry() {
        XCTAssertEqual(c.romaji.count, c.vocabN5.count + c.vocabN4.count)
    }

    func testEveryGrammarPointBelongsToACategory() {
        for (points, cats, name) in [(c.grammarN5, c.categoriesN5, "N5"), (c.grammarN4, c.categoriesN4, "N4")] {
            let slugs = Set(cats.map(\.slug))
            let orphans = points.filter { !slugs.contains($0.category) }
            XCTAssertTrue(orphans.isEmpty, "\(name) grammar points with no category: \(orphans.map(\.id))")
            XCTAssertEqual(cats.reduce(0) { $0 + $1.count }, points.count, "\(name) category counts")
        }
    }

    /// Two homophone entries in the web data point at vocab ids that do not exist
    /// (a pre-existing data issue). The app is unaffected - it renders the kanji and
    /// meaning embedded in each homophone word - but any *new* dangling id should fail.
    func testHomophoneWordsResolveToVocabExceptKnownDangling() {
        let ids = Set((c.vocabN5 + c.vocabN4).map(\.id))
        let dangling = c.homophones.flatMap(\.words).map(\.vocabId).filter { !ids.contains($0) }
        XCTAssertEqual(Set(dangling), ["n5_0169", "n5_0491"])
    }

    func testKanjiWordIDsAreUniquePerSource() {
        for chapters in [c.kanjiN5, c.kanjiN4] {
            let ids = chapters.flatMap(\.groups).map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count)
        }
    }

    // MARK: Search against real data

    func testRomajiSearchFindsTabemasu() {
        // The vocab list stores verbs in ます-form, so the romaji is "tabemasu".
        let hits = Search.vocab(c.vocabN5, query: "tabemasu", group: nil, pos: nil) { self.c.romaji[$0.id] ?? "" }
        XCTAssertTrue(hits.contains { $0.kanji == "食べます" })
    }

    func testDiacriticInsensitiveMeaningSearch() {
        let hits = Search.vocab(c.vocabN5, query: "viet nam", group: nil, pos: nil) { self.c.romaji[$0.id] ?? "" }
        XCTAssertTrue(hits.contains { $0.kanji == "ベトナム" })
    }

    func testGroupAndPosFilters() {
        let hits = Search.vocab(c.vocabN5, query: "", group: "1", pos: "noun") { _ in "" }
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.allSatisfy { $0.chapter == 1 && $0.pos == "noun" })
    }

    func testGrammarSearchByPattern() {
        let hits = Search.grammar(c.grammarN5, query: "です")
        XCTAssertTrue(hits.contains { $0.id == "g_001" })
    }

    func testKanjiSearchByHanViet() {
        let all = c.kanjiN5.flatMap(\.groups)
        XCTAssertTrue(all.contains { Search.kanjiGroup($0, matches: "nhat") && $0.anchor == "一" })
    }
}

@MainActor
final class DataStoreTests: XCTestCase {
    func testLoadsAndExposesLevelScopedAccessors() async {
        let store = DataStore(repository: BundledContentRepository(bundle: Bundle(for: DataStore.self)))
        XCTAssertEqual(store.state, .loading)
        await store.load()
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(store.vocab(.n5).count, 1402)
        XCTAssertEqual(store.vocab(.all).count, 1402 + 1463)
        XCTAssertEqual(store.grammar(.n4).count, 135)
        XCTAssertNotNil(store.vocabByID["n5_0001"])
        XCTAssertNotNil(store.grammarByID["g_001"])
        XCTAssertEqual(store.kanjiChapters(.all).count, store.kanjiChapters(.n5).count + store.kanjiChapters(.n4).count)
        XCTAssertEqual(store.verbForms(.all).count, 2)
    }

    func testMissingFilesSurfaceAsFailure() async {
        let empty = Bundle(path: FileManager.default.temporaryDirectory.path) ?? Bundle()
        let store = DataStore(repository: BundledContentRepository(bundle: empty))
        await store.load()
        if case .failed = store.state {} else { XCTFail("expected .failed, got \(store.state)") }
    }
}
