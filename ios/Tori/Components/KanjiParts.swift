import SwiftUI

// MARK: - Pitch graph

/// The small accent diagram next to a word: one dot per mora, high or low,
/// a dashed step to the particle after the word. Port of the web PitchAccent.
struct PitchGraphView: View {
    let kana: String
    let pitch: Int?
    var large = false
    @Environment(\.palette) private var p

    var body: some View {
        if let pitch, !kana.isEmpty {
            let morae = Japanese.splitMorae(kana)
            if !morae.isEmpty {
                let (levels, afterHigh) = Japanese.pitchLevels(moraCount: morae.count, pitch: pitch)
                let step: CGFloat = large ? 16 : 12, dot: CGFloat = large ? 3.5 : 2.5
                let highY: CGFloat = large ? 5 : 4, lowY: CGFloat = large ? 19 : 14
                let height: CGFloat = large ? 24 : 18, line: CGFloat = large ? 2 : 1.5
                let width = step * CGFloat(levels.count + 1)
                Canvas { ctx, _ in
                    func pt(_ i: Int, _ high: Bool) -> CGPoint { CGPoint(x: step * CGFloat(i) + step / 2, y: high ? highY : lowY) }
                    let points = levels.enumerated().map { pt($0.offset, $0.element) }
                    var path = Path()
                    for (i, q) in points.enumerated() { i == 0 ? path.move(to: q) : path.addLine(to: q) }
                    ctx.stroke(path, with: .color(p.accent), lineWidth: line)
                    let after = pt(levels.count, afterHigh)
                    var tail = Path(); tail.move(to: points[points.count - 1]); tail.addLine(to: after)
                    ctx.stroke(tail, with: .color(p.muted), style: StrokeStyle(lineWidth: line, dash: [2, 2]))
                    for q in points { ctx.fill(Path(ellipseIn: CGRect(x: q.x - dot, y: q.y - dot, width: dot * 2, height: dot * 2)), with: .color(p.accent)) }
                    let r = dot * 0.7
                    ctx.stroke(Path(ellipseIn: CGRect(x: after.x - r, y: after.y - r, width: r * 2, height: r * 2)), with: .color(p.muted), lineWidth: line * 0.8)
                }
                .frame(width: width, height: height)
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - On/kun tag

/// KUN--KUN, ON--ON, JUKU, ATE: how each kanji of a word is read, tinted like the web.
struct OnkunTag: View {
    let text: String
    @Environment(\.palette) private var p

    private var tone: Color {
        if text.contains("Juku") || text.contains("Ate") { return Color(hex: 0x9333EA) }
        let hasOn = text.contains("On"), hasKun = text.contains("Kun")
        if hasOn && hasKun { return p.muted }
        return hasOn ? p.blue : p.green
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(0.6)
            .foregroundStyle(tone)
    }
}

// MARK: - Components

/// One component of a kanji (all its occurrences merged: 森 -> 木 x3).
struct GroupedComponent: Hashable {
    let element: String
    var count = 0
    var positions: [String] = []
    /// Union of every occurrence's stroke indices.
    var strokes: [Int] = []

    static func group(_ components: [KanjiVGEntry.Component]) -> [GroupedComponent] {
        var order: [String] = []
        var map: [String: GroupedComponent] = [:]
        for c in components {
            guard let el = c.element else { continue }
            if map[el] == nil { map[el] = GroupedComponent(element: el); order.append(el) }
            map[el]!.count += 1
            map[el]!.strokes.append(contentsOf: c.strokes)
            if let pos = c.position, !map[el]!.positions.contains(pos) { map[el]!.positions.append(pos) }
        }
        return order.compactMap { map[$0] }
    }

    /// One ink colour per distinct component, cycled (same as the web drawer).
    static let palette: [Color] = [0xBE4327, 0x3B82F6, 0x16A34A, 0xA855F7, 0xD97706, 0x0891B2, 0xDB2777].map { Color(hex: $0) }
}

/// Bothu.pdf names the positional variants "Bộ thủ", "Bộ khuyển"; the lead-in
/// word is noise on a chip, so chips and the diagram show "Thủ", "Khuyển".
func shortRadicalName(_ name: String?) -> String {
    guard var s = name, !s.isEmpty else { return "" }
    if s.lowercased().hasPrefix("bộ ") { s = String(s.dropFirst(3)) }
    return s.prefix(1).uppercased() + s.dropFirst()
}

struct GraphNode: Identifiable {
    let element: String
    let label: String
    let count: Int
    let color: Color
    var id: String { element }
}

/// One level of 'chiết tự': each component points into the kanji it builds,
/// and every node opens that component's own page.
struct ComponentGraphView: View {
    let char: String
    var charLabel: String?
    let nodes: [GraphNode]
    @Binding var hovered: String?
    let onSelect: (String) -> Void
    @Environment(\.palette) private var p

    private let W: CGFloat = 360, H: CGFloat = 200
    private let nodeR: CGFloat = 24, topY: CGFloat = 66, charY: CGFloat = 156, charR: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / W
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for (i, node) in nodes.enumerated() {
                        let x = W * (CGFloat(i) + 0.5) / CGFloat(nodes.count)
                        let vx = W / 2 - x, vy = charY - topY
                        let len = (vx * vx + vy * vy).squareRoot()
                        let ux = vx / len, uy = vy / len
                        let a = CGPoint(x: (x + ux * nodeR) * s, y: (topY + uy * nodeR) * s)
                        let b = CGPoint(x: (W / 2 - ux * (charR + 4)) * s, y: (charY - uy * (charR + 4)) * s)
                        let color = dimmed(node) ? p.hairline : p.muted
                        var line = Path(); line.move(to: a); line.addLine(to: b)
                        ctx.stroke(line, with: .color(color), lineWidth: 1.5 * s)
                        // Arrow head at b.
                        let ang = atan2(b.y - a.y, b.x - a.x), h = 7 * s
                        var head = Path()
                        head.move(to: b)
                        head.addLine(to: CGPoint(x: b.x - h * cos(ang - .pi / 7), y: b.y - h * sin(ang - .pi / 7)))
                        head.addLine(to: CGPoint(x: b.x - h * cos(ang + .pi / 7), y: b.y - h * sin(ang + .pi / 7)))
                        head.closeSubpath()
                        ctx.fill(head, with: .color(color))
                    }
                }
                ForEach(Array(nodes.enumerated()), id: \.element.id) { i, node in
                    let x = W * (CGFloat(i) + 0.5) / CGFloat(nodes.count)
                    let color = dimmed(node) ? p.hairline : node.color
                    Button { onSelect(node.element) } label: {
                        ZStack {
                            Circle().fill(Color.white).overlay(Circle().strokeBorder(color, lineWidth: 2.5 * s))
                            Text(node.element).jp(22 * s, weight: .bold).foregroundStyle(color)
                        }
                        .frame(width: nodeR * 2 * s, height: nodeR * 2 * s)
                        .overlay(alignment: .topTrailing) {
                            if node.count > 1 { Text("×\(node.count)").font(.system(size: 11 * s, weight: .black)).foregroundStyle(color).offset(x: 6 * s, y: -4 * s) }
                        }
                    }
                    .buttonStyle(.plain)
                    .position(x: x * s, y: topY * s)
                    if !node.label.isEmpty {
                        Text(node.label).font(.system(size: 11 * s, weight: .bold)).foregroundStyle(color)
                            .position(x: x * s, y: (topY - nodeR - 8) * s)
                    }
                }
                ZStack {
                    Circle().fill(p.text)
                    Text(char).jp(28 * s, weight: .bold).foregroundStyle(p.bg)
                }
                .frame(width: charR * 2 * s, height: charR * 2 * s)
                .position(x: W / 2 * s, y: charY * s)
                if let charLabel {
                    Text(charLabel).font(.system(size: 11 * s, weight: .bold)).foregroundStyle(p.text)
                        .position(x: W / 2 * s, y: (H - 4) * s)
                }
            }
        }
        .aspectRatio(W / H, contentMode: .fit)
    }

    private func dimmed(_ n: GraphNode) -> Bool { hovered != nil && hovered != n.element }
}
