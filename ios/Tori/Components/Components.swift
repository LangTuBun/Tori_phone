import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var p
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(p.accentFg)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .frame(minHeight: 48)
            .background(Capsule().fill(LinearGradient(colors: [p.accent, p.accent.opacity(0.82)], startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(p.highlight.opacity(0.35), lineWidth: 1))
            .shadow(color: p.accent.opacity(0.35), radius: 12, y: 6)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.palette) private var p

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(p.text)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(minHeight: 44)
            .glass(radius: 22, shadowed: false)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var toriPrimary: PrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == GlassButtonStyle {
    static var toriGlass: GlassButtonStyle { .init() }
}

/// Plain press feedback for tappable cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Chips and segmented controls

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? p.accentFg : p.text)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(Capsule().fill(selected ? AnyShapeStyle(p.accent) : AnyShapeStyle(p.card)))
                .overlay(Capsule().strokeBorder(selected ? Color.clear : p.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Segmented control look-alike: track = ink @ 6%, selected thumb = glass-strong.
struct GlassSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    @Environment(\.palette) private var p
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i]
                let isOn = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOn ? p.text : p.muted)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if isOn {
                                Capsule().fill(Material.regularMaterial)
                                    .overlay(Capsule().fill(p.glassStrongFill).opacity(0.7))
                                    .overlay(Capsule().strokeBorder(p.edge, lineWidth: 1))
                                    .shadow(color: p.shadow.opacity(0.25), radius: 5, y: 2)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(p.text.opacity(0.06)))
    }
}

// MARK: - Small pieces

struct PosTag: View {
    let pos: String
    @Environment(\.palette) private var p

    var body: some View {
        Text(Japanese.posLabel(pos).uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(p.posForeground(pos))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(p.posColor(pos)))
    }
}

struct CapsuleProgress: View {
    let value: Double
    @Environment(\.palette) private var p

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.text.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [p.accent, p.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityValue("\(Int(value * 100))%")
    }
}

struct SpeakButton: View {
    let text: String
    @Environment(Speaker.self) private var speaker
    @Environment(\.palette) private var p

    var body: some View {
        Button { speaker.speak(text) } label: {
            Image(systemName: speaker.speakingText == text ? "speaker.wave.3.fill" : "speaker.wave.2")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(p.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(p.accent.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speak")
    }
}

/// Reading above the word, for words that contain kanji.
struct FuriganaWord: View {
    let kanji: String
    let kana: String
    var size: CGFloat = 20
    @Environment(\.palette) private var p

    var body: some View {
        if kanji.isEmpty || kanji == kana || !Japanese.hasKanji(kanji) {
            Text(kanji.isEmpty ? kana : kanji).jp(size)
        } else {
            VStack(spacing: 1) {
                Text(kana)
                    .font(.system(size: max(9, size * 0.42), weight: .medium, design: .serif))
                    .foregroundStyle(p.muted)
                Text(kanji).jp(size)
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let message: String
    @Environment(\.palette) private var p

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(p.muted)
            Text(message).font(.subheadline).foregroundStyle(p.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

/// Section label used above groups of cards.
struct SectionLabel: View {
    let text: String
    @Environment(\.palette) private var p

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(p.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Ruby text

/// Wraps its children left-to-right, top-to-bottom.
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width {
                x = 0; y += lineHeight + lineSpacing; lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, CGSize(width: maxX, height: y + lineHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        for (sub, f) in zip(subviews, result.frames) {
            sub.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size))
        }
    }
}

/// Renders `<ruby>` markup with the reading above its base; falls back to a
/// plain wrapping `Text` when there is no ruby markup or furigana is hidden.
struct RubyText: View {
    let html: String
    var size: CGFloat = 18
    var showFurigana = true
    @Environment(\.palette) private var p

    init(_ html: String, size: CGFloat = 18, showFurigana: Bool = true) {
        self.html = html
        self.size = size
        self.showFurigana = showFurigana
    }

    var body: some View {
        if !showFurigana || !RubyParser.hasRuby(html) {
            Text(RubyParser.plain(html))
                .jp(size, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            FlowLayout(spacing: 0, lineSpacing: 2) {
                ForEach(RubyParser.parse(html)) { seg in
                    VStack(spacing: 0) {
                        Text(seg.reading ?? " ")
                            .font(.system(size: max(8, size * 0.45), weight: .medium, design: .serif))
                            .foregroundStyle(p.muted)
                        Text(seg.base).jp(size, weight: .medium)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(RubyParser.plain(html))
        }
    }
}

// MARK: - Pitch accent

struct PitchAccentView: View {
    let kana: String
    let pitch: Int?
    var size: CGFloat = 16
    @Environment(\.palette) private var p
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        if let pitch {
            let morae = Japanese.splitMorae(kana)
            let (levels, afterHigh) = Japanese.pitchLevels(moraCount: morae.count, pitch: pitch)
            let type = Japanese.classifyPitch(pitch, moraCount: morae.count)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(morae.indices, id: \.self) { i in
                        Text(morae[i])
                            .jp(size, weight: .medium)
                            .padding(.vertical, 3)
                            .overlay(alignment: levels[i] ? .top : .bottom) {
                                Capsule().fill(p.accent).frame(height: 2)
                            }
                    }
                    Circle()
                        .fill(afterHigh ? p.accent : p.muted.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .padding(.leading, 2)
                }
                Text(settings.t("vocab.pitch.types.\(type.rawValue)"))
                    .font(.caption2).foregroundStyle(p.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(settings.t("vocab.pitch.label")): \(settings.t("vocab.pitch.types.\(type.rawValue)"))")
        }
    }
}
