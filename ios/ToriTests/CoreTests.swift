import XCTest
@testable import Tori

// MARK: - SM-2 (expected values worked out by hand from src/lib/srs.ts)

final class SRSTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAgainIsALapse() {
        let c = SRS.schedule(.makeDefault(id: "a"), rating: .again, now: now)
        XCTAssertEqual(c.interval, 1)
        XCTAssertEqual(c.repetition, 0)
        XCTAssertEqual(c.lapseCount, 1)
        XCTAssertEqual(c.state, .learning)
        XCTAssertEqual(c.easeFactor, 1.7, accuracy: 1e-9)   // 2.5 + (0.1 - 5*(0.08 + 5*0.02))
    }

    func testGoodIntervalLadder() {
        var c = SRSCard.makeDefault(id: "a")
        var intervals: [Int] = []
        for _ in 0..<4 {
            c = SRS.schedule(c, rating: .good, now: now)
            intervals.append(c.interval)
        }
        // 1, 6, round(6*2.5)=15, round(15*2.5)=38 (37.5 rounds up, like Math.round)
        XCTAssertEqual(intervals, [1, 6, 15, 38])
        XCTAssertEqual(c.easeFactor, 2.5, accuracy: 1e-9)   // q=4 leaves EF unchanged
        XCTAssertEqual(c.state, .mastered)
        XCTAssertEqual(c.reviewCount, 4)
    }

    func testStateBecomesReviewBelow21Days() {
        let c = SRS.schedule(.makeDefault(id: "a"), rating: .good, now: now)
        XCTAssertEqual(c.state, .review)
    }

    func testEaseFactorHardAndEasy() {
        XCTAssertEqual(SRS.schedule(.makeDefault(id: "a"), rating: .hard, now: now).easeFactor, 2.36, accuracy: 1e-9)
        XCTAssertEqual(SRS.schedule(.makeDefault(id: "a"), rating: .easy, now: now).easeFactor, 2.6, accuracy: 1e-9)
    }

    func testEaseFactorFloor() {
        var c = SRSCard.makeDefault(id: "a")
        for _ in 0..<10 { c = SRS.schedule(c, rating: .again, now: now) }
        XCTAssertEqual(c.easeFactor, 1.3, accuracy: 1e-9)
    }

    func testNextReviewIsIntervalDaysAway() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = SRS.schedule(.makeDefault(id: "a"), rating: .good, now: now, calendar: cal)
        XCTAssertEqual(c.nextReview, cal.date(byAdding: .day, value: 1, to: now))
        XCTAssertEqual(c.lastReview, now)
    }

    func testIsDue() {
        XCTAssertTrue(SRS.isDue(.makeDefault(id: "a"), now: now))                 // new
        let c = SRS.schedule(.makeDefault(id: "a"), rating: .good, now: now)
        XCTAssertFalse(SRS.isDue(c, now: now))
        XCTAssertTrue(SRS.isDue(c, now: now.addingTimeInterval(2 * 86_400)))
    }
}

// MARK: - Romaji / Japanese helpers

final class JapaneseTests: XCTestCase {
    func testRomaji() {
        let cases = [
            ("たべる", "taberu"), ("がっこう", "gakkou"), ("きょう", "kyou"), ("ちょっと", "chotto"),
            ("まっちゃ", "matcha"), ("コーヒー", "koohii"), ("ファイル", "fairu"), ("にほん", "nihon"),
            ("しんぶん", "shinbun"), ("ベトナム", "betonamu"),
        ]
        for (kana, expected) in cases { XCTAssertEqual(Romaji.fromKana(kana), expected, kana) }
    }

    func testRomajiPassesThroughUnknownCharacters() {
        XCTAssertEqual(Romaji.fromKana("日本ab"), "日本ab")
    }

    func testMoraeKeepSmallKanaAttached() {
        XCTAssertEqual(Japanese.splitMorae("きょうと"), ["きょ", "う", "と"])
        XCTAssertEqual(Japanese.splitMorae("がっこう"), ["が", "っ", "こ", "う"])
    }

