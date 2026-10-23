import SwiftUI

/// A word or sentence with furigana over every kanji run, aligned from the
/// separate reading (`Furigana.alignCached`). Falls back to plain text when the
/// reading cannot be lined up. With `tappable`, each kanji opens its detail sheet.
struct FuriganaText: View {
    let kanji: String
    var kana: String?
    var size: CGFloat = 18
    var weight: Font.Weight = .semibold
    /// Let long text wrap between units (sentences). Words stay on one line.
    var wrap = true
    var tappable = false
    /// Handle kanji taps yourself (the kanji sheet pages in place) instead of opening a sheet.
    var onKanji: ((String) -> Void)?

    @Environment(\.palette) private var p
    @State private var picked: String?

    private var segments: [Furigana.Segment]? {
        guard let kana, !kana.isEmpty, kanji != kana, Furigana.hasKanji(kanji) else { return nil }
        return Furigana.alignCached(kanji: kanji, kana: kana)
    }

    var body: some View {
        let text = kanji.isEmpty ? (kana ?? "") : kanji
        Group {
            if let segments, segments.contains(where: { $0.reading != nil }) {
                ruby(segments)
            } else if tappable, Furigana.hasKanji(text) {
                layout { ForEach(Array(text.enumerated()), id: \.offset) { _, ch in glyph(String(ch)) } }
            } else {
                Text(text).jp(size, weight: weight).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .modifier(KanjiPickSheet(enabled: tappable && onKanji == nil, picked: $picked))
    }

    private func ruby(_ segments: [Furigana.Segment]) -> some View {
        // Literal text is split per character so a sentence can wrap anywhere;
        // a run with a reading stays one unit so its ruby stays centred.
        let units: [Furigana.Segment] = segments.flatMap { seg -> [Furigana.Segment] in
            seg.reading == nil && wrap ? seg.text.map { Furigana.Segment(text: String($0), reading: nil) } : [seg]
        }
        return layout {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                VStack(spacing: 0) {
                    Text(unit.reading ?? " ")
                        .font(.system(size: max(8, size * 0.45), weight: .medium, design: .serif))
                        .foregroundStyle(p.muted)
                        .lineLimit(1).fixedSize()
                    HStack(spacing: 0) {
                        ForEach(Array(unit.text.enumerated()), id: \.offset) { _, ch in glyph(String(ch)) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if wrap { FlowLayout(spacing: 0, lineSpacing: 2) { content() } }
        else { HStack(alignment: .bottom, spacing: 0) { content() } }
    }

    @ViewBuilder
    private func glyph(_ ch: String) -> some View {
        let t = Text(ch).jp(size, weight: weight)
        if tappable, let c = ch.first, Furigana.isKanji(c) {
            t.contentShape(Rectangle()).onTapGesture { if let onKanji { onKanji(ch) } else { picked = ch } }
        } else {
            t
        }
    }
}

/// Presents the kanji sheet for a tapped glyph; skipped for rows that are not tappable.
private struct KanjiPickSheet: ViewModifier {
    let enabled: Bool
    @Binding var picked: String?
    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled { content.kanjiSheet($picked) } else { content }
    }
}
