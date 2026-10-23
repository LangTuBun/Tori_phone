import Foundation
import Observation

/// One glyph from kanjivg.json: SVG stroke paths in stroke order, plus the
/// components (radicals/parts) each stroke belongs to.
struct KanjiVGEntry: Decodable, Sendable {
    struct Component: Decodable, Sendable {
        let element: String?
        let position: String?
        let isRadical: Bool?
        let strokes: [Int]
    }

    let viewBox: String
    let strokes: [String]
    let components: [Component]?

    /// Width and height of the SVG viewBox ("0 0 109 109").
    var size: CGSize {
        let parts = viewBox.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        return parts.count == 4 ? CGSize(width: parts[2], height: parts[3]) : CGSize(width: 109, height: 109)
    }
}

/// Loads the ~2 MB kanjivg.json on first use, off the main thread, and keeps
/// it for the rest of the session.
@Observable
@MainActor
final class KanjiVGStore {
    private(set) var entries: [String: KanjiVGEntry]?
    private var loading = false

    func loadIfNeeded() async {
        guard entries == nil, !loading else { return }
        loading = true
        defer { loading = false }
        let result = await Task.detached(priority: .utility) { () -> [String: KanjiVGEntry]? in
            guard let url = Bundle.main.url(forResource: "kanjivg", withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode([String: KanjiVGEntry].self, from: data)
        }.value
        entries = result
    }

    func entry(for glyph: String) -> KanjiVGEntry? { entries?[glyph] }
}
