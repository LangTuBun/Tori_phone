import XCTest
@testable import Tori

@MainActor
final class KanjiLibraryTests: XCTestCase {
    private func loadedLibrary() async throws -> KanjiLibrary {
        let data = DataStore()
        await data.load()
        let lib = KanjiLibrary()
        await lib.load(chapters: data.kanjiChapters(.all))
        XCTAssertTrue(lib.ready)
        return lib
    }

    func testLoadsRadicalsAndRecords() async throws {
        let lib = try await loadedLibrary()
        XCTAssertEqual(lib.radicals.count, 214)
        XCTAssertGreaterThan(lib.records.count, 1000)
        XCTAssertEqual(lib.order.count, lib.records.count)
        XCTAssertNotNil(lib.record("日")?.anchor, "textbook anchors carry their group")
    }

    func testSearchByKanjiHanVietKanaAndMeaning() async throws {
        let lib = try await loadedLibrary()
        XCTAssertEqual(lib.search("日").first?.char, "日")
        XCTAssertTrue(lib.search("nhat").contains { $0.char == "日" }, "tone-insensitive Han Viet")
        XCTAssertTrue(lib.search("Nhật").contains { $0.char == "日" })
        XCTAssertTrue(lib.search("ニチ").contains { $0.char == "日" }, "katakana query matches readings")
        XCTAssertTrue(lib.search("にち").contains { $0.char == "日" })
        XCTAssertTrue(lib.search("xyzzy-nothing").isEmpty)
    }

    func testCleanReadingsStripsBoundFormMarkersAndDedupes() {
        XCTAssertEqual(KanjiText.cleanReadings(["-あ.がり", "うわ-", "うわ"]), ["あ.がり", "うわ"])
        XCTAssertEqual(KanjiText.stripTone("Đức Hán"), "duc han")
        XCTAssertEqual(KanjiText.katakanaToHiragana("ニチ"), "にち")
    }
}

final class OnyomiRulesTests: XCTestCase {
    func testLoadsRulesAndBuildsQuestions() throws {
        let rules = try XCTUnwrap(OnyomiRules.load())
        XCTAssertFalse(rules.finals.isEmpty)
        XCTAssertFalse(rules.initials.isEmpty)
        XCTAssertEqual(rules.finals.count + rules.initials.count, rules.rules.count)
        XCTAssertTrue(rules.rules.allSatisfy { $0.matched <= $0.total && (0...100).contains($0.rate) })

        var rng = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let q = try XCTUnwrap(rules.makeQuestion(using: &rng))
            XCTAssertEqual(q.options.count, 4)
            XCTAssertEqual(Set(q.options).count, 4, "options are distinct")
            XCTAssertTrue(q.options.contains(q.example.on[0]), "the answer is offered")
            XCTAssertEqual(q.options.filter { q.example.on.contains($0) }.count, 1, "exactly one right option")
        }
    }
}
