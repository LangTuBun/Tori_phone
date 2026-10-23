import SwiftUI

private let synonymShort: [String: (vi: String, en: String)] = [
    "wear": ("Mặc, đội, đeo", "Wear"), "play": ("Chơi", "Play"), "see-hear": ("Nhìn, nghe", "See, hear"),
    "know-understand": ("Biết, hiểu", "Know, understand"), "borrow-lend": ("Mượn, cho mượn", "Borrow, lend"),
    "teach-learn": ("Dạy, học", "Teach, learn"), "bring-take": ("Mang, dẫn đi", "Bring, take"),
    "say-speak": ("Nói", "Say, speak"), "return": ("Về, quay lại", "Return"), "think": ("Nghĩ", "Think"),
]
private let particleShort: [String: (vi: String, en: String)] = [
    "transport": ("Lên, xuống phương tiện", "Vehicles"), "feelings-relationships": ("Cảm xúc, quan hệ", "Feelings, people"),
    "motion-through-space": ("Đi qua nơi nào đó (を)", "Moving through (を)"), "phone-everyday": ("Điện thoại, sinh hoạt", "Phone, daily life"),
]

/// Fast path for the biggest "which verb?" question: pick by body part.
private let wearQuick: [(vi: String, en: String, verbs: [String])] = [
    ("Thân trên, cả người (áo, váy liền)", "Torso, whole body (shirt, dress)", ["着る"]),
    ("Chân, dưới eo (quần, váy, giày, tất)", "Legs, feet (pants, skirt, shoes, socks)", ["履く"]),
    ("Đầu (mũ, nón)", "Head (hat, cap)", ["被る"]),
    ("Mắt (kính)", "Eyes (glasses)", ["かける"]),
    ("Cổ (khăn quàng)", "Neck (scarf)", ["巻く"]),
    ("Cà vạt, thắt lưng", "Tie, belt", ["締める", "する"]),
    ("Tay, ngón tay (găng, nhẫn)", "Hands, fingers (gloves, ring)", ["はめる", "する"]),
    ("Phụ kiện (khuyên tai, khẩu trang, đồng hồ)", "Accessories (earrings, mask, watch)", ["つける", "する"]),
    ("Khoác hờ lên vai (áo ngoài)", "Draped over shoulders (outer layer)", ["羽織る"]),
    ("Cởi quần áo, giày, mũ", "Taking off clothes, shoes, hat", ["脱ぐ"]),
    ("Tháo kính, nhẫn, đồng hồ, khẩu trang", "Taking off glasses, ring, watch, mask", ["外す"]),
]

