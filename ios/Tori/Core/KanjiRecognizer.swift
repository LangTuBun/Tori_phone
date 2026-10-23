import SwiftUI
import simd

/// Handwriting -> kanji lookup, fully offline: the drawn strokes are compared
/// with the KanjiVG stroke paths the app already ships. Port of
/// src/lib/kanji-recognizer.ts, same pipeline and constants.
///
/// Each stroke is resampled to a fixed number of points; the character is
/// normalized (centroid + RMS radius); candidates are shortlisted by a
/// directional ink-feature map (order- and stroke-count-independent) and
/// re-ranked with a stroke-by-stroke shape cost, so a wrong stroke order or a
/// stroke drawn in two pieces still finds the right kanji. It ranks "which of
/// these ~960 kanji did I mean", it is not general OCR.
enum KanjiRecognizer {
    typealias Pt = SIMD2<Double>
    typealias Stroke = [Pt]

    static let samples = 16
    private static let grid = 22
    private static let blurPasses = 2
    private static let ori = 4
    private static let featureLen = grid * grid * ori
    private static let shortlist = 60
    private static let countPenalty = 0.015
    private static let shapeWeight = 0.05

    struct Candidate: Sendable {
        let char: String
        let strokes: [Stroke]
        let features: [Float]
    }

    // MARK: Geometry

    /// Flattens a path into a dense polyline (curves in 12 steps, like the web).
    static func flatten(_ path: Path) -> Stroke {
        var pts: Stroke = []
        var cur = Pt.zero
        func cubic(_ p1: Pt, _ p2: Pt, _ p3: Pt) {
            let p0 = cur
            for i in 1...12 {
                let t = Double(i) / 12, u = 1 - t
                pts.append(u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
            }
            cur = p3
        }
        path.forEach { element in
            switch element {
            case .move(let to), .line(let to):
                cur = Pt(to.x, to.y); pts.append(cur)
            case .curve(let to, let c1, let c2):
                cubic(Pt(c1.x, c1.y), Pt(c2.x, c2.y), Pt(to.x, to.y))
            case .quadCurve(let to, let c):
                // Raise the quadratic to a cubic.
                let q = Pt(c.x, c.y), e = Pt(to.x, to.y)
                cubic(cur + 2.0 / 3.0 * (q - cur), e + 2.0 / 3.0 * (q - e), e)
            case .closeSubpath:
                break
            }
        }
        return pts
    }

    static func resample(_ points: Stroke, n: Int = samples) -> Stroke {
        guard let first = points.first else { return [] }
        if points.count == 1 { return Array(repeating: first, count: n) }
        var cum = [0.0]
        for i in 1..<points.count { cum.append(cum[i - 1] + simd_distance(points[i], points[i - 1])) }
        let total = cum[cum.count - 1]
        if total == 0 { return Array(repeating: first, count: n) }
        var out: Stroke = []
        var seg = 1
        for k in 0..<n {
            let target = total * Double(k) / Double(n - 1)
            while seg < cum.count - 1 && cum[seg] < target { seg += 1 }
            let span = (cum[seg] - cum[seg - 1]) == 0 ? 1 : cum[seg] - cum[seg - 1]
            let f = (target - cum[seg - 1]) / span
            out.append(points[seg - 1] + (points[seg] - points[seg - 1]) * f)
        }
        return out
    }

    /// Centre on the centroid and scale by the RMS radius, so the glyph's mass
    /// (not its extreme corners) sets the size.
    static func normalize(_ strokes: [Stroke]) -> [Stroke] {
        var sum = Pt.zero, n = 0.0
        for s in strokes { for p in s { sum += p; n += 1 } }
        guard n > 0 else { return strokes }
        let c = sum / n
        var r2 = 0.0
        for s in strokes { for p in s { r2 += simd_length_squared(p - c) } }
        let r = (r2 / n).squareRoot()
        let scale = r == 0 ? 1 : r
        return strokes.map { $0.map { ($0 - c) / scale } }
    }

    private static func strokeDist(_ a: Stroke, _ b: Stroke) -> Double {
        var d = 0.0
        for k in 0..<samples { d += simd_distance(a[k], b[k]) }
        d /= Double(samples)
        // Endpoints say where a stroke starts and stops; weight them extra.
        let ends = simd_distance(a[0], b[0]) + simd_distance(a[samples - 1], b[samples - 1])
        return d + 0.25 * ends
    }

    // MARK: Directional ink features

    /// Lays the ink on a small grid and records, per cell, how much of it runs
    /// horizontally, vertically or along either diagonal (direction-less).
    static func inkFeatures(_ strokes: [Stroke]) -> [Float] {
        let dense = strokes.filter { !$0.isEmpty }.map { $0.count == 1 ? [$0[0], $0[0]] : $0 }
        guard !dense.isEmpty else { return [Float](repeating: 0, count: featureLen) }
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for st in dense { for p in st {
            minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
        } }
        let size = max(maxX - minX, maxY - minY, 1e-6)
        let span = Double(grid - 3)
        let ox = (maxX + minX) / 2, oy = (maxY + minY) / 2
        var f = [Float](repeating: 0, count: featureLen)

        func put(_ gx: Double, _ gy: Double, _ o: Int, _ w: Double) {
            let x0 = Int(gx.rounded(.down)), y0 = Int(gy.rounded(.down))
            let fx = gx - Double(x0), fy = gy - Double(y0)
            for dy in 0..<2 { for dx in 0..<2 {
                let x = x0 + dx, y = y0 + dy
                if x < 0 || y < 0 || x >= grid || y >= grid { continue }
                f[(y * grid + x) * ori + o] += Float(w * (dx == 1 ? fx : 1 - fx) * (dy == 1 ? fy : 1 - fy))
            } }
        }

        for st in dense {
            for i in 1..<st.count {
                let dx = st[i].x - st[i - 1].x, dy = st[i].y - st[i - 1].y
                let len = (dx * dx + dy * dy).squareRoot()
                if len == 0 { continue }
                var ang = atan2(dy, dx)
                if ang < 0 { ang += .pi }
                if ang >= .pi { ang -= .pi }
                let pos = ang / .pi * Double(ori)
                let o0 = Int(pos.rounded(.down)) % ori
                let frac = pos - pos.rounded(.down)
                let steps = max(1, Int(((len / size) * span * 2).rounded(.up)))
                for k in 0..<steps {
                    let t = (Double(k) + 0.5) / Double(steps)
                    let gx = ((st[i - 1].x + dx * t - ox) / size) * span + Double(grid) / 2
                    let gy = ((st[i - 1].y + dy * t - oy) / size) * span + Double(grid) / 2
                    let w = (len / size) / Double(steps)
                    put(gx, gy, o0, w * (1 - frac))
                    put(gx, gy, (o0 + 1) % ori, w * frac)
                }
            }
        }

        // Blur (two passes of [1 2 1] x [1 2 1]) so near-misses overlap, then L2-normalize.
        var tmp = [Float](repeating: 0, count: featureLen)
        for _ in 0..<blurPasses {
            for y in 0..<grid { for x in 0..<grid { for o in 0..<ori {
                var acc: Float = 0, wsum: Float = 0
                for dy in -1...1 { for dx in -1...1 {
                    let X = x + dx, Y = y + dy
                    if X < 0 || Y < 0 || X >= grid || Y >= grid { continue }
                    let w: Float = (dx == 0 ? 2 : 1) * (dy == 0 ? 2 : 1)
                    acc += f[(Y * grid + X) * ori + o] * w
                    wsum += w
                } }
                tmp[(y * grid + x) * ori + o] = acc / wsum
            } } }
            f = tmp
        }
        var norm: Float = 0
        for v in f { norm += v * v }
        norm = norm.squareRoot()
        if norm == 0 { norm = 1 }
        for i in 0..<featureLen { f[i] /= norm }
        return f
    }

    private static func dot(_ a: [Float], _ b: [Float]) -> Float {
        var s: Float = 0
        for i in 0..<featureLen { s += a[i] * b[i] }
        return s
    }

    // MARK: Candidates and ranking

    /// Samples every KanjiVG stroke of `chars` once.
    static func makeCandidates(_ entries: [String: KanjiVGEntry], chars: Set<String>? = nil) -> [Candidate] {
        entries.compactMap { char, entry in
            if let chars, !chars.contains(char) { return nil }
            let raw = entry.strokes.compactMap { SVGPathParser.parse($0).map { flatten($0.path) } }
            guard !raw.isEmpty else { return nil }
            return Candidate(char: char, strokes: normalize(raw.map { resample($0) }), features: inkFeatures(raw))
        }
    }

    /// Pointer samples arrive sparse, so densify before measuring direction.
    private static func densify(_ points: Stroke, step: Double) -> Stroke {
        var out: Stroke = [points[0]]
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let n = max(1, Int((simd_distance(a, b) / step).rounded(.up)))
            for k in 1...n { out.append(a + (b - a) * (Double(k) / Double(n))) }
        }
        return out
    }

