import SwiftUI

extension Color {
    /// `0xRRGGBB` with optional opacity.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Design tokens from DESIGN.md (source of truth: src/index.css).
struct Palette {
    var bg: Color
    var text: Color
    var muted: Color
    var accent: Color
    var accentFg: Color
    var yellow: Color
    var green: Color
    var red: Color
    var blue: Color
    var card: Color
    var glassFill: Color
    var glassStrongFill: Color
    var edge: Color
    var highlight: Color
    var hairline: Color
    var shadow: Color
    var blobs: [Color]
    var solidCard: Color

    static func make(_ id: ThemeID) -> Palette {
        switch id {
        case .glass:
            Palette(bg: Color(hex: 0xE9ECF5), text: Color(hex: 0x14182A), muted: Color(hex: 0x5A6180),
                    accent: Color(hex: 0x4458F0), accentFg: .white,
                    yellow: Color(hex: 0xE3A008), green: Color(hex: 0x22A15A), red: Color(hex: 0xEA4F3D), blue: Color(hex: 0x4F7CF5),
                    card: Color.white.opacity(0.74), glassFill: Color.white.opacity(0.52), glassStrongFill: Color.white.opacity(0.78),
                    edge: Color.white.opacity(0.75), highlight: Color.white.opacity(0.9),
                    hairline: Color(hex: 0x14182A, opacity: 0.10), shadow: Color(hex: 0x4458F0, opacity: 0.28),
                    blobs: [Color(hex: 0xB9C4FF), Color(hex: 0xFFD0C2), Color(hex: 0xBFEEDE), Color(hex: 0xE8D7FF)],
                    solidCard: Color(hex: 0xF6F7FB))
        case .graphite:
            Palette(bg: Color(hex: 0xECEEF2), text: Color(hex: 0x15171C), muted: Color(hex: 0x5B606B),
                    accent: Color(hex: 0x2F6FED), accentFg: .white,
                    yellow: Color(hex: 0xE3A008), green: Color(hex: 0x22A15A), red: Color(hex: 0xEA4F3D), blue: Color(hex: 0x3F84F2),
                    card: Color.white.opacity(0.76), glassFill: Color.white.opacity(0.52), glassStrongFill: Color.white.opacity(0.78),
                    edge: Color.white.opacity(0.75), highlight: Color.white.opacity(0.9),
                    hairline: Color(hex: 0x15171C, opacity: 0.10), shadow: Color(hex: 0x2F6FED, opacity: 0.24),
                    blobs: [Color(hex: 0xCDD6E6), Color(hex: 0xE6DCCF), Color(hex: 0xCFE3DC), Color(hex: 0xDCD6EA)],
                    solidCard: Color(hex: 0xF6F7F9))
        case .midnight:
            Palette(bg: Color(hex: 0x080A14), text: Color(hex: 0xEEF0FB), muted: Color(hex: 0x9AA2C4),
                    accent: Color(hex: 0x8B9BFF), accentFg: Color(hex: 0x0B1030),
                    yellow: Color(hex: 0xFFD26A), green: Color(hex: 0x52D6A1), red: Color(hex: 0xFF7D5C), blue: Color(hex: 0x8FB0FF),
                    card: Color(hex: 0x1A1E36, opacity: 0.72), glassFill: Color(hex: 0x1E223C, opacity: 0.5), glassStrongFill: Color(hex: 0x282E54, opacity: 0.78),
                    edge: Color.white.opacity(0.14), highlight: Color.white.opacity(0.22),
                    hairline: Color.white.opacity(0.10), shadow: Color.black.opacity(0.7),
                    blobs: [Color(hex: 0x2A3580), Color(hex: 0x6B2F3C), Color(hex: 0x14594A), Color(hex: 0x4A2D80)],
                    solidCard: Color(hex: 0x1A1E36))
        }
    }

    /// Part-of-speech tint (src/components/ui/PosTag.tsx).
    func posColor(_ pos: String) -> Color {
        if pos.hasPrefix("verb") { return blue }
        if pos.hasPrefix("adj") { return green }
        if pos == "noun" { return yellow }
        if pos == "adverb" { return red }
        return muted
    }

    func posForeground(_ pos: String) -> Color {
        if pos == "noun" { return Color(hex: 0x3A2A00) }
        if pos == "expression" || pos == "conjunction" || !(pos.hasPrefix("verb") || pos.hasPrefix("adj") || pos == "adverb") { return bg }
        return .white
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(.glass)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Radii

enum Radius {
    static let card: CGFloat = 20
    static let small: CGFloat = 14
    static let sheet: CGFloat = 28
}

// MARK: - Glass surfaces

/// Frosted glass for chrome (tab bar, headers, modals, flashcards):
/// a system material, a theme tint, a 1pt gradient edge and a soft shadow.
/// Falls back to an opaque fill when Reduce Transparency is on.
struct GlassSurface: ViewModifier {
    var strong = false
    var radius: CGFloat = Radius.card
    var shadowed = true

    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(p.solidCard)
                } else {
                    ZStack {
                        shape.fill(strong ? Material.regularMaterial : Material.ultraThinMaterial)
                        shape.fill(strong ? p.glassStrongFill : p.glassFill).opacity(0.55)
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [p.highlight, p.edge, p.edge.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            }
            .clipShape(shape)
            .shadow(color: shadowed ? p.shadow.opacity(0.55) : .clear, radius: 16, y: 10)
    }
}

/// Solid translucent card for long lists: no blur, for scroll performance.
struct SolidCard: ViewModifier {
    var radius: CGFloat = Radius.card
    @Environment(\.palette) private var p

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(p.card))
            .overlay(shape.strokeBorder(p.hairline, lineWidth: 1))
    }
}

extension View {
    func glass(strong: Bool = false, radius: CGFloat = Radius.card, shadowed: Bool = true) -> some View {
        modifier(GlassSurface(strong: strong, radius: radius, shadowed: shadowed))
    }

    func solidCard(radius: CGFloat = Radius.card) -> some View {
        modifier(SolidCard(radius: radius))
    }

    /// Serif face so kanji render as Mincho (Hiragino Mincho on iOS).
    func jp(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        font(.system(size: size, weight: weight, design: .serif))
    }
}

// MARK: - Ambient field

/// Four soft color blobs behind everything; all color lives here so the
/// controls above can stay neutral.
struct AmbientBackground: View {
    @Environment(\.palette) private var p

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                p.bg
                blob(p.blobs[0], size: w * 0.95).position(x: w * 0.10, y: h * 0.06)
                blob(p.blobs[1], size: w * 0.85).position(x: w * 0.95, y: h * 0.30)
                blob(p.blobs[2], size: w * 0.95).position(x: w * 0.05, y: h * 0.72)
                blob(p.blobs[3], size: w * 0.80).position(x: w * 0.90, y: h * 0.96)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).blur(radius: size * 0.22)
    }
}