    func testPitchPatterns() {
        XCTAssertEqual(Japanese.pitchLevels(moraCount: 3, pitch: 0).levels, [false, true, true])    // heiban
        XCTAssertEqual(Japanese.pitchLevels(moraCount: 3, pitch: 1).levels, [true, false, false])   // atamadaka
        XCTAssertEqual(Japanese.pitchLevels(moraCount: 4, pitch: 2).levels, [false, true, false, false])
        XCTAssertTrue(Japanese.pitchLevels(moraCount: 3, pitch: 0).afterHigh)
        XCTAssertEqual(Japanese.classifyPitch(3, moraCount: 3), .odaka)
        XCTAssertEqual(Japanese.classifyPitch(2, moraCount: 4), .nakadaka)
    }

    func testGroupKeyOrdering() {
        let keys = ["?", "Food", "10", "2", "Animals"]
        XCTAssertEqual(keys.sorted(by: Japanese.compareGroupKeys), ["2", "10", "Animals", "Food", "?"])
        XCTAssertTrue(Japanese.isChapterKey("12"))
        XCTAssertFalse(Japanese.isChapterKey("?"))
        XCTAssertFalse(Japanese.isChapterKey("Food"))
    }

    func testRubyParsing() {
        let html = "私は<ruby>学生<rp>(</rp><rt>がくせい</rt><rp>)</rp></ruby>です。"
        let segs = RubyParser.parse(html)
        XCTAssertEqual(segs.map(\.base), ["私", "は", "学生", "で", "す", "。"])
        XCTAssertEqual(segs.map(\.reading), [nil, nil, "がくせい", nil, nil, nil])
        XCTAssertEqual(RubyParser.plain(html), "私は学生です。")
        XCTAssertTrue(RubyParser.hasRuby(html))
        XCTAssertFalse(RubyParser.hasRuby("私は学生です"))
    }

    func testRubyPerCharacterReadings() {
        let segs = RubyParser.parse("<ruby>学<rt>がく</rt>生<rt>せい</rt></ruby>")
        XCTAssertEqual(segs.map(\.base), ["学", "生"])
        XCTAssertEqual(segs.map(\.reading), ["がく", "せい"])
    }
}

// MARK: - Localizer

final class LocalizerTests: XCTestCase {
    private let loc = Localizer(bundle: Bundle(for: DataStore.self))

    func testLookupInBundledLocales() {
        XCTAssertEqual(loc.t(.vi, "nav.home"), "Trang chủ")
        XCTAssertEqual(loc.t(.vi, "review.rating.forgot"), "Chưa thuộc")
    }

    func testInterpolation() {
        XCTAssertEqual(loc.t(.vi, "common.chapterN", ["n": 7]), "Chương 7")
    }

    func testMissingKeyReturnsKey() {
        XCTAssertEqual(loc.t(.vi, "does.not.exist"), "does.not.exist")
    }

    func testIOSStringsExistInBothLanguages() {
        XCTAssertEqual(loc.t(.vi, "ios.rating.again"), "Quên")
        XCTAssertEqual(loc.t(.en, "ios.rating.again"), "Again")
    }

    func testLocalizedTextFallsBackToVietnamese() {
        let t = LocalizedText(vi: "mưa", en: "")
        XCTAssertEqual(t.text(.en), "mưa")
        XCTAssertEqual(LocalizedText(vi: "mưa", en: "rain").text(.en), "rain")
    }
}

// MARK: - Progress persistence

@MainActor
final class ProgressStoreTests: XCTestCase {
    func testReviewUpdatesCardAndCounter() {
        let store = ProgressStore(fileURL: nil)
        store.review("n5_0001", cardType: "meaning", rating: .good)
        XCTAssertEqual(store.card("n5_0001").state, .review)
        XCTAssertEqual(store.card("n5_0001").cardType, "meaning")
        XCTAssertEqual(store.totalReviewed, 1)
    }

    func testQueriesPartitionCards() {
        let store = ProgressStore(fileURL: nil)
        let now = Date()
        store.review("a", cardType: "x", rating: .again, now: now.addingTimeInterval(-3 * 86_400)) // learning, due
        store.review("b", cardType: "x", rating: .good, now: now)                                    // review, not due
        let ids = ["a", "b", "c"]
        XCTAssertEqual(store.dueCards(in: ids).map(\.vocabId), ["a"])
        XCTAssertEqual(store.scheduledCards(in: ids).map(\.vocabId), ["b"])
        XCTAssertEqual(store.newCards(in: ids).map(\.vocabId), ["c"])
        XCTAssertEqual(store.newCards(in: ["c", "d", "e"], limit: 2).count, 2)
    }

