import XCTest
@testable import Tori

@MainActor
final class BookTests: XCTestCase {
    private func loaded() async -> DataStore {
        let data = DataStore()
        await data.load()
        return data
    }

    func testToriIsTheDefaultBook() {
        XCTAssertEqual(SettingsStore(defaults: nil).book, .tori)
        let suite = UserDefaults(suiteName: "tori.tests.book")!
        suite.removePersistentDomain(forName: "tori.tests.book")
        let s = SettingsStore(defaults: suite)
        s.book = .minna
        XCTAssertEqual(SettingsStore(defaults: suite).book, .minna, "the choice persists")
    }

    func testToriBookHidesMinnaOnlyWords() async {
        let data = await loaded()
        let all = data.allVocab(.all)
        let tori = data.vocab(.all, book: .tori)
        XCTAssertFalse(tori.contains { $0.category == Book.minnaOnlyCategory })
        XCTAssertEqual(all.count - tori.count, all.filter { $0.category == Book.minnaOnlyCategory }.count)
        XCTAssertEqual(tori.count, 1800, "Tori's own words: 2865 in total minus 1065 Minna-only")
    }

    func testMinnaBookIsExactlyTheLessonTaggedWords() async {
        let data = await loaded()
        let minna = data.vocab(.all, book: .minna)
        XCTAssertTrue(minna.allSatisfy { $0.minna != nil })
        XCTAssertEqual(minna.count, data.allVocab(.all).filter { $0.minna != nil }.count)
        let lessons = Set(minna.compactMap(\.minna))
        XCTAssertEqual(lessons, Set(1...50), "Minna book covers lessons 1-50")
        XCTAssertTrue(minna.contains { $0.category == Book.minnaOnlyCategory }, "Minna-only words live here")
    }

    func testTheTwoBooksNeverShowTheSameWordTwice() async {
        let data = await loaded()
        for book in Book.allCases {
            let words = data.vocab(.all, book: book)
            XCTAssertEqual(Set(words.map(\.id)).count, words.count, "\(book): ids are unique")
        }
    }

    func testGroupKeyFollowsTheBook() async {
        let data = await loaded()
        let v = data.vocab(.n5, book: .minna).first { $0.chapter != nil && $0.minna != nil }!
        XCTAssertEqual(Japanese.groupKey(v, book: .minna), String(v.minna!))
        XCTAssertEqual(Japanese.groupKey(v, book: .tori), String(v.chapter!))
    }

    func testSearchHonoursTheBookGrouping() async {
        let data = await loaded()
        let minna = data.vocab(.n5, book: .minna)
        let hits = Search.vocab(minna, query: "", group: "1", pos: nil,
                                groupKey: { Japanese.groupKey($0, book: .minna) }) { _ in "" }
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.allSatisfy { $0.minna == 1 })
    }
}

@MainActor
final class SearchVariantTests: XCTestCase {
    private func words() async -> [VocabEntry] {
        let data = DataStore()
        await data.load()
        return data.allVocab(.all)
    }

    func testKanaOnlyDuplicateCollapsesIntoTheKanjiEntry() async {
        let all = await words()
        let usos = all.filter { $0.kana == "うそ" }
        XCTAssertEqual(usos.count, 2, "the data holds うそ and 嘘")
        let collapsed = Search.collapsingVariants(usos)
        XCTAssertEqual(collapsed.map(\.kanji), ["嘘"])
        let hazukashii = all.filter { $0.kana == "はずかしい" }
        XCTAssertEqual(Search.collapsingVariants(hazukashii).map(\.kanji), ["恥ずかしい"])
    }

    func testDifferentWordsWithTheSameReadingStayApart() async {
        let all = await words()
        for kana in ["あつい", "なくなる", "ふたり", "やる", "ええ", "はし", "かえる", "かわく", "こむ"] {
            let group = all.filter { $0.kana == kana }
            XCTAssertGreaterThan(group.count, 1, kana)
            XCTAssertEqual(Search.collapsingVariants(group).count, group.count, "\(kana) has different words and must not merge")
        }
    }

    func testOnlyTwoEntriesInTheWholeDatasetCollapse() async {
        let all = await words()
        XCTAssertEqual(all.count - Search.collapsingVariants(all).count, 2, "うそ and はずかしい only")
    }

    func testOrderIsPreserved() async {
        let all = await words()
        let collapsed = Search.collapsingVariants(all)
        let ids = collapsed.map(\.id)
        XCTAssertEqual(ids, all.map(\.id).filter(Set(ids).contains))
    }
}
