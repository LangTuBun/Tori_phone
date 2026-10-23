import SwiftUI

// Painted backgrounds for the gallery. Liquid Glass shows only what is behind it,
// so every scene has real structure (ridges, skylines, a sun, blossoms) for the
// blur and the refracted edges to work on. Everything is vector and deterministic.

/// Small seeded generator so scenes look the same on every launch.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct SceneBackground: View {
    let theme: ThemeID

    var body: some View {
        switch theme {
        case .dusk: DuskBackground()
        case .aurora: AuroraBackground()
        case .neon: NeonBackground()
        case .sakura: SakuraBackground()
        case .ink: InkBackground()
        default: Color.clear
        }
    }
}

/// A theme as a small picture: the scene itself, or the colour field for gradients.
struct ThemePreview: View {
    let theme: ThemeID

    var body: some View {
        if theme.isScene {
            SceneBackground(theme: theme)
        } else {
            let pal = Palette.make(theme)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    pal.bg
                    Circle().fill(pal.blobs[0]).frame(width: w * 0.95).blur(radius: w * 0.2).position(x: w * 0.1, y: h * 0.08)
                    Circle().fill(pal.blobs[1]).frame(width: w * 0.85).blur(radius: w * 0.2).position(x: w * 0.95, y: h * 0.32)
                    Circle().fill(pal.blobs[2]).frame(width: w * 0.95).blur(radius: w * 0.2).position(x: w * 0.05, y: h * 0.72)
                    Circle().fill(pal.blobs[3]).frame(width: w * 0.8).blur(radius: w * 0.2).position(x: w * 0.9, y: h * 0.96)
                }
            }
        }
    }
}

// MARK: - Shared drawing

/// A jagged or rolling ridge line filled down to the bottom edge.
private func ridgePath(w: CGFloat, h: CGFloat, baseY: CGFloat, amp: CGFloat, seed: UInt64, jagged: Bool) -> Path {
    var rng = SeededRandom(seed)
    var p = Path()
    p.move(to: CGPoint(x: 0, y: h))
    let steps = jagged ? 22 : 30
    var last = baseY
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let wave = 0.55 * sin(Double(t) * 6.1 + Double(seed)) + 0.3 * sin(Double(t) * 13.7 + Double(seed) * 2.1)
        var y = baseY - amp * CGFloat(wave)
        if jagged { y = baseY - amp * CGFloat.random(in: -0.4...1.0, using: &rng) * (0.6 + 0.4 * CGFloat(sin(Double(t) * 5))) }
        last = y
        p.addLine(to: CGPoint(x: t * w, y: y))
    }
    _ = last
    p.addLine(to: CGPoint(x: w, y: h))
    p.closeSubpath()
    return p
}

private func hex(_ v: UInt32, _ o: Double = 1) -> Color { Color(hex: v, opacity: o) }

// MARK: - Aurora

