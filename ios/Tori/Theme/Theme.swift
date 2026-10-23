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
    /// Use the clear glass variant on iOS 26 (see-through, for rich scenic backgrounds).
    var clearGlass = false

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
        case .dusk:
            Palette(bg: Color(hex: 0x1C2540), text: .white, muted: Color.white.opacity(0.70),
                    accent: Color(hex: 0xFFC978), accentFg: Color(hex: 0x2A1B05),
                    yellow: Color(hex: 0xFFD26A), green: Color(hex: 0x6FE0A8), red: Color(hex: 0xFF8A70), blue: Color(hex: 0x8FC1FF),
                    card: Color.white.opacity(0.12), glassFill: Color.white.opacity(0.14), glassStrongFill: Color.white.opacity(0.2),
                    edge: Color.white.opacity(0.4), highlight: Color.white.opacity(0.7),
                    hairline: Color.white.opacity(0.2), shadow: Color.black.opacity(0.4),
                    blobs: [Color(hex: 0x2B3A5C), Color(hex: 0xC98A63), Color(hex: 0x3C4A63), Color(hex: 0x5E6B2D)],
                    solidCard: Color(hex: 0x27304F), clearGlass: true)
        case .aurora:
            Palette(bg: Color(hex: 0x07142A), text: .white, muted: Color.white.opacity(0.70),
                    accent: Color(hex: 0x7CF0C9), accentFg: Color(hex: 0x04251C),
                    yellow: Color(hex: 0xFFE08A), green: Color(hex: 0x6FE0A8), red: Color(hex: 0xFF8F9E), blue: Color(hex: 0x8FB8FF),
                    card: Color.white.opacity(0.10), glassFill: Color.white.opacity(0.12), glassStrongFill: Color.white.opacity(0.2),
                    edge: Color.white.opacity(0.4), highlight: Color.white.opacity(0.7),
                    hairline: Color.white.opacity(0.2), shadow: Color.black.opacity(0.4),
                    blobs: [Color(hex: 0x0A1F3A), Color(hex: 0x1F6B5C), Color(hex: 0x3B2A78), Color(hex: 0x103B4A)],
                    solidCard: Color(hex: 0x12263F), clearGlass: true)
        case .neon:
            Palette(bg: Color(hex: 0x120A33), text: .white, muted: Color.white.opacity(0.72),
                    accent: Color(hex: 0xFF5CC8), accentFg: .white,
                    yellow: Color(hex: 0xFFE066), green: Color(hex: 0x5CF2C0), red: Color(hex: 0xFF6B8A), blue: Color(hex: 0x6CC8FF),
                    card: Color.white.opacity(0.10), glassFill: Color.white.opacity(0.12), glassStrongFill: Color.white.opacity(0.2),
                    edge: Color.white.opacity(0.4), highlight: Color.white.opacity(0.7),
                    hairline: Color.white.opacity(0.2), shadow: Color.black.opacity(0.45),
                    blobs: [Color(hex: 0x2A0F55), Color(hex: 0x9C2E8A), Color(hex: 0xFF5C7A), Color(hex: 0x0B0820)],
                    solidCard: Color(hex: 0x1E1245), clearGlass: true)
        case .sakura:
            Palette(bg: Color(hex: 0xFBE7EC), text: Color(hex: 0x3A2230), muted: Color(hex: 0x7A5A68),
                    accent: Color(hex: 0xD94F78), accentFg: .white,
                    yellow: Color(hex: 0xE3A008), green: Color(hex: 0x22A15A), red: Color(hex: 0xEA4F3D), blue: Color(hex: 0x4F7CF5),
                    card: Color.white.opacity(0.55), glassFill: Color.white.opacity(0.5), glassStrongFill: Color.white.opacity(0.75),
                    edge: Color.white.opacity(0.8), highlight: Color.white.opacity(0.95),
                    hairline: Color(hex: 0x3A2230, opacity: 0.12), shadow: Color(hex: 0xD94F78, opacity: 0.25),
                    blobs: [Color(hex: 0xF6C6D8), Color(hex: 0xFFE0D2), Color(hex: 0xE8D7FF), Color(hex: 0xFFF1D0)],
                    solidCard: Color(hex: 0xFFF4F7))
        case .ink:
            Palette(bg: Color(hex: 0xF1ECE0), text: Color(hex: 0x1E1C1A), muted: Color(hex: 0x6B655C),
                    accent: Color(hex: 0xB5382C), accentFg: .white,
                    yellow: Color(hex: 0xC98A12), green: Color(hex: 0x3F8F5A), red: Color(hex: 0xB5382C), blue: Color(hex: 0x3F6FA8),
                    card: Color.white.opacity(0.5), glassFill: Color.white.opacity(0.5), glassStrongFill: Color.white.opacity(0.75),
                    edge: Color.white.opacity(0.8), highlight: Color.white.opacity(0.95),
                    hairline: Color(hex: 0x1E1C1A, opacity: 0.12), shadow: Color.black.opacity(0.18),
                    blobs: [Color(hex: 0xE8E0D0), Color(hex: 0xD9D2C3), Color(hex: 0xCBC4B4), Color(hex: 0xF4EFE4)],
                    solidCard: Color(hex: 0xF7F3EA))
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

extension Palette {
    /// The palette of the chosen theme, kept in step by `SettingsStore`. Presented
    /// sheets can start from the environment default, so it must be the live one.
    nonisolated(unsafe) static var current = Palette.make(.dusk)
}