    func testRoundTripThroughDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tori-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = ProgressStore(fileURL: url)
        a.review("n5_0002", cardType: "word", rating: .easy)
        a.toggleLearned("g_001")

        let b = ProgressStore(fileURL: url)
        XCTAssertEqual(b.card("n5_0002").interval, 1)
        XCTAssertEqual(b.card("n5_0002").state, .review)
        XCTAssertEqual(b.totalReviewed, 1)
        XCTAssertTrue(b.isLearned("g_001"))
    }

    func testToggleLearnedAndReset() {
        let store = ProgressStore(fileURL: nil)
        store.toggleLearned("g_001")
        XCTAssertTrue(store.isLearned("g_001"))
        store.toggleLearned("g_001")
        XCTAssertFalse(store.isLearned("g_001"))
        store.review("a", cardType: "x", rating: .good)
        store.reset()
        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertEqual(store.totalReviewed, 0)
    }
}

// MARK: - Review session

@MainActor
final class ReviewModelTests: XCTestCase {
    private func entry(_ id: String) -> VocabEntry {
        VocabEntry(id: id, kanji: id, kana: id, meanings: LocalizedText(vi: id, en: ""), pos: "noun", verbGroup: nil,
                   adjType: nil, jlptLevel: "N5", chapter: 1, category: nil, minna: nil, tags: [], homophones: [],
                   relatedWords: [], examples: [], pitch: nil)
    }

    private func cards(_ ids: [String]) -> [ReviewCard] { ids.map { .vocab(id: $0, cardType: "meaning", entry: entry($0)) } }

    func testGoodAdvancesAndFinishes() {
        let store = ProgressStore(fileURL: nil), m = ReviewModel()
        m.start(with: cards(["a", "b"]))
        XCTAssertEqual(m.phase, .session)
        m.flipped = true
        m.rate(.good, store: store)
        XCTAssertEqual(m.current?.id, "b")
        XCTAssertFalse(m.flipped)
        m.rate(.easy, store: store)
        XCTAssertEqual(m.phase, .done)
        XCTAssertEqual(m.reviewed, 2)
    }

    func testAgainRequeuesFourCardsAhead() {
        let store = ProgressStore(fileURL: nil), m = ReviewModel()
        m.start(with: cards(["a", "b", "c", "d", "e", "f"]))
        m.rate(.again, store: store)
        XCTAssertEqual(m.queue.map(\.id), ["a", "b", "c", "d", "e", "a", "f"])
        XCTAssertEqual(store.card("a").lapseCount, 1)
    }

    func testRequeueIsClampedAtEndOfQueue() {
        let store = ProgressStore(fileURL: nil), m = ReviewModel()
        m.start(with: cards(["a"]))
        m.rate(.hard, store: store)
        XCTAssertEqual(m.queue.map(\.id), ["a", "a"])
        XCTAssertEqual(m.phase, .session)             // the requeued copy still has to be answered
        m.rate(.good, store: store)
        XCTAssertEqual(m.phase, .done)
    }

    func testEmptyQueueStaysInSetup() {
        let m = ReviewModel()
        m.start(with: [])
        XCTAssertEqual(m.phase, .setup)
    }

    func testBuildQueueOrdersDueThenNewThenScheduledAndCaps() {
        let store = ProgressStore(fileURL: nil)
        let now = Date()
        store.review("due", cardType: "x", rating: .again, now: now.addingTimeInterval(-5 * 86_400))
        store.review("later", cardType: "x", rating: .good, now: now)
        let byID = Dictionary(uniqueKeysWithValues: ["due", "later", "n1", "n2", "n3"].map { ($0, entry($0)) })
        let q = ReviewModel.buildQueue(ids: ["later", "n1", "due", "n2", "n3"], count: 3, store: store,
                                       resolve: { c in byID[c.vocabId].map { .vocab(id: c.vocabId, cardType: c.cardType, entry: $0) } },
                                       shuffle: { $0 })
        XCTAssertEqual(q.map(\.id), ["due", "n1", "n2"])
    }
}