struct AuroraBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: hex(0x040A1C), location: 0),
                    .init(color: hex(0x0A1F3A), location: 0.45),
                    .init(color: hex(0x123F4C), location: 0.78),
                    .init(color: hex(0x0B2530), location: 1),
                ], startPoint: .top, endPoint: .bottom)

                Canvas { ctx, size in
                    var rng = SeededRandom(7)
                    for _ in 0..<150 {
                        let x = Double.random(in: 0...size.width, using: &rng)
                        let y = Double.random(in: 0...(size.height * 0.62), using: &rng)
                        let r = Double.random(in: 0.5...1.7, using: &rng)
                        let a = Double.random(in: 0.25...0.95, using: &rng)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a)))
                    }
                }

                ribbon(w: w, h: h, y: 0.26, thickness: 0.17, phase: 0.3, colors: [0x4DFFB0, 0x2FD6C8], op: 0.75)
                ribbon(w: w, h: h, y: 0.34, thickness: 0.14, phase: 1.7, colors: [0x4DD2FF, 0x6B7BFF], op: 0.55)
                ribbon(w: w, h: h, y: 0.20, thickness: 0.10, phase: 3.1, colors: [0xB06BFF, 0xFF7BD0], op: 0.45)

                ridgePath(w: w, h: h, baseY: h * 0.70, amp: h * 0.07, seed: 3, jagged: true).fill(hex(0x0C2233))
                ridgePath(w: w, h: h, baseY: h * 0.78, amp: h * 0.06, seed: 9, jagged: true).fill(hex(0x071622))

                // Frozen lake with the glow lying on it.
                Rectangle().fill(LinearGradient(colors: [hex(0x14505A, 0.9), hex(0x06141E)], startPoint: .top, endPoint: .bottom))
                    .frame(height: h * 0.2).position(x: w / 2, y: h * 0.9)
                Ellipse().fill(hex(0x4DFFB0, 0.28)).frame(width: w * 0.8, height: h * 0.05).blur(radius: 18).position(x: w * 0.4, y: h * 0.84)

                LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.05), .black.opacity(0.38)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private func ribbon(w: CGFloat, h: CGFloat, y: CGFloat, thickness: CGFloat, phase: Double, colors: [UInt32], op: Double) -> some View {
        Path { p in
            let steps = 24
            var top: [CGPoint] = [], bottom: [CGPoint] = []
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let cy = h * y + h * 0.05 * CGFloat(sin(t * 5.2 + phase) + 0.5 * sin(t * 11 + phase * 1.7))
                let th = h * thickness * CGFloat(0.65 + 0.35 * sin(t * 4 + phase * 2))
                top.append(CGPoint(x: CGFloat(t) * w, y: cy))
                bottom.append(CGPoint(x: CGFloat(t) * w, y: cy + th))
            }
            p.move(to: top[0])
            top.dropFirst().forEach { p.addLine(to: $0) }
            bottom.reversed().forEach { p.addLine(to: $0) }
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [.clear, hex(colors[0], op), hex(colors[1], op * 0.8), .clear], startPoint: .top, endPoint: .bottom))
        .blur(radius: 18)
        .blendMode(.screen)
    }
}

// MARK: - Neon (Tokyo at night)

struct NeonBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: hex(0x0B0626), location: 0),
                    .init(color: hex(0x2A0F55), location: 0.34),
                    .init(color: hex(0x9C2E8A), location: 0.54),
                    .init(color: hex(0xFF5C7A), location: 0.65),
                    .init(color: hex(0xFFB070), location: 0.74),
                ], startPoint: .top, endPoint: .bottom)

                // Retro sun with slits.
                Circle()
                    .fill(LinearGradient(colors: [hex(0xFFE066), hex(0xFF8A5C), hex(0xFF3C8E)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.66, height: w * 0.66)
                    .mask {
                        Canvas { ctx, size in
                            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                            ctx.blendMode = .clear
                            for i in 0..<8 {
                                let y = size.height * (0.52 + 0.06 * Double(i))
                                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.5 + Double(i) * 1.1)), with: .color(.black))
                            }
                        }
                    }
                    .position(x: w * 0.5, y: h * 0.5)

                skyline(w: w, h: h, baseY: h * 0.76, minH: 0.07, maxH: 0.2, seed: 21, color: hex(0x1B0F40), windows: 0.12)
                skyline(w: w, h: h, baseY: h * 0.78, minH: 0.09, maxH: 0.3, seed: 5, color: hex(0x0A0620), windows: 0.4)

                // Neon signs.
                ForEach(0..<5, id: \.self) { i in
                    let colors = [0xFF4FD8, 0x4FF3FF, 0xFFE066, 0xFF5C7A, 0x7CFFB0]
                    RoundedRectangle(cornerRadius: 2).fill(hex(UInt32(colors[i])))
                        .frame(width: 4, height: h * 0.04 + CGFloat(i % 3) * h * 0.012)
                        .shadow(color: hex(UInt32(colors[i])), radius: 8)
                        .position(x: w * (0.12 + 0.19 * CGFloat(i)), y: h * (0.66 + 0.02 * CGFloat(i % 2)))
                }

                // Wet street with the lights streaking down it.
                Rectangle().fill(LinearGradient(colors: [hex(0x24104A), hex(0x070416)], startPoint: .top, endPoint: .bottom))
                    .frame(height: h * 0.24).position(x: w / 2, y: h * 0.88)
                ForEach(0..<7, id: \.self) { i in
                    let colors = [0xFF4FD8, 0x4FF3FF, 0xFFE066, 0xFF5C7A, 0x7CFFB0, 0xFF4FD8, 0x4FF3FF]
                    Capsule().fill(hex(UInt32(colors[i]), 0.55))
                        .frame(width: 5, height: h * (0.08 + 0.02 * CGFloat(i % 3)))
                        .blur(radius: 5)
                        .position(x: w * (0.08 + 0.14 * CGFloat(i)), y: h * 0.86)
                }

                LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.12), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private func skyline(w: CGFloat, h: CGFloat, baseY: CGFloat, minH: CGFloat, maxH: CGFloat, seed: UInt64, color: Color, windows: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed)
            var x: CGFloat = -10
            while x < size.width {
                let bw = CGFloat.random(in: 22...54, using: &rng)
                let bh = size.height * CGFloat.random(in: minH...maxH, using: &rng)
                ctx.fill(Path(CGRect(x: x, y: baseY - bh, width: bw, height: bh + (size.height - baseY))), with: .color(color))
                var wy = baseY - bh + 8
                while wy < baseY - 6 {
                    var wx = x + 5
                    while wx < x + bw - 6 {
                        if Double.random(in: 0...1, using: &rng) < windows {
                            let c: [UInt32] = [0x6CF6FF, 0xFFE066, 0xFF8AD8]
                            ctx.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 4)), with: .color(hex(c[Int.random(in: 0..<3, using: &rng)], 0.85)))
                        }
                        wx += 8
                    }
                    wy += 11
                }
                x += bw + CGFloat.random(in: 0...4, using: &rng)
            }
        }
    }
}

