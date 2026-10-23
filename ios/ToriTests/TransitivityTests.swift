import XCTest
@testable import Tori

final class TransitivityTests: XCTestCase {
    func testLoadsPatternsAndPairs() throws {
        let t = try XCTUnwrap(TransitivityData.load())
        XCTAssertEqual(t.patterns.count, 8)
        XCTAssertEqual(t.pairs.count, 35)
        let ids = Set(t.patterns.map(\.id))
        XCTAssertTrue(t.pairs.allSatisfy { ids.contains($0.patternId) }, "every pair belongs to a pattern")
        XCTAssertTrue(ids.contains(t.irregularPatternId))
    }

    func testFilterByPatternAndQuery() throws {
        let t = try XCTUnwrap(TransitivityData.load())
        XCTAssertEqual(t.pairs(pattern: nil, query: "").count, t.pairs.count)
        let aru = t.pairs(pattern: "aru-eru", query: "")
        XCTAssertFalse(aru.isEmpty)
        XCTAssertTrue(aru.allSatisfy { $0.patternId == "aru-eru" })
        XCTAssertTrue(t.pairs(pattern: nil, query: "あがる").contains { $0.id == "ageru-agaru" }, "matches the intransitive kana")
        XCTAssertTrue(t.pairs(pattern: nil, query: "上げる").contains { $0.id == "ageru-agaru" }, "matches the transitive kanji")
        XCTAssertTrue(t.pairs(pattern: "aru-eru", query: "zzzz").isEmpty)
    }
}
