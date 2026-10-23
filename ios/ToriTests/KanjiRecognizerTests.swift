import XCTest
import SwiftUI
@testable import Tori

@MainActor
final class KanjiRecognizerTests: XCTestCase {
    typealias R = KanjiRecognizer

    private func loaded() async throws -> (entries: [String: KanjiVGEntry], lib: KanjiLibrary) {
        let vg = KanjiVGStore()
        await vg.loadIfNeeded()
        let data = DataStore()
        await data.load()
        let lib = KanjiLibrary()
        await lib.load(chapters: data.kanjiChapters(.all))
        return (try XCTUnwrap(vg.entries), lib)
    }

    func testResampleKeepsEndpointsAndCount() {
        let s = R.resample([.init(0, 0), .init(10, 0), .init(10, 10)], n: 16)
        XCTAssertEqual(s.count, 16)
        XCTAssertEqual(s.first, .init(0, 0))
        XCTAssertEqual(s.last!.x, 10, accuracy: 1e-9)
        XCTAssertEqual(s.last!.y, 10, accuracy: 1e-9)
        XCTAssertEqual(R.resample([.init(3, 4)], n: 16).count, 16)
    }

    func testFlattenFollowsThePath() throws {
        let stroke = try XCTUnwrap(SVGPathParser.parse("M0,0c10,0,20,0,30,0"))
        let pts = R.flatten(stroke.path)
        XCTAssertEqual(pts.count, 13)
        XCTAssertEqual(pts.last!.x, 30, accuracy: 1e-9)
    }

    /// A drawing: the glyph's own strokes, scaled and shifted like a finger
    /// drawing in a pad, with deterministic wobble on every point.
    private func drawing(of entry: KanjiVGEntry, noise: Double, seed: UInt64) -> [R.Stroke] {
        var state = seed
        func rand() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(1 << 31) - 0.5
        }
        return entry.strokes.compactMap { d in
            SVGPathParser.parse(d).map { s in
                R.flatten(s.path).enumerated().filter { $0.offset % 3 == 0 }.map { _, p in
                    R.Pt(p.x * 2.9 + 40 + rand() * noise * 2.9, p.y * 2.9 + 25 + rand() * noise * 2.9)
                }
            }
        }
    }

    func testRecognizesKanjiFromTheirOwnStrokes() async throws {
        let (entries, lib) = try await loaded()
        // Debug builds are ~50x slower than Release, so test on the first 300
        // kanji (textbook anchors first) to keep the suite quick.
        let chars = Set(lib.order.filter { entries[$0] != nil }.prefix(300))
        XCTAssertEqual(chars.count, 300)
        let t0 = Date()
        let candidates = R.makeCandidates(entries, chars: chars)
        let buildTime = Date().timeIntervalSince(t0)
        XCTAssertEqual(candidates.count, chars.count)

        // Textbook anchors are the kanji learners actually look up.
        let sample = lib.order.filter { chars.contains($0) }.prefix(60)
        var top1 = 0, top5 = 0
        for (i, ch) in sample.enumerated() {
            let drawn = drawing(of: entries[ch]!, noise: 2.5, seed: UInt64(i + 1))
            let guesses = R.recognize(drawn, candidates: candidates)
            if guesses.first == ch { top1 += 1 }
            if guesses.prefix(5).contains(ch) { top5 += 1 }
        }
        let n = Double(sample.count)
        let recognizeTime = Date().timeIntervalSince(t0) - buildTime
        print("recognizer timing: build \(buildTime)s for \(candidates.count) glyphs, \(recognizeTime / n)s per recognition")
        print("recognizer top1=\(Double(top1) / n) top5=\(Double(top5) / n) over \(sample.count)")
        XCTAssertGreaterThan(Double(top1) / n, 0.85, "top-1 accuracy on wobbly drawings")
        XCTAssertGreaterThan(Double(top5) / n, 0.95, "top-5 accuracy on wobbly drawings")
    }

    func testEmptyDrawingGivesNothing() {
        XCTAssertTrue(R.recognize([], candidates: []).isEmpty)
        XCTAssertTrue(R.recognize([[]], candidates: []).isEmpty)
    }
}
