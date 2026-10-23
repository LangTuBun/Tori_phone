import SwiftUI

/// Minimal SVG path parser for KanjiVG stroke data: M L H V C S Q T Z in
/// absolute and relative forms (no arcs; KanjiVG does not use them).
enum SVGPathParser {
    struct Stroke {
        let path: Path
        let start: CGPoint
    }

    private enum Token { case command(Character), number(Double) }

    static func parse(_ d: String) -> Stroke? {
        let tokens = tokenize(d)
        var path = Path()
        var cur = CGPoint.zero, subStart = CGPoint.zero
        var lastCubic: CGPoint?, lastQuad: CGPoint?
        var first: CGPoint?
        var i = 0
        var cmd: Character = " "

        func nums(_ n: Int) -> [Double]? {
            guard i + n <= tokens.count else { return nil }
            var out: [Double] = []
            for k in 0..<n {
                guard case .number(let v) = tokens[i + k] else { return nil }
                out.append(v)
            }
            i += n
            return out
        }
        func atNumber() -> Bool {
            if i < tokens.count, case .number = tokens[i] { return true }
            return false
        }

        while i < tokens.count {
            if case .command(let c) = tokens[i] { cmd = c; i += 1 }
            else if cmd == " " { return nil }
            let rel = cmd.isLowercase
            let upper = Character(cmd.uppercased())
            switch upper {
            case "M":
                guard let v = nums(2) else { return nil }
                cur = rel ? CGPoint(x: cur.x + v[0], y: cur.y + v[1]) : CGPoint(x: v[0], y: v[1])
                subStart = cur
                path.move(to: cur)
                if first == nil { first = cur }
                cmd = rel ? "l" : "L"          // further pairs are implicit lineto
                lastCubic = nil; lastQuad = nil
            case "L":
                repeat {
                    guard let v = nums(2) else { return nil }
                    cur = rel ? CGPoint(x: cur.x + v[0], y: cur.y + v[1]) : CGPoint(x: v[0], y: v[1])
                    path.addLine(to: cur)
                } while atNumber()
                lastCubic = nil; lastQuad = nil
            case "H":
                repeat {
                    guard let v = nums(1) else { return nil }
                    cur.x = rel ? cur.x + v[0] : v[0]
                    path.addLine(to: cur)
                } while atNumber()
                lastCubic = nil; lastQuad = nil
            case "V":
                repeat {
                    guard let v = nums(1) else { return nil }
                    cur.y = rel ? cur.y + v[0] : v[0]
                    path.addLine(to: cur)
                } while atNumber()
                lastCubic = nil; lastQuad = nil
            case "C":
                repeat {
                    guard let v = nums(6) else { return nil }
                    let o = rel ? cur : .zero
                    let c1 = CGPoint(x: o.x + v[0], y: o.y + v[1])
                    let c2 = CGPoint(x: o.x + v[2], y: o.y + v[3])
                    let end = CGPoint(x: o.x + v[4], y: o.y + v[5])
                    path.addCurve(to: end, control1: c1, control2: c2)
                    cur = end; lastCubic = c2
                } while atNumber()
                lastQuad = nil
            case "S":
                repeat {
                    guard let v = nums(4) else { return nil }
                    let o = rel ? cur : .zero
                    let c1 = lastCubic.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    let c2 = CGPoint(x: o.x + v[0], y: o.y + v[1])
                    let end = CGPoint(x: o.x + v[2], y: o.y + v[3])
                    path.addCurve(to: end, control1: c1, control2: c2)
                    cur = end; lastCubic = c2
                } while atNumber()
                lastQuad = nil
            case "Q":
                repeat {
                    guard let v = nums(4) else { return nil }
                    let o = rel ? cur : .zero
                    let c = CGPoint(x: o.x + v[0], y: o.y + v[1])
                    let end = CGPoint(x: o.x + v[2], y: o.y + v[3])
                    path.addQuadCurve(to: end, control: c)
                    cur = end; lastQuad = c
                } while atNumber()
                lastCubic = nil
            case "T":
                repeat {
                    guard let v = nums(2) else { return nil }
                    let o = rel ? cur : .zero
                    let c = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    let end = CGPoint(x: o.x + v[0], y: o.y + v[1])
                    path.addQuadCurve(to: end, control: c)
                    cur = end; lastQuad = c
                } while atNumber()
                lastCubic = nil
            case "Z":
                path.closeSubpath()
                cur = subStart
                lastCubic = nil; lastQuad = nil
            default:
                return nil
            }
        }
        guard let first else { return nil }
        return Stroke(path: path, start: first)
    }

    private static func tokenize(_ d: String) -> [Token] {
        let s = Array(d.unicodeScalars)
        var out: [Token] = []
        var i = 0
        func isDigit(_ u: Unicode.Scalar) -> Bool { u.value >= 48 && u.value <= 57 }
        while i < s.count {
            let u = s[i]
            if isDigit(u) || u == "-" || u == "+" || u == "." {
                var j = i
                if s[j] == "-" || s[j] == "+" { j += 1 }
                var seenDot = false
                while j < s.count {
                    if isDigit(s[j]) { j += 1 }
                    else if s[j] == ".", !seenDot { seenDot = true; j += 1 }
                    else { break }
                }
                var text = ""
                text.unicodeScalars.append(contentsOf: s[i..<j])
                if let v = Double(text) { out.append(.number(v)) }
                i = max(j, i + 1)
            } else if (u.properties.isAlphabetic) {
                out.append(.command(Character(u)))
                i += 1
            } else {
                i += 1
            }
        }
        return out
    }
}