    private static func orderedCost(_ user: [Stroke], _ cand: [Stroke]) -> Double {
        let m = min(user.count, cand.count)
        var sum = 0.0
        for i in 0..<m { sum += strokeDist(user[i], cand[i]) }
        return sum / Double(m)
    }

    static func recognize(_ drawn: [Stroke], candidates: [Candidate], limit: Int = 12) -> [String] {
        let usable = drawn.filter { !$0.isEmpty }
        guard !usable.isEmpty else { return [] }
        // Light smoothing of finger jitter: resample each stroke to a calm polyline.
        let calm = usable.map { $0.count < 2 ? $0 : resample(densify($0, step: 1), n: 40) }
        let feat = inkFeatures(calm)
        let first = candidates
            .map { (c: $0, sim: dot(feat, $0.features)) }
            .sorted { $0.sim > $1.sim }
            .prefix(shortlist)
        let user = normalize(usable.map { resample($0) })
        return first
            .map { entry -> (char: String, score: Double) in
                let diff = abs(entry.c.strokes.count - user.count)
                let shape = diff <= 1 ? orderedCost(user, entry.c.strokes) : 1.5
                return (entry.c.char, -Double(entry.sim) + countPenalty * Double(diff) + shapeWeight * shape)
            }
            .sorted { $0.score < $1.score }
            .prefix(limit)
            .map(\.char)
    }
}
