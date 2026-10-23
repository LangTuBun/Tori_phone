import XCTest
@testable import Tori

final class UsageTests: XCTestCase {
    func testLoadsAllThreeSections() throws {
        let u = try XCTUnwrap(UsageData.load())
        XCTAssertEqual(u.synonymGroups.count, 10)
        XCTAssertEqual(u.collocationGroups.count, 4)
        XCTAssertEqual(u.auxiliaryVerbs.count, 7)
        XCTAssertTrue(u.synonymGroups.allSatisfy { !$0.words.isEmpty })
    }

    func testBrowsingShowsOneGroupAndSearchSpansAll() throws {
        let u = try XCTUnwrap(UsageData.load())
        XCTAssertEqual(u.synonyms(group: "wear", query: "").map(\.id), ["wear"])
        let found = u.synonyms(group: "wear", query: "履く")
        XCTAssertFalse(found.isEmpty)
        XCTAssertTrue(found.allSatisfy { g in g.words.allSatisfy { w in
            [w.kanji, w.kana, w.meaning.vi, w.meaning.en, w.nuance.vi, w.nuance.en].joined(separator: " ").lowercased().contains("履く")
        } }, "search keeps only matching words")
        XCTAssertTrue(u.synonyms(group: "wear", query: "zzzz").isEmpty)
        XCTAssertEqual(u.auxiliaries(query: "").count, 7)
        XCTAssertFalse(u.auxiliaries(query: "しまう").isEmpty)
    }

    func testCollocationContrastLinksResolve() throws {
        let u = try XCTUnwrap(UsageData.load())
        let entries = u.collocationGroups.flatMap(\.entries)
        XCTAssertFalse(entries.isEmpty)
        for e in entries { if let id = e.contrastId { XCTAssertNotNil(u.collocationPattern(id: id), "\(e.id) -> \(id)") } }
    }
}
