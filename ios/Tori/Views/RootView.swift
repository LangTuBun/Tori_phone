import SwiftUI

enum Destination: String, CaseIterable, Identifiable, Hashable {
    case home, vocab, review, grammar, verbForms, transitivity, usage, kanji, radicals, kanjiLookup, kanjiRules, counters, homophones, accent, settings

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house"
        case .vocab: "book"
        case .review: "rectangle.stack"
        case .grammar: "text.alignleft"
        case .verbForms: "arrow.left.arrow.right"
        case .transitivity: "arrow.triangle.swap"
        case .usage: "text.bubble"
        case .kanji: "character"
        case .radicals: "square.grid.3x3"
        case .kanjiLookup: "magnifyingglass"
        case .kanjiRules: "pencil.and.list.clipboard"
        case .counters: "number"
        case .homophones: "bubble.left.and.bubble.right"
        case .accent: "waveform"
        case .settings: "slider.horizontal.3"
        }
    }

    var titleKey: String {
        switch self {
        case .home: "nav.home"
        case .vocab: "nav.vocabulary"
        case .review: "nav.review"
        case .grammar: "nav.grammar"
        case .verbForms: "nav.verbForms"
        case .transitivity: "nav.transitivity"
        case .usage: "nav.usage"
        case .kanji: "nav.kanji"
        case .radicals: "nav.radicals"
        case .kanjiLookup: "nav.lookup"
        case .kanjiRules: "nav.rules"
        case .counters: "nav.counters"
        case .homophones: "nav.homophones"
        case .accent: "nav.accent"
        case .settings: "nav.settings"
        }
    }

    /// The four tab-bar destinations; everything else lives in the More sheet.
    static let tabs: [Destination] = [.vocab, .review, .grammar, .kanji]

    static let groups: [(titleKey: String, items: [Destination])] = [
        ("nav.groups.learn", [.home, .vocab, .review]),
        ("nav.groups.grammar", [.grammar, .verbForms, .transitivity, .usage]),
        ("nav.groups.kanji", [.kanji, .radicals, .kanjiLookup, .kanjiRules]),
        ("nav.groups.more", [.counters, .homophones, .accent, .settings]),
    ]
}

private struct NavigateKey: EnvironmentKey {
    static let defaultValue: (Destination) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigate: (Destination) -> Void {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
}

/// Widest the content column and the tab bar grow on iPad.
enum ScreenWidth {
    static let content: CGFloat = 820
    static let tabBar: CGFloat = 560
}

struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data

    @State private var selection: Destination
    /// Screens already opened stay alive (hidden) so a review session or a
    /// scroll position survives switching tabs.
    @State private var visited: Set<Destination>
    /// `-kanji <char>` opens that kanji's sheet at launch (screenshots, UI tests).
    @State private var launchKanji: String?
    @State private var showMore = false

