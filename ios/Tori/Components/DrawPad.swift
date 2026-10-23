import SwiftUI
import simd

/// Finger-drawing surface for the kanji lookup. Points are reported in a fixed
/// 320x320 space (like the web pad) however large the view is, so the
/// recognizer sees the same coordinates on every device.
struct DrawPad: View {
    @Binding var strokes: [KanjiRecognizer.Stroke]
    @Environment(\.palette) private var p
    @State private var current: KanjiRecognizer.Stroke = []

    static let side: Double = 320

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / Self.side
            Canvas { ctx, size in
                // Dashed centre cross, like a practice sheet.
                var cross = Path()
                cross.move(to: CGPoint(x: size.width / 2, y: 0)); cross.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                cross.move(to: CGPoint(x: 0, y: size.height / 2)); cross.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                ctx.stroke(cross, with: .color(p.muted.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                let ink = StrokeStyle(lineWidth: 6 * scale, lineCap: .round, lineJoin: .round)
                for s in strokes + [current] where !s.isEmpty { ctx.stroke(path(s, scale: scale), with: .color(p.text), style: ink) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        let pt = KanjiRecognizer.Pt(v.location.x / scale, v.location.y / scale)
                        if current.isEmpty || simd_distance(current[current.count - 1], pt) >= 1 { current.append(pt) }
                    }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current) }
                        current = []
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(p.solidCard.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityIdentifier("drawpad")
        .accessibilityLabel("Drawing pad")
    }

    /// Segments joined with quadratic curves through their midpoints, so a
    /// wobbly hand reads as a smooth line.
    private func path(_ s: KanjiRecognizer.Stroke, scale: Double) -> Path {
        var path = Path()
        func cg(_ p: KanjiRecognizer.Pt) -> CGPoint { CGPoint(x: p.x * scale, y: p.y * scale) }
        path.move(to: cg(s[0]))
        if s.count == 1 { path.addLine(to: CGPoint(x: s[0].x * scale + 0.1, y: s[0].y * scale)); return path }
        for i in 1..<(s.count - 1) {
            let mid = KanjiRecognizer.Pt((s[i].x + s[i + 1].x) / 2, (s[i].y + s[i + 1].y) / 2)
            path.addQuadCurve(to: cg(mid), control: cg(s[i]))
        }
        path.addLine(to: cg(s[s.count - 1]))
        return path
    }
}