/// 使い方とニュアンス: near-synonym words, verb + particle pairings and
/// 〜て auxiliary verbs, the three recurring learner-confusion areas.
struct UsageView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.navigate) private var navigate
    @Environment(\.palette) private var p

    private enum Tab: Hashable { case synonyms, particles, auxiliary }

    @State private var content: UsageData?
    @State private var tab: Tab = .synonyms
    @State private var synonymID = ""
    @State private var particleID = ""
    @State private var query = ""
    @State private var highlighted: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let content {
                            Text(settings.t("usage.subtitle")).font(.footnote).foregroundStyle(p.muted)
                            tabPicker
                            switch tab {
                            case .synonyms: synonymsSection(content, proxy)
                            case .particles: particlesSection(content, proxy)
                            case .auxiliary: auxiliarySection(content)
                            }
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .toriScreen(title: settings.t("nav.usage"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("usage.searchPlaceholder"))
            .task {
                let d = UsageData.load()
                content = d
                synonymID = d?.synonymGroups.first?.id ?? ""
                particleID = d?.collocationGroups.first?.id ?? ""
            }
        }
    }

    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: Tabs

    private var tabPicker: some View {
        let tabs: [(Tab, String, String, String, String)] = [
            (.synonyms, "類", settings.l("Từ gần nghĩa", "Similar words"),
             settings.l("Tiếng Việt chỉ có một từ (mặc, chơi, nghe…) nhưng tiếng Nhật có nhiều từ. Chọn từ nào?",
                        "One word in English or Vietnamese, several in Japanese. Which one do you pick?"), "着る / 履く / 被る"),
            (.particles, "助", settings.l("Động từ đi với trợ từ nào", "Which particle goes with the verb"),
             settings.l("Mỗi động từ đòi một trợ từ cố định, và tiếng Việt không giúp bạn đoán được.",
                        "Each verb demands a fixed particle, and your own language will not help you guess."), "電車に乗る / 電車を降りる"),
            (.auxiliary, "補", settings.l("Thêm nghĩa cho động từ (〜て…)", "Adding meaning to a verb (〜て…)"),
             settings.l("Gắn thêm vào thể て để nói lỡ làm, thử làm, làm sẵn, đang dần thay đổi…",
                        "Added after the て-form to say: did it by accident, tried it, did it in advance, is gradually changing…"), "食べてしまう / 食べてみる"),
        ]
        return VStack(spacing: 10) {
            ForEach(tabs, id: \.0) { id, glyph, title, hint, example in
                let active = tab == id
                Button { tab = id } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(glyph).jp(20, weight: .black)
                            Text(title).font(.subheadline.weight(.black)).multilineTextAlignment(.leading)
                        }
                        Text(hint).font(.caption).opacity(active ? 0.85 : 1).foregroundStyle(active ? p.accentFg : p.muted)
                            .multilineTextAlignment(.leading)
                        Text(example).jp(12, weight: .bold)
                    }
                    .foregroundStyle(active ? p.accentFg : p.text)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
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

    private func chipRow(_ items: [(id: String, label: String, count: Int)], active: String, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.id) { it in
                    Chip(title: "\(it.label) \(it.count)", selected: active == it.id) { pick(it.id) }
                }
            }
        }
    }

    // MARK: Synonyms

    @ViewBuilder
    private func synonymsSection(_ c: UsageData, _ proxy: ScrollViewProxy) -> some View {
        if !searching {
            chipRow(c.synonymGroups.map { (id: $0.id, label: synonymShort[$0.id].map { settings.l($0.vi, $0.en) } ?? $0.glossJa, count: $0.words.count) },
                    active: synonymID) { synonymID = $0 }
        }
        let shown = c.synonyms(group: synonymID, query: query)
        if shown.isEmpty { EmptyStateView(symbol: "magnifyingglass", message: settings.t("usage.noResults")) }
        ForEach(shown) { g in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(g.glossJa).jp(18, weight: .black).foregroundStyle(p.accent)
                    Text(settings.text(g.title)).font(.footnote.weight(.semibold)).foregroundStyle(p.muted)
                    Spacer(minLength: 0)
                    Text(settings.t("common.wordsCount", ["n": g.words.count])).font(.caption.monospaced()).foregroundStyle(p.muted)
                }
                if let note = g.note {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: settings.l("Mẹo nhớ", "Rule of thumb"))
                        Text(settings.text(note)).font(.footnote.weight(.semibold))
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.yellow.opacity(0.16)))
                }
                if !searching && g.id == "wear" { wearQuickPick(proxy) }
                ForEach(g.words) { w in synonymCard(w).id("word-\(w.kanji)") }
            }
        }
    }

    private func wearQuickPick(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(settings.l("Chọn nhanh theo vị trí trên cơ thể", "Quick pick by body part"))
                .font(.subheadline.weight(.black)).padding(12)
            ForEach(wearQuick, id: \.en) { row in
                Divider().overlay(p.hairline)
                HStack(spacing: 8) {
                    Text(settings.l(row.vi, row.en)).font(.footnote.weight(.semibold))
                    Spacer(minLength: 4)
                    ForEach(row.verbs, id: \.self) { v in
                        Button { jump(to: "word-\(v)", proxy) } label: {
                            Text(v).jp(15, weight: .black).padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(p.text.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .solidCard(radius: Radius.small)
    }

    private func synonymCard(_ w: SynonymWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FuriganaWord(kanji: w.kanji, kana: w.kana, size: 22, tappable: true)
                SpeakButton(text: w.kana)
                Spacer()
                PosTag(pos: w.pos)
            }
            Text(settings.text(w.meaning)).font(.subheadline.weight(.semibold)).foregroundStyle(p.muted)
            Text(settings.text(w.nuance)).font(.footnote)
            exampleBox(w.example)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: Radius.card)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(p.accent, lineWidth: highlighted == "word-\(w.kanji)" ? 3 : 0))
    }

    private func exampleBox(_ ex: SentenceExample) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                FuriganaText(kanji: ex.ja, kana: ex.kana, size: 15, tappable: true)
                Text(settings.text(ex.translation)).font(.caption).foregroundStyle(p.muted)
            }
            Spacer(minLength: 0)
            SpeakButton(text: ex.ja)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.text.opacity(0.05)))
    }

    private func trapBox(_ text: LocalizedText) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(settings.t("usage.trapLabel").uppercased()).font(.system(size: 10, weight: .black)).tracking(0.8)
            Text(settings.text(text)).font(.caption.weight(.semibold))
        }
        .foregroundStyle(p.red)
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(p.red.opacity(0.07))
    }

    // MARK: Particles

    private let particleColor: [String: KeyPath<Palette, Color>] = ["に": \.blue, "を": \.red, "が": \.green, "と": \.yellow]

    @ViewBuilder
    private func particlesSection(_ c: UsageData, _ proxy: ScrollViewProxy) -> some View {
        if !searching {
            chipRow(c.collocationGroups.map { (id: $0.id, label: particleShort[$0.id].map { settings.l($0.vi, $0.en) } ?? settings.text($0.title), count: $0.entries.count) },
                    active: particleID) { particleID = $0 }
        }
        let shown = c.collocations(group: particleID, query: query)
        if shown.isEmpty { EmptyStateView(symbol: "magnifyingglass", message: settings.t("usage.noResults")) }
        ForEach(shown) { g in
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(g.title)).font(.headline)
                    Text(settings.text(g.description)).font(.footnote).foregroundStyle(p.muted)
                }
                ForEach(g.entries) { e in collocationCard(e, c, proxy).id(e.id) }
            }
        }
    }

    private func collocationCard(_ e: CollocationEntry, _ c: UsageData, _ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(e.pattern).jp(17, weight: .black)
                    Spacer()
                    Text(e.particle).jp(13, weight: .black).foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(particleColor[e.particle].map { p[keyPath: $0] } ?? p.muted))
                }
                HStack(spacing: 6) {
                    FuriganaWord(kanji: e.verb.kanji, kana: e.verb.kana, size: 17, tappable: true)
                    SpeakButton(text: e.verb.kana)
                    Text(settings.text(e.verb.meaning)).font(.footnote).foregroundStyle(p.muted)
                }
                Text(settings.text(e.explanation)).font(.footnote)
                exampleBox(e.example)
                if let id = e.contrastId, let other = c.collocationPattern(id: id) {
                    Button { jump(to: id, proxy) } label: {
                        Text("⇄ \(settings.t("usage.compareWith")) \(other)").font(.caption.weight(.bold)).foregroundStyle(p.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            if let trap = e.trap { trapBox(trap) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(p.accent, lineWidth: highlighted == e.id ? 3 : 0))
    }

    // MARK: Auxiliary verbs

    @ViewBuilder
    private func auxiliarySection(_ c: UsageData) -> some View {
        let shown = c.auxiliaries(query: query)
        if shown.isEmpty { EmptyStateView(symbol: "magnifyingglass", message: settings.t("usage.noResults")) }
        let grammar = Dictionary(data.grammar(settings.level).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        ForEach(shown) { a in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.pattern).jp(22, weight: .black)
                        Spacer()
                        if let col = a.colloquial { Text(col).jp(12, weight: .bold).foregroundStyle(p.muted) }
                    }
                    Text(settings.text(a.meaning)).font(.subheadline.weight(.semibold)).foregroundStyle(p.muted)
                    Text(settings.text(a.nuance)).font(.footnote)
                    ForEach(Array(a.examples.enumerated()), id: \.offset) { _, ex in exampleBox(ex) }
                    let linked = (a.grammarIds ?? []).compactMap { grammar[$0] }
                    if !linked.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(linked) { g in
                                    Button { navigate(.grammar) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(g.pattern).jp(13, weight: .bold).multilineTextAlignment(.leading)
                                            Text(settings.text(g.meaning)).font(.caption2).foregroundStyle(p.muted).lineLimit(3)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(10).frame(width: 190, alignment: .leading)
                                        .solidCard(radius: Radius.small)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(14)
                if let trap = a.trap { trapBox(trap) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .solidCard(radius: Radius.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    // MARK: Helpers

    /// Scrolls to an entry and flashes a ring around it.
    private func jump(to id: String, _ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(id, anchor: .center) }
        highlighted = id
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            if highlighted == id { highlighted = nil }
        }
    }
}