    init() {
        // `-open <destination>` launches straight into a screen (UI tests, screenshots).
        let args = ProcessInfo.processInfo.arguments
        let start = args.firstIndex(of: "-open").flatMap { args.indices.contains($0 + 1) ? Destination(rawValue: args[$0 + 1]) : nil } ?? .home
        _selection = State(initialValue: start)
        _visited = State(initialValue: [start])
        _launchKanji = State(initialValue: args.firstIndex(of: "-kanji").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil })
    }

    var body: some View {
        let palette = Palette.make(settings.theme)
        ZStack {
            AmbientBackground(theme: settings.theme)

            switch data.state {
            case .loading:
                ProgressView(settings.t("ios.loading")).tint(palette.accent)
            case .failed(let message):
                ContentUnavailableView(settings.t("ios.loadFailed"), systemImage: "exclamationmark.triangle", description: Text(message))
            case .ready:
                ZStack {
                    ForEach(Destination.allCases) { d in
                        if visited.contains(d) {
                            screen(d)
                                .opacity(selection == d ? 1 : 0)
                                .allowsHitTesting(selection == d)
                                .accessibilityHidden(selection != d)
                        }
                    }
                }
                // On iPad the screens keep a readable column instead of stretching edge to edge.
                .frame(maxWidth: ScreenWidth.content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    FloatingTabBar(selection: selection, showMore: $showMore, select: go)
                        .frame(maxWidth: ScreenWidth.tabBar)
                }
            }
        }
        .environment(\.palette, palette)
        .environment(\.navigate, go)
        .kanjiSheet($launchKanji)
        .tint(palette.accent)
        .foregroundStyle(palette.text)
        .preferredColorScheme(settings.theme.isDark ? .dark : .light)
        .sheet(isPresented: $showMore) {
            MoreSheet(selection: selection, select: go)
                .environment(\.palette, palette)
                .environment(settings)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Radius.sheet)
                .toriSheetBackground()
                .preferredColorScheme(settings.theme.isDark ? .dark : .light)
        }
    }

    private func go(_ destination: Destination) {
        visited.insert(destination)
        showMore = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { selection = destination }
    }

    @ViewBuilder
    private func screen(_ d: Destination) -> some View {
        switch d {
        case .home: HomeView()
        case .vocab: VocabView()
        case .review: ReviewView()
        case .grammar: GrammarView()
        case .verbForms: VerbFormsView()
        case .transitivity: TransitivityView()
        case .usage: UsageView()
        case .kanji: KanjiView()
        case .radicals: RadicalsView()
        case .kanjiLookup: KanjiLookupView()
        case .kanjiRules: KanjiRulesView()
        case .counters: CountersView()
        case .homophones: HomophonesView()
        case .accent: AccentView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Floating capsule tab bar

struct FloatingTabBar: View {
    let selection: Destination
    @Binding var showMore: Bool
    let select: (Destination) -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    @Namespace private var selectionPill
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var moreActive: Bool { !Destination.tabs.contains(selection) }

    var body: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            // One Liquid Glass bar; the selected tab is a second glass shape that
            // flows from tab to tab (glassEffectID) instead of jumping.
            GlassEffectContainer(spacing: 6) { bar }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        } else {
            bar
                .glass(strong: true, radius: 36)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var bar: some View {
        let row = HStack(spacing: 2) {
            ForEach(Destination.tabs) { d in
                item(symbol: d.symbol, title: settings.t(d.titleKey), active: selection == d, id: "tab.\(d.rawValue)") {
                    select(d)
                }
            }
            item(symbol: "ellipsis", title: settings.t("ios.more"), active: moreActive, id: "tab.more") {
                showMore = true
            }
        }
        .padding(6)
        if #available(iOS 26.0, *), !reduceTransparency {
            row.glassEffect(.regular, in: Capsule())
        } else {
            row
        }
    }

    private func item(symbol: String, title: String, active: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { itemLabel(symbol: symbol, title: title, active: active) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
            .accessibilityLabel(title)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The selected tab carries its own glass on iOS 26 (a tinted capsule that
    /// flows to the next tab), so the icon and text are never under the blur.
    @ViewBuilder
    private func itemLabel(symbol: String, title: String, active: Bool) -> some View {
        let label = VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
            Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(active ? p.accent : p.muted)
        .frame(maxWidth: .infinity, minHeight: 50)
        if #available(iOS 26.0, *), !reduceTransparency {
            if active {
                label
                    .glassEffect(.regular.tint(p.accent.opacity(0.3)).interactive(), in: Capsule())
                    .glassEffectID("tab.selection", in: selectionPill)
            } else {
                label.contentShape(Capsule())
            }
        } else {
            label
                .background {
                    if active {
                        Capsule().fill(p.accent.opacity(0.14))
                            .overlay(Capsule().strokeBorder(p.accent.opacity(0.25), lineWidth: 1))
                    }
                }
                .contentShape(Capsule())
        }
    }
}

// MARK: - More sheet

struct MoreSheet: View {
    let selection: Destination
    let select: (Destination) -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Destination.groups, id: \.titleKey) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: settings.t(group.titleKey))
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element) { i, d in
                                Button { select(d) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: d.symbol)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(p.accent)
                                            .frame(width: 28)
                                        Text(settings.t(d.titleKey)).font(.body.weight(.medium))
                                        Spacer()
                                        if selection == d {
                                            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(p.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("more.\(d.rawValue)")
                                if i < group.items.count - 1 { Divider().overlay(p.hairline).padding(.leading, 58) }
                            }
                        }
                        .solidCard()
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Shared screen chrome

extension View {
    /// Large title over the ambient field, with room for the floating tab bar.
    func toriScreen(title: String) -> some View {
        self
            .navigationTitle(title)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 100, for: .scrollContent)
            .modifier(ClearNavigationBackground())
            .modifier(GlassScrollEdges())
    }
}

/// iOS 26: content fades softly under the navigation bar and the floating tab bar
/// instead of being cut off by a hard edge.
private struct GlassScrollEdges: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
        }
    }
}

/// iOS 18 paints an opaque container behind a NavigationStack unless told
/// otherwise; iOS 17 is already transparent, so nothing is needed there.
private struct ClearNavigationBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
    }
}

struct LevelPicker: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        GlassSegmented(options: Level.allCases.map { ($0, $0.label) }, selection: $settings.level)
            .accessibilityIdentifier("level.picker")
    }
}
