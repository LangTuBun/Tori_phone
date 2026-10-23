import SwiftUI

/// 自動詞と他動詞: intransitive / transitive verb pairs grouped by the shape
/// of the pair, with the を-vs-が explainer and the てある / ている tie-in.
struct TransitivityView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.navigate) private var navigate
    @Environment(\.palette) private var p

    @State private var content: TransitivityData?
    @State private var query = ""
    @State private var activePattern: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let content {
                        explainers
                        chapterTieIn
                        patterns(content)
                        pairList(content)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.transitivity"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("transitivity.searchPlaceholder"))
            .task { content = TransitivityData.load() }
        }
    }

    private var transColor: Color { p.blue }
    private var intransColor: Color { p.green }

    // MARK: Explainers

    private var explainers: some View {
        VStack(spacing: 12) {
            explainer(ja: "他動詞", label: settings.t("transitivity.transitive"), color: transColor,
                      body: settings.t("transitivity.transitiveExplain"),
                      sentence: ("誰かが窓を開けました。", "だれかがまどをあけました。"),
                      caption: settings.t("transitivity.exampleTransitiveCaption"))
            explainer(ja: "自動詞", label: settings.t("transitivity.intransitive"), color: intransColor,
                      body: settings.t("transitivity.intransitiveExplain"),
                      sentence: ("窓が開いています。", "まどがあいています。"),
                      caption: settings.t("transitivity.exampleIntransitiveCaption"))
        }
    }

    private func explainer(ja: String, label: String, color: Color, body: String,
                           sentence: (String, String), caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(ja).jp(20, weight: .black).foregroundStyle(color)
                Text(label).font(.caption.weight(.bold)).foregroundStyle(p.muted)
            }
            Text(body).font(.footnote).foregroundStyle(p.muted)
            sentenceBox(sentence.0, kana: sentence.1, caption: caption)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: Radius.card, shadowed: false)
    }

    private func sentenceBox(_ ja: String, kana: String?, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            FuriganaText(kanji: ja, kana: kana, size: 16, tappable: true)
            if let caption, !caption.isEmpty { Text(caption).font(.caption).foregroundStyle(p.muted) }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.text.opacity(0.05)))
    }

    // MARK: Chapter tie-in (てある vs ている vs ておく)

    private var chapterTieIn: some View {
        let related = data.grammar(settings.level).filter { $0.category == "transitive-intransitive" }
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: settings.t("transitivity.chapterTieIn"))
            tieCard("他動詞 + てある", "窓が開けてあります。", "まどがあけてあります。", settings.t("transitivity.teAruNote"))
            tieCard("自動詞 + ている", "窓が開いています。", "まどがあいています。", settings.t("transitivity.teIruNote"))
            tieCard("他動詞 + ておく", "窓を開けておきます。", "まどをあけておきます。", settings.t("transitivity.teOkuNote"))
            Text(settings.t("transitivity.chapterTieInFooter")).font(.caption).foregroundStyle(p.muted)
            if !related.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(related) { g in
                            Button { navigate(.grammar) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(g.pattern).jp(14, weight: .bold).multilineTextAlignment(.leading)
                                    Text(settings.text(g.meaning)).font(.caption).foregroundStyle(p.muted)
                                        .multilineTextAlignment(.leading).lineLimit(3)
                                }
                                .padding(12).frame(width: 220, alignment: .leading)
                                .solidCard(radius: Radius.small)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(p.yellow.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
    }

    private func tieCard(_ title: String, _ ja: String, _ kana: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).jp(14, weight: .black)
            sentenceBox(ja, kana: kana, caption: nil)
            Text(note).font(.caption).foregroundStyle(p.muted)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: Radius.small)
    }

    // MARK: Patterns

    private func patterns(_ content: TransitivityData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: settings.t("transitivity.patternsTitle"))
                if activePattern != nil {
                    Button(settings.t("transitivity.clearPatternFilter")) { activePattern = nil }
                        .font(.caption.weight(.bold)).foregroundStyle(p.red)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(content.patterns) { pt in
                    let irregular = pt.id == content.irregularPatternId
                    let active = activePattern == pt.id
                    Button { activePattern = active ? nil : pt.id } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(irregular ? settings.t("transitivity.irregular") : pt.label)
                                .font(.system(.footnote, design: .monospaced).weight(.black))
                            if !irregular {
                                HStack(spacing: 5) {
                                    Text(pt.intransitiveEnding).foregroundStyle(active ? p.accentFg.opacity(0.85) : intransColor)
                                    Text("⇄").opacity(0.5)
                                    Text(pt.transitiveEnding).foregroundStyle(active ? p.accentFg.opacity(0.85) : transColor)
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            Text(settings.text(pt.description)).font(.caption2)
                                .foregroundStyle(active ? p.accentFg.opacity(0.9) : p.muted)
                                .multilineTextAlignment(.leading).lineLimit(5)
                        }
                        .foregroundStyle(active ? p.accentFg : p.text)
                        .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(active ? AnyShapeStyle(p.accent) : AnyShapeStyle(p.card)))
                        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .strokeBorder(active ? Color.clear : p.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Pair list

    @ViewBuilder
    private func pairList(_ content: TransitivityData) -> some View {
        let pairs = content.pairs(pattern: activePattern, query: query)
        if pairs.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", message: settings.t("transitivity.noResults"))
        }
        ForEach(content.patterns) { pt in
            let inPattern = pairs.filter { $0.patternId == pt.id }
            if !inPattern.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pt.id == content.irregularPatternId ? settings.t("transitivity.irregular") : pt.label)
                            .font(.system(.subheadline, design: .monospaced).weight(.black))
                        Text(settings.t("common.wordsCount", ["n": inPattern.count])).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
                    }
                    .padding(.top, 6)
                    ForEach(inPattern) { pair in pairCard(pair) }
                }
            }
        }
    }

    private func pairCard(_ pair: VerbPair) -> some View {
        VStack(spacing: 0) {
            half(pair.transitive, tag: settings.t("transitivity.transitiveTag"), particle: "を", color: transColor)
            Divider().overlay(p.hairline)
            half(pair.intransitive, tag: settings.t("transitivity.intransitiveTag"), particle: "が", color: intransColor)
            if let note = pair.note {
                Text(settings.text(note)).font(.caption.weight(.semibold)).foregroundStyle(p.red)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.red.opacity(0.07))
            }
        }
        .solidCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func half(_ h: VerbHalf, tag: String, particle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FuriganaWord(kanji: h.kanji, kana: h.kana, size: 22, tappable: true)
                SpeakButton(text: h.kana)
                Spacer()
                Text("\(tag) \(particle)")
                    .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(color))
            }
            Text(settings.text(h.meaning)).font(.subheadline.weight(.semibold)).foregroundStyle(p.muted)
            HStack(alignment: .top) {
                sentenceBox(h.example.ja, kana: h.example.kana, caption: settings.text(h.example.translation))
                SpeakButton(text: h.example.ja)
            }
        }
        .padding(14)
    }
}