// MARK: - Sakura (spring dawn, Mt Fuji)

struct SakuraBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: hex(0xF5C2D6), location: 0),
                    .init(color: hex(0xFBD6DF), location: 0.32),
                    .init(color: hex(0xFFE8DA), location: 0.62),
                    .init(color: hex(0xFFF6EC), location: 1),
                ], startPoint: .top, endPoint: .bottom)

                Circle().fill(hex(0xFFF4EA, 0.8)).frame(width: w * 0.5).blur(radius: 4).position(x: w * 0.28, y: h * 0.22)
                Circle().fill(hex(0xFFE3D0, 0.4)).frame(width: w * 0.9).blur(radius: 30).position(x: w * 0.28, y: h * 0.22)

                // Mt Fuji.
                Path { p in
                    p.move(to: CGPoint(x: -w * 0.15, y: h * 0.7))
                    p.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.33), control: CGPoint(x: w * 0.3, y: h * 0.6))
                    p.addQuadCurve(to: CGPoint(x: w * 1.15, y: h * 0.7), control: CGPoint(x: w * 0.74, y: h * 0.6))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [hex(0x8B9CC9), hex(0xD4BFD8)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.4, y: h * 0.4))
                    p.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.33), control: CGPoint(x: w * 0.46, y: h * 0.36))
                    p.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.4), control: CGPoint(x: w * 0.58, y: h * 0.36))
                    p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.41)); p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.39))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.415)); p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.39))
                    p.addLine(to: CGPoint(x: w * 0.43, y: h * 0.41)); p.closeSubpath()
                }
                .fill(.white.opacity(0.92))

                Ellipse().fill(.white.opacity(0.55)).frame(width: w * 1.3, height: h * 0.07).blur(radius: 16).position(x: w * 0.5, y: h * 0.62)
                ridgePath(w: w, h: h, baseY: h * 0.78, amp: h * 0.03, seed: 12, jagged: false).fill(hex(0xF1C0CC, 0.75))
                ridgePath(w: w, h: h, baseY: h * 0.88, amp: h * 0.025, seed: 4, jagged: false).fill(hex(0xE8A9BB, 0.7))

                blossoms
            }
        }
    }

    private var blossoms: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Branch: a bezier from the top right corner across the sky.
            let p0 = CGPoint(x: w * 1.08, y: h * 0.0), p1 = CGPoint(x: w * 0.88, y: h * 0.06)
            let p2 = CGPoint(x: w * 0.66, y: h * 0.0), p3 = CGPoint(x: w * 0.42, y: h * 0.045)
            var branch = Path(); branch.move(to: p0); branch.addCurve(to: p3, control1: p1, control2: p2)
            ctx.stroke(branch, with: .color(hex(0x6B4A44)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            func point(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                return CGPoint(x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
                               y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y)
            }
            var rng = SeededRandom(33)
            for _ in 0..<56 {
                let t = CGFloat.random(in: 0...1, using: &rng)
                let c = point(t)
                let at = CGPoint(x: c.x + CGFloat.random(in: -34...34, using: &rng), y: c.y + CGFloat.random(in: -22...30, using: &rng))
                flower(ctx, at: at, r: CGFloat.random(in: 6...13, using: &rng), rot: Double.random(in: 0...6.28, using: &rng),
                       tone: Double.random(in: 0...1, using: &rng))
            }
            // Petals in the air.
            for _ in 0..<42 {
                let at = CGPoint(x: CGFloat.random(in: 0...w, using: &rng), y: CGFloat.random(in: h * 0.1...h * 0.95, using: &rng))
                var c = ctx
                c.translateBy(x: at.x, y: at.y)
                c.rotate(by: .radians(Double.random(in: 0...6.28, using: &rng)))
                let r = CGFloat.random(in: 3...6.5, using: &rng)
                c.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.6, width: r * 2, height: r * 1.2)),
                       with: .color(hex(0xFFC2D6, Double.random(in: 0.55...0.95, using: &rng))))
            }
        }
    }

    private func flower(_ ctx: GraphicsContext, at: CGPoint, r: CGFloat, rot: Double, tone: Double) {
        var c = ctx
        c.translateBy(x: at.x, y: at.y)
        c.rotate(by: .radians(rot))
        let petal = tone < 0.5 ? hex(0xFFB7CE) : hex(0xFFD3E1)
        for i in 0..<5 {
            var pc = c
            pc.rotate(by: .radians(Double(i) * 2 * .pi / 5))
            pc.fill(Path(ellipseIn: CGRect(x: -r * 0.32, y: -r * 1.0, width: r * 0.64, height: r * 0.95)), with: .color(petal))
        }
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.16, y: -r * 0.16, width: r * 0.32, height: r * 0.32)), with: .color(hex(0xE0577A)))
    }
}

