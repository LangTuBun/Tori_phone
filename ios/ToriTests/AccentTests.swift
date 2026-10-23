import XCTest
@testable import Tori

final class AccentTests: XCTestCase {
    func testParseSkipsBadLinesAndKeepsAlternatives() {
        let d = AccentDictionary.parse("一\tひと\t0,2\n\n壊れ\n猫\tねこ\t1\n空\t\t0\n")
        XCTAssertEqual(d.rows.map(\.surface), ["一", "猫", "空"])
        XCTAssertEqual(d.rows[0].pitches, [0, 2])
        XCTAssertEqual(d.rows[2].reading, "空", "missing reading falls back to the surface")
    }

    func testSearchRanksExactThenPrefixThenSubstring() {
        let d = AccentDictionary.parse("猫\tねこ\t1\n猫舌\tねこじた\t0\n子猫\tこねこ\t0\n犬\tいぬ\t2\n")
        XCTAssertEqual(d.search("猫").map(\.surface), ["猫", "猫舌", "子猫"])
        XCTAssertEqual(d.search("ネコ").first?.surface, "猫", "katakana query matches hiragana readings")
        XCTAssertEqual(d.search("こね").map(\.surface), ["子猫"])
        XCTAssertTrue(d.search("   ").isEmpty)
        XCTAssertTrue(d.search("zzz").isEmpty)
        XCTAssertEqual(d.search("猫", limit: 1).count, 1)
    }

    func testBundledDictionaryLoadsAndFindsKnownWords() throws {
        let d = try XCTUnwrap(AccentDictionary.load())
        XCTAssertGreaterThan(d.rows.count, 100_000)
        let hit = try XCTUnwrap(d.search("はし").first)
        XCTAssertFalse(hit.pitches.isEmpty)
        XCTAssertLessThanOrEqual(d.search("あ").count, AccentDictionary.maxResults)
    }
}
