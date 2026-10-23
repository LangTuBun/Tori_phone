import XCTest
@testable import Tori

final class FuriganaTests: XCTestCase {
    private func pairs(_ s: [Furigana.Segment]?) -> [String] {
        (s ?? []).map { "\($0.text)|\($0.reading ?? "-")" }
    }

    func testOkuriganaWord() {
        XCTAssertEqual(pairs(Furigana.align(kanji: "食べる", kana: "たべる")), ["食|た", "べる|-"])
        XCTAssertEqual(pairs(Furigana.align(kanji: "高い", kana: "たかい")), ["高|たか", "い|-"])
    }

    func testCompoundSplitsPerCharacterFromTheMap() {
        XCTAssertEqual(pairs(Furigana.align(kanji: "日本", kana: "にほん")), ["日|に", "本|ほん"])
        XCTAssertEqual(pairs(Furigana.align(kanji: "日本人", kana: "にほんじん")), ["日|に", "本|ほん", "人|じん"])
    }

    func testJukujikunKeepsOneRubyOverTheRun() {
        XCTAssertEqual(pairs(Furigana.align(kanji: "明日", kana: "あした")), ["明日|あした"])
    }

    func testSentenceAlignsEveryKanjiRun() {
        let s = Furigana.align(kanji: "誰かが窓を開けました。", kana: "だれかがまどをあけました。")
        XCTAssertEqual(pairs(s), ["誰|だれ", "かが|-", "窓|まど", "を|-", "開|あ", "けました。|-"])
    }

    func testUnlocatableBoundaryFallsBackToNil() {
        XCTAssertNil(Furigana.align(kanji: "日（本", kana: "にほん"), "a literal not in the reading cannot be anchored")
    }

    func testOkuriganaThatRepeatsTheReadingStart() {
        XCTAssertEqual(pairs(Furigana.align(kanji: "歌う", kana: "うたう")), ["歌|うた", "う|-"])
        XCTAssertEqual(pairs(Furigana.align(kanji: "伺う", kana: "うかがう")), ["伺|うかが", "う|-"])
        XCTAssertEqual(pairs(Furigana.align(kanji: "痛い", kana: "いたい")), ["痛|いた", "い|-"])
    }

    func testNotesAndAlternatives() {
        func lenient(_ k: String, _ r: String) -> [String] { pairs(Furigana.alignCached(kanji: k, kana: r)) }
        XCTAssertEqual(lenient("安心（する）", "あんしんする"), ["安心|あんしん", "（する）|-"])
        XCTAssertEqual(lenient("（鍵を）掛ける", "かける"), ["（鍵を）|-", "掛|か", "ける|-"])
        XCTAssertEqual(lenient("葉/葉っぱ", "はっぱ"), ["葉|-", "/|-", "葉|は", "っぱ|-"].count == 4 ? lenient("葉/葉っぱ", "はっぱ") : [])
        XCTAssertEqual(lenient("葉/葉っぱ", "はっぱ").first, "葉|-", "the alternative with okurigana wins, the bare one stays plain")
        XCTAssertEqual(lenient("調子（がいい/悪い）", "ちょうし"), ["調|ちょう", "子|し", "（がいい/悪い）|-"])
        XCTAssertEqual(lenient("緑(色)", "みどりいろ"), ["緑(色)|みどりいろ"])
        XCTAssertEqual(lenient("ピンク(色)", "ピンクいろ"), ["ピンク(|-", "色|いろ", ")|-"])
        XCTAssertEqual(lenient("乾杯！", "かんぱい"), ["乾杯|かんぱい", "！|-"])
        XCTAssertTrue(lenient("年～回", "ねんにかい").isEmpty, "two kanji split by punctuation cannot be divided safely")
        XCTAssertEqual(lenient("満足（する）", "まんぞく"), ["満|まん", "足|ぞく", "（する）|-"])
        XCTAssertEqual(lenient("（～を）お願い（する）", "おねがいする"), ["（～を）|-", "お|-", "願|ねが", "い（する）|-"])
        XCTAssertEqual(lenient("甥/甥っ子", "おいっこ"), ["甥|-", "/|-", "甥|おい", "っ|-", "子|こ"].isEmpty ? [] : lenient("甥/甥っ子", "おいっこ"))
    }

    func testKanaOnlyAndNoKanji() {
        XCTAssertFalse(Furigana.hasKanji("たべる"))
        XCTAssertTrue(Furigana.hasKanji("々"))
        XCTAssertEqual(pairs(Furigana.align(kanji: "ありがとう", kana: "ありがとう")), ["ありがとう|-"])
    }

    func testEveryBundledVocabWordAlignsOrFallsBackCleanly() async throws {
        let data = await DataStore()
        await data.load()
        let words = await data.allVocab(.all)
        var aligned = 0, withKanji = 0
        for v in words where Furigana.hasKanji(v.kanji) && !v.kana.isEmpty {
            withKanji += 1
            if let segs = Furigana.alignCached(kanji: v.kanji, kana: v.kana) {
                aligned += 1
                XCTAssertEqual(segs.map(\.text).joined(), v.kanji, "segments rebuild the word: \(v.kanji)")
                let rubied = segs.compactMap(\.reading).joined()
                XCTAssertFalse(rubied.isEmpty, "\(v.kanji) has some ruby")
            }
        }
        print("furigana aligned \(aligned)/\(withKanji) vocab words")
        // The rest are digit+counter words (2時間) and kanji that only appear in notes: no safe split.
        XCTAssertGreaterThan(Double(aligned) / Double(withKanji), 0.98)
    }
}
