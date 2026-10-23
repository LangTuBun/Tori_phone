import SwiftUI

/// Detail for any kanji (textbook anchor or not), laid out like the web
/// KanjiDrawer: coloured stroke animation, Han Viet, readings, the sound rules
/// it follows, its components and the 'chiết tự' diagram. Prev/next walks the
/// textbook order (or a list passed in), and tapping a component pushes onto a
/// history so back retraces it.
struct KanjiDetailSheet: View {
    let chars: [String]?
    @State var current: String

    @Environment(SettingsStore.self) private var settings
    @Environment(KanjiLibrary.self) private var library
    @Environment(KanjiVGStore.self) private var kanjiVG
    @Environment(\.navigate) private var navigate
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss

    @State private var history: [String] = []
    @State private var showNumbers = false
    @State private var replayToken = 0
    @State private var hovered: String?

    init(char: String, chars: [String]? = nil) {
        self.chars = chars
        _current = State(initialValue: char)
    }

    private var pages: [String] { chars ?? library.order }
    private var pageIndex: Int? { pages.firstIndex(of: current) }

    var body: some View {
        let record = library.record(current)
        let entry = kanjiVG.entry(for: current)
        let groups = GroupedComponent.group(entry?.components ?? [])
        let colored = groups.count >= 2
        let hanviet = record?.hanviet
        let radical = library.radicalNames[current]

        VStack(spacing: 0) {
            header
            Divider().overlay(p.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let entry {
                        strokeArea(entry, groups: groups, colored: colored)
                        if let hanviet { hanvietBadge(hanviet) }
                        if let radical, hanviet == nil || (record?.meaning.isEmpty ?? true) { radicalCard(radical) }
                        strokeControls(entry)
                    } else if kanjiVG.entries == nil {
                        HStack(spacing: 8) { ProgressView(); Text(settings.t("kanjiDrawer.loadingStrokes")) }
                            .font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity).padding(20)
                    } else {
                        VStack(spacing: 12) {
                            Text(current).jp(96, weight: .medium)
                            Text(settings.t("kanjiDrawer.noAnimation")).font(.footnote).foregroundStyle(p.muted)
                            if let radical { radicalCard(radical) }
                            if let hanviet { hanvietBadge(hanviet) }
                        }
                        .frame(maxWidth: .infinity).padding(20).glass(strong: true, radius: Radius.sheet)
                    }

                    readings(record)
                    rules()
                    if !groups.isEmpty { components(groups, colored: colored, hanviet: hanviet) }
                    if let group = record?.anchor?.group, !group.words.isEmpty { words(group) }
                }
                .padding(16)
            }
            .id(current)
        }
        .task { await kanjiVG.loadIfNeeded() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            if !history.isEmpty { headerButton("arrow.uturn.backward", label: settings.t("kanjiDrawer.back")) { goBack() } }
            if pageIndex != nil { headerButton("chevron.left", label: settings.t("kanjiDrawer.prev")) { step(-1) } }
            Text(current).jp(26, weight: .black).frame(minWidth: 34)
            if pageIndex != nil { headerButton("chevron.right", label: settings.t("kanjiDrawer.next")) { step(1) } }
            if let i = pageIndex {
                Text("\(i + 1)/\(pages.count)").font(.caption2.weight(.bold).monospacedDigit()).foregroundStyle(p.muted)
            }
            Spacer()
            Button { dismiss() } label: { Text("× \(settings.t("kanjiDrawer.close"))").font(.footnote.weight(.black)).foregroundStyle(p.muted) }
                .buttonStyle(.plain).accessibilityLabel(settings.t("common.close"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30) }
            .buttonStyle(.toriGlass).accessibilityLabel(label)
    }

    // MARK: Strokes

    private func strokeArea(_ entry: KanjiVGEntry, groups: [GroupedComponent], colored: Bool) -> some View {
        var colors = [Color?](repeating: nil, count: entry.strokes.count)
        if colored {
            for (gi, g) in groups.enumerated() {
                let color: Color = hovered == nil || hovered == g.element ? GroupedComponent.palette[gi % GroupedComponent.palette.count] : p.hairline
                for i in g.strokes where colors.indices.contains(i) { colors[i] = color }
            }
        }
        return StrokeOrderView(entry: entry, showNumbers: showNumbers, showsReplayButton: false,
                               strokeColors: colors, replayToken: replayToken)
            .frame(maxWidth: 360).frame(maxWidth: .infinity)
    }

    private func strokeControls(_ entry: KanjiVGEntry) -> some View {
        HStack(spacing: 8) {
            Text(settings.t("kanjiDrawer.strokeCount", ["n": entry.strokes.count]).uppercased())
                .font(.system(size: 11, weight: .black)).tracking(0.6).foregroundStyle(p.muted)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
            Button { showNumbers.toggle() } label: {
                Text("123").font(.footnote.weight(.black)).foregroundStyle(showNumbers ? p.red : p.text)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.toriGlass).accessibilityLabel(settings.t("kanjiDrawer.showNumbers"))
            .accessibilityAddTraits(showNumbers ? .isSelected : []).accessibilityIdentifier("kanji.numbers")
            Button { replayToken += 1 } label: {
                Label(settings.t("kanjiDrawer.replay"), systemImage: "arrow.counterclockwise").font(.footnote.weight(.bold))
            }
            .buttonStyle(.toriGlass).accessibilityIdentifier("kanji.replay")
        }
        .frame(maxWidth: .infinity)
    }

    private func hanvietBadge(_ hv: String) -> some View {
        HStack(spacing: 8) {
            Text(settings.t("kanjiDrawer.hanvietLabel").uppercased()).font(.system(size: 10, weight: .black)).tracking(1).foregroundStyle(p.muted)
            Text(hv).font(.title3.weight(.black))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(p.muted.opacity(0.6), lineWidth: 1))
    }

    private func radicalCard(_ r: RadicalName) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: settings.t("kanjiDrawer.radicalCard"))
            Text(r.hanviet).font(.headline.weight(.black))
            if !r.meaning.isEmpty { Text(r.meaning).font(.footnote.weight(.semibold)).foregroundStyle(p.muted) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(p.muted.opacity(0.6), lineWidth: 1))
    }

    // MARK: Readings, rules, components

    @ViewBuilder
    private func readings(_ record: KanjiRecord?) -> some View {
        if let r = record {
            let hasMeaning = !r.meaning.isEmpty
            if hasMeaning || !r.on.isEmpty || !r.kun.isEmpty || r.anchor != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if hasMeaning {
                        SectionLabel(text: settings.t("kanjiDrawer.meaning"))
                        Text(settings.text(r.meaning)).font(.subheadline.weight(.bold))
                    }
                    if !r.on.isEmpty { readingPills("On'yomi", r.on, color: p.blue) }
                    if !r.kun.isEmpty { readingPills("Kun'yomi", r.kun, color: p.green) }
                    if let a = r.anchor {
                        Text("\(a.src.rawValue) · " + settings.t("common.chapterN", ["n": a.chapter]).uppercased())
                            .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(p.muted)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func readingPills(_ title: String, _ items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10, weight: .black)).tracking(1).foregroundStyle(color)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(items, id: \.self) { r in
                    Text(r).jp(14, weight: .bold).foregroundStyle(color)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func rules() -> some View {
        let list = library.rules(for: current)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: settings.t("kanjiDrawer.rulesTitle"))
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(list) { r in
                        Button { dismiss(); navigate(.kanjiRules) } label: {
                            Text("\(r.vi) → \(r.ja)").jp(12, weight: .bold).foregroundStyle(p.yellow)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(p.yellow, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func componentLabel(_ g: GroupedComponent) -> String {
        let name = shortRadicalName(library.radicalNames[g.element]?.hanviet)
        return name.isEmpty ? (library.hanviet(g.element) ?? "") : name
    }

    private func components(_ groups: [GroupedComponent], colored: Bool, hanviet: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: settings.t("kanjiDrawer.componentsTitle"))
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(groups.enumerated()), id: \.element.element) { gi, g in
                    let color = colored ? GroupedComponent.palette[gi % GroupedComponent.palette.count] : p.muted
                    let label = componentLabel(g)
                    Button { goTo(g.element) } label: {
                        HStack(spacing: 4) {
                            Text("[ \(g.element)\(label.isEmpty ? "" : " - \(label)") ]").jp(14, weight: .bold)
                            if g.count > 1 { Text("×\(g.count)").font(.system(size: 12, weight: .black)) }
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            let single = groups.count == 1 && groups[0].element == current
            if !single {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("kanjiDrawer.graphTitle").uppercased()).font(.system(size: 10, weight: .black)).tracking(0.6).foregroundStyle(p.muted)
                    ComponentGraphView(char: current, charLabel: hanviet,
                                       nodes: groups.enumerated().map { gi, g in
                                           GraphNode(element: g.element, label: componentLabel(g), count: g.count,
                                                     color: GroupedComponent.palette[gi % GroupedComponent.palette.count])
                                       },
                                       hovered: $hovered, onSelect: goTo)
                }
                .padding(10).solidCard(radius: Radius.small)
            }
        }
    }

    // MARK: Related words

    private func words(_ group: KanjiGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: settings.t("kanji.relatedWords"))
            ForEach(Array(group.words.enumerated()), id: \.offset) { _, w in
                KanjiWordRow(word: w, onKanji: { goTo($0) })
            }
        }
    }

    // MARK: Navigation

    private func goTo(_ next: String) {
        guard next != current else { return }
        history.append(current)
        current = next
        hovered = nil
        replayToken += 1
    }

    private func goBack() {
        guard let prev = history.popLast() else { return }
        current = prev
        hovered = nil
        replayToken += 1
    }

    private func step(_ delta: Int) {
        guard let i = pageIndex, !pages.isEmpty else { return }
        history = []
        current = pages[(i + delta + pages.count) % pages.count]
        hovered = nil
        replayToken += 1
    }
}

/// A related word of a kanji group: furigana on each kanji (tap one to open it),
/// the accent diagram, how each kanji is read, meaning and Han Viet.
struct KanjiWordRow: View {
    let word: KanjiWord
    var onKanji: ((String) -> Void)?

    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                FuriganaWord(kanji: word.kanji, kana: word.kana, size: 21, tappable: true, onKanji: onKanji)
                SpeakButton(text: word.kana)
                PitchGraphView(kana: word.kana, pitch: data.pitch(kanji: word.kanji, kana: word.kana))
                Spacer(minLength: 4)
                OnkunTag(text: word.onkun)
            }
            Text("\(settings.text(word.meaning))  (\(word.hanviet))").font(.footnote).foregroundStyle(p.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: Radius.small)
    }
}

extension View {
    /// Presents `KanjiDetailSheet` for a kanji; `chars` pages through a list instead of the textbook order.
    func kanjiSheet(_ char: Binding<String?>, chars: [String]? = nil) -> some View {
        sheet(item: Binding(get: { char.wrappedValue.map(KanjiPick.init) }, set: { char.wrappedValue = $0?.char })) { pick in
            KanjiDetailSheet(char: pick.char, chars: chars)
                .presentationDetents([.large])
                .presentationCornerRadius(Radius.sheet)
                .toriSheetBackground()
        }
    }
}

struct KanjiPick: Identifiable { let char: String; var id: String { char } }
