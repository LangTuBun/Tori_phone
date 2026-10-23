import XCTest
@testable import Tori

final class KanjiVGTests: XCTestCase {
    func testParsesRelativeCurves() throws {
        let s = try XCTUnwrap(SVGPathParser.parse("M15.5,51.75c1.82,0.5,4.38,0.88,6.96,0.5c16.91-2.45,50.92-8.12,64.44-8.74"))
        XCTAssertEqual(s.start.x, 15.5, accuracy: 0.001)
        let end = try XCTUnwrap(s.path.currentPoint)
        XCTAssertEqual(end.x, 15.5 + 6.96 + 64.44, accuracy: 0.001)
        XCTAssertEqual(end.y, 51.75 + 0.5 - 8.74, accuracy: 0.001)
    }

    func testSmoothCurveAndImplicitLineto() throws {
        XCTAssertNotNil(SVGPathParser.parse("M10,10 20,20 30,10"))
        XCTAssertNotNil(SVGPathParser.parse("M10,10C20,0,30,0,40,10s10,10,20,0"))
        XCTAssertNil(SVGPathParser.parse("not a path"))
    }

    @MainActor
    func testEveryBundledStrokeParses() async throws {
        let store = KanjiVGStore()
        await store.loadIfNeeded()
        let entries = try XCTUnwrap(store.entries)
        XCTAssertGreaterThan(entries.count, 1500)
        for (glyph, entry) in entries {
            XCTAssertFalse(entry.strokes.isEmpty, glyph)
            for d in entry.strokes {
                XCTAssertNotNil(SVGPathParser.parse(d), "\(glyph): \(d)")
            }
        }
        let seven = try XCTUnwrap(entries["七"])
        XCTAssertEqual(seven.strokes.count, 2)
    }
}