private struct PaletteKey: EnvironmentKey {
    static var defaultValue: Palette { Palette.current }
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

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(p.clearGlass ? (strong ? .clear.tint(Color.black.opacity(0.14)) : .clear) : (strong ? .regular.tint(p.glassStrongFill.opacity(0.35)) : .regular), in: shape)
        } else {
            legacy(content, shape: shape)
        }
    }

    private func legacy(_ content: Content, shape: RoundedRectangle) -> some View {
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

/// Card for lists and sections. On iOS 26 it is real Liquid Glass (the system
/// caches it, so long lists stay smooth); earlier systems and Reduce Transparency
/// get a translucent fill with no blur, for scroll performance.
struct SolidCard: ViewModifier {
    var radius: CGFloat = Radius.card
    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(p.clearGlass ? .clear.tint(Color.black.opacity(0.16)) : .regular, in: shape)
        } else {
            content
                .background(shape.fill(p.card))
                .overlay(shape.strokeBorder(p.hairline, lineWidth: 1))
        }
    }
}

extension View {
    func glass(strong: Bool = false, radius: CGFloat = Radius.card, shadowed: Bool = true) -> some View {
        modifier(GlassSurface(strong: strong, radius: radius, shadowed: shadowed))
    }

    func solidCard(radius: CGFloat = Radius.card) -> some View {
        modifier(SolidCard(radius: radius))
    }

    /// Sheets are Liquid Glass by default on iOS 26; earlier systems get the
    /// frosted material.
    @ViewBuilder
    func toriSheetBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            presentationBackground(.ultraThinMaterial)
        }
    }

    /// Serif face so kanji render as Mincho (Hiragino Mincho on iOS).
    func jp(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        font(.system(size: size, weight: weight, design: .serif))
    }
}

// MARK: - Ambient field

/// The scene behind everything. Glass only shows what is behind it, so the Dusk
/// theme paints a landscape with real edges (ridges, a sun, clouds) for the blur
/// and refraction to work on; the pastel themes use four soft colour blobs.
struct AmbientBackground: View {
    var theme: ThemeID = .glass
    @Environment(\.palette) private var p

    var body: some View {
        Group {
            if theme.isScene { SceneBackground(theme: theme) } else { blobs }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var blobs: some View {
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
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).blur(radius: size * 0.22)
    }
}

/// Dusk: a sky with a low sun and clouds over layered ridges and a meadow.
struct DuskBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(hex: 0x1B2A4E), location: 0),
                    .init(color: Color(hex: 0x3E5080), location: 0.32),
                    .init(color: Color(hex: 0xB9806C), location: 0.52),
                    .init(color: Color(hex: 0xF2B880), location: 0.66),
                ], startPoint: .top, endPoint: .bottom)

                // Sun glow just above the ridges.
                RadialGradient(colors: [Color(hex: 0xFFE7B0).opacity(0.7), Color(hex: 0xFFC27A).opacity(0.28), .clear],
                               center: UnitPoint(x: 0.74, y: 0.58), startRadius: 0, endRadius: w * 0.7)

                // Clouds: soft, with a lit underside.
                cloud(w * 0.9, 0.16 * h, x: 0.22 * w, y: 0.13 * h, tint: 0xC9C8EE, op: 0.20)
                cloud(w * 0.8, 0.12 * h, x: 0.78 * w, y: 0.24 * h, tint: 0xFFD7B0, op: 0.28)
                cloud(w * 1.1, 0.10 * h, x: 0.30 * w, y: 0.42 * h, tint: 0xF3C4A0, op: 0.30)

                ridge(h * 0.60, amp: h * 0.045, phase: 0.2, w: w, h: h, color: Color(hex: 0x6B6B97).opacity(0.75))
                ridge(h * 0.66, amp: h * 0.06, phase: 1.4, w: w, h: h, color: Color(hex: 0x465577))
                // The big hillside, as in a mountain photo: it climbs towards the right.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.80))
                    p.addCurve(to: CGPoint(x: w * 0.58, y: h * 0.70),
                               control1: CGPoint(x: w * 0.18, y: h * 0.79), control2: CGPoint(x: w * 0.38, y: h * 0.76))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.57),
                               control1: CGPoint(x: w * 0.76, y: h * 0.65), control2: CGPoint(x: w * 0.9, y: h * 0.60))
                    p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(hex: 0x4A5A38), Color(hex: 0x2D3A26)], startPoint: .top, endPoint: .bottom))
                // Meadow in front.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.86))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.80),
                               control1: CGPoint(x: w * 0.35, y: h * 0.84), control2: CGPoint(x: w * 0.7, y: h * 0.86))
                    p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(hex: 0x7D8A3A), Color(hex: 0x3D4A1F)], startPoint: .top, endPoint: .bottom))

                // Keeps white text readable on the bright horizon.
                LinearGradient(colors: [Color.black.opacity(0.32), Color.black.opacity(0.24), Color.black.opacity(0.46)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private func cloud(_ width: CGFloat, _ height: CGFloat, x: CGFloat, y: CGFloat, tint: UInt32, op: Double) -> some View {
        Ellipse().fill(Color(hex: tint).opacity(op))
            .frame(width: width, height: height)
            .blur(radius: height * 0.28)
            .position(x: x, y: y)
    }

    private func ridge(_ baseY: CGFloat, amp: CGFloat, phase: Double, w: CGFloat, h: CGFloat, color: Color) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: h))
            let steps = 28
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let y = baseY - amp * (0.55 * sin(t * 6.1 + phase) + 0.30 * sin(t * 13.7 + phase * 2.1) + 0.15 * sin(t * 27 + phase))
                p.addLine(to: CGPoint(x: t * w, y: y))
            }
            p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
        }
        .fill(color)
    }
}