// MARK: - Ink (sumi-e)

struct InkBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [hex(0xF6F1E6), hex(0xE9E1D0)], startPoint: .top, endPoint: .bottom)

                Canvas { ctx, size in          // paper grain
                    var rng = SeededRandom(99)
                    for _ in 0..<260 {
                        let x = Double.random(in: 0...size.width, using: &rng), y = Double.random(in: 0...size.height, using: &rng)
                        let r = Double.random(in: 0.5...1.6, using: &rng)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.black.opacity(Double.random(in: 0.02...0.07, using: &rng))))
                    }
                }

                Circle().fill(hex(0xC7402D, 0.92)).frame(width: w * 0.15).blur(radius: 1.2).position(x: w * 0.86, y: h * 0.085)

                ridgePath(w: w, h: h, baseY: h * 0.50, amp: h * 0.07, seed: 31, jagged: true).fill(hex(0x2A2A2A, 0.10)).blur(radius: 5)
                Ellipse().fill(.white.opacity(0.7)).frame(width: w * 1.2, height: h * 0.06).blur(radius: 16).position(x: w * 0.5, y: h * 0.56)
                ridgePath(w: w, h: h, baseY: h * 0.60, amp: h * 0.08, seed: 17, jagged: true).fill(hex(0x2A2A2A, 0.20)).blur(radius: 2.5)
                Ellipse().fill(.white.opacity(0.65)).frame(width: w * 1.2, height: h * 0.06).blur(radius: 16).position(x: w * 0.4, y: h * 0.67)
                ridgePath(w: w, h: h, baseY: h * 0.72, amp: h * 0.09, seed: 8, jagged: true).fill(hex(0x2A2A2A, 0.34))
                ridgePath(w: w, h: h, baseY: h * 0.84, amp: h * 0.07, seed: 25, jagged: false).fill(hex(0x232323, 0.55))

                // A few bamboo strokes in the foreground.
                Canvas { ctx, size in
                    var rng = SeededRandom(5)
                    for i in 0..<3 {
                        let x = size.width * (0.08 + 0.07 * Double(i))
                        var y = size.height
                        while y > size.height * (0.55 + 0.05 * Double(i)) {
                            let seg = Double.random(in: 38...60, using: &rng)
                            ctx.fill(Path(roundedRect: CGRect(x: x, y: y - seg, width: 5, height: seg - 3), cornerRadius: 2), with: .color(hex(0x1E1C1A, 0.78)))
                            y -= seg
                        }
                    }
                }
            }
        }
    }
}
