import SwiftUI

/// Draws a kanji stroke by stroke, like the web app's AnimatedKanjiSvg: a dim
/// guide underneath, ink drawn in order on top, optional stroke numbers.
///
/// The clock starts on the first frame actually drawn (not when the view is
/// created), so a sheet that is still sliding in or a busy main thread never
/// eats the first strokes. Each replay carries a generation number, so a
/// stale "finished" can never freeze a newer animation.
struct StrokeOrderView: View {
    let entry: KanjiVGEntry
    var strokeDuration: Double = 0.5
    var showNumbers = true
    var showsReplayButton = true
    /// Ink colour per stroke index (a missing or nil entry uses the text colour).
    var strokeColors: [Color?] = []
    /// Bump to replay from outside (the kanji sheet's own button).
    var replayToken = 0

    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strokes: [SVGPathParser.Stroke] = []
    @State private var generation = 0
    @State private var finished = false
    /// Not state: read and written while drawing, and must not trigger a redraw.
    @State private var clock = Clock()

    /// Start time of the current run (set by the first frame drawn) and the
    /// stroke paths already scaled to the current size.
    private final class Clock {
        var start: Date?
        var size: CGSize = .zero
        var scaled: [Path] = []
        var scale: CGFloat = 1
        var offset: CGPoint = .zero
    }

    private var total: Double { Double(strokes.count) * strokeDuration }

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(paused: finished || reduceMotion)) { context in
                let elapsed = elapsedTime(at: context.date)
                Canvas { ctx, size in draw(&ctx, size: size, elapsed: elapsed) }
            }
            .aspectRatio(entry.size.width / entry.size.height, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.solidCard.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
            .accessibilityElement()
            .accessibilityLabel("Stroke order, \(entry.strokes.count) strokes")

            if showsReplayButton {
                Button { replay() } label: {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.toriGlass)
                .accessibilityIdentifier("strokes.replay")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .onChange(of: replayToken) { replay() }
        .task(id: entry.strokes) {
            strokes = entry.strokes.compactMap(SVGPathParser.parse)
            clock.size = .zero
            replay()
        }
    }

    private func replay() {
        generation += 1
        finished = false
        clock.start = nil
    }

    /// Seconds into the run. The first frame fixes the start; once the last
    /// stroke is done (plus a beat) the timeline is paused, but only if no
    /// newer replay began in the meantime.
    private func elapsedTime(at date: Date) -> Double {
        if reduceMotion { return total }
        if clock.start == nil { clock.start = date }
        let elapsed = date.timeIntervalSince(clock.start ?? date)
        if !strokes.isEmpty, elapsed > total + 0.3, !finished {
            let g = generation
            DispatchQueue.main.async { if g == generation { finished = true } }
        }
        return elapsed
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, elapsed: Double) {
        guard !strokes.isEmpty else { return }
        if clock.size != size || clock.scaled.count != strokes.count {
            let vb = entry.size
            let scale = min(size.width / vb.width, size.height / vb.height)
            let dx = (size.width - vb.width * scale) / 2, dy = (size.height - vb.height * scale) / 2
            let t = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
            clock.scaled = strokes.map { $0.path.applying(t) }
            clock.scale = scale
            clock.offset = CGPoint(x: dx, y: dy)
            clock.size = size
        }
        let scale = clock.scale
        let guide = StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round)
        let ink = StrokeStyle(lineWidth: 3 * scale, lineCap: .round, lineJoin: .round)

        for path in clock.scaled { ctx.stroke(path, with: .color(p.muted.opacity(0.28)), style: guide) }
        for (i, s) in strokes.enumerated() {
            let progress = min(max((elapsed - Double(i) * strokeDuration) / strokeDuration, 0), 1)
            guard progress > 0 else { break }          // strokes start in order, so none after this one has begun
            let color = strokeColors.indices.contains(i) ? (strokeColors[i] ?? p.text) : p.text
            ctx.stroke(clock.scaled[i].trimmedPath(from: 0, to: easeInOut(progress)), with: .color(color), style: ink)
            if showNumbers {
                let at = CGPoint(x: (s.start.x - 4) * scale + clock.offset.x, y: (s.start.y - 3) * scale + clock.offset.y)
                ctx.draw(Text("\(i + 1)").font(.system(size: 8 * scale, weight: .bold)).foregroundColor(p.red), at: at)
            }
        }
    }

    private func easeInOut(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
