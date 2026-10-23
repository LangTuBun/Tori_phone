import SwiftUI

private struct StrokeRule: Identifiable {
    let id: String
    let ja: String
    let vi: String
    let en: String
    let noteVi: String
    let noteEn: String
    let examples: [String]
}

/// Examples are drawn with KanjiVG's own stroke order (numbers on), so each
/// card demonstrates its rule with the same data the rest of the app animates.
private let strokeRules: [StrokeRule] = [
    .init(id: "top-bottom", ja: "上から下へ", vi: "Từ trên xuống dưới", en: "Top to bottom",
          noteVi: "Các phần xếp chồng theo chiều dọc thì viết phần trên trước.", noteEn: "When parts are stacked vertically, write the upper part first.",
          examples: ["三", "言", "思"]),
    .init(id: "left-right", ja: "左から右へ", vi: "Từ trái sang phải", en: "Left to right",
          noteVi: "Các phần xếp ngang thì viết phần bên trái trước.", noteEn: "When parts sit side by side, write the left part first.",
          examples: ["川", "休", "明"]),
    .init(id: "horizontal-first", ja: "横画が先", vi: "Nét ngang trước nét sổ", en: "Horizontal before vertical",
          noteVi: "Khi nét ngang và nét sổ cắt nhau, viết nét ngang trước.", noteEn: "When a horizontal and a vertical stroke cross, write the horizontal first.",
          examples: ["十", "土"]),
    .init(id: "center-first", ja: "中が先", vi: "Nét giữa trước hai bên", en: "Center before the sides",
          noteVi: "Chữ đối xứng có nét giữa thì viết nét giữa trước, rồi trái, rồi phải.", noteEn: "In symmetric characters, write the center stroke first, then left, then right.",
          examples: ["小", "水", "山"]),
    .init(id: "outside-first", ja: "外側が先", vi: "Khung ngoài trước, nét đóng viết sau cùng", en: "Outside before inside",
          noteVi: "Khung bao quanh viết trước, nét bên trong sau, rồi đóng đáy khung.", noteEn: "Write the enclosing frame first, then what's inside, then close the bottom.",
          examples: ["日", "月", "国"]),
    .init(id: "left-falling-first", ja: "左払いが先", vi: "Nét phẩy trái trước nét mác phải", en: "Left-falling before right-falling",
          noteVi: "Khi nét phẩy (丿) và nét mác (乀) đối xứng nhau, viết nét phẩy trước.", noteEn: "When a left-falling and a right-falling stroke meet, write the left-falling stroke first.",
          examples: ["人", "文", "父"]),
    .init(id: "vertical-last", ja: "貫く縦画は最後", vi: "Nét sổ xuyên qua viết sau cùng", en: "Piercing vertical stroke last",
          noteVi: "Nét sổ đi xuyên qua các nét khác thì viết cuối cùng.", noteEn: "A vertical stroke that runs through the other strokes is written last.",
          examples: ["中", "車", "申"]),
    .init(id: "horizontal-last", ja: "貫く横画は最後", vi: "Nét ngang xuyên qua viết sau cùng", en: "Piercing horizontal stroke last",
          noteVi: "Nét ngang đi xuyên qua các nét khác thì viết cuối cùng.", noteEn: "A horizontal stroke that runs through the other strokes is written last.",
          examples: ["女", "母"]),
    .init(id: "dot-last", ja: "右上の点は最後", vi: "Chấm bên phải viết sau cùng", en: "Dot at upper right last",
          noteVi: "Chấm nhỏ ở góc phải trên của chữ viết cuối cùng.", noteEn: "A small dot at the upper right of a character is written last.",
          examples: ["犬", "状"]),
    .init(id: "left-falling-vs-horizontal", ja: "左払いと横画", vi: "Nét phẩy cắt nét ngang", en: "Left-falling vs. horizontal",
          noteVi: "Nét ngang dài hơn → viết nét ngang trước (左, 有). Nét phẩy dài hơn → viết nét phẩy trước (右).", noteEn: "Longer horizontal → write it first (左, 有). Longer left-falling stroke → write it first (右).",
          examples: ["左", "右", "有"]),
    .init(id: "nyo-last", ja: "にょう（辶・廴）は最後", vi: "Bộ bao đáy (辶, 廴) viết sau cùng", en: "Wrap-around radicals (辶, 廴) last",
          noteVi: "Phần bên trong viết trước, bộ 辶 / 廴 ở dưới và bên trái viết sau cùng.", noteEn: "Write the contents first; the wrap-around 辶 / 廴 radical comes last.",
          examples: ["道", "近", "建"]),
]

struct KanjiRulesView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(KanjiVGStore.self) private var kanjiVG
    @Environment(\.palette) private var p

    private enum Tab: Hashable { case stroke, sound }

    @State private var tab: Tab = .stroke
    @State private var rules: OnyomiRules?
    @State private var picked: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassSegmented(options: [(Tab.stroke, settings.l("Thuận bút", "Stroke order")),
                                             (Tab.sound, settings.l("Chuyển âm", "Sound rules"))],
                                   selection: $tab)
                    switch tab {
                    case .stroke: strokeSection
                    case .sound: soundSection
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.rules"))
            .kanjiSheet($picked)
            .task {
                rules = OnyomiRules.load()
                await kanjiVG.loadIfNeeded()
            }
        }
    }

    // MARK: Stroke order

    private var strokeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.l("Chạm vào từng chữ để xem lại hoạt hình. Số đỏ là thứ tự nét.",
                            "Tap a character to replay its animation. Red numbers show the stroke order."))
                .font(.footnote).foregroundStyle(p.muted)
            ForEach(Array(strokeRules.enumerated()), id: \.element.id) { i, rule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i + 1)").font(.title2.weight(.black)).foregroundStyle(p.accent)
                        Text(rule.ja).jp(17, weight: .bold)
                        Text(settings.l(rule.vi, rule.en)).font(.subheadline.weight(.bold))
                    }
                    Text(settings.l(rule.noteVi, rule.noteEn)).font(.footnote).foregroundStyle(p.muted)
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(rule.examples, id: \.self) { ch in
                            if let vg = kanjiVG.entry(for: ch) {
                                VStack(spacing: 4) {
                                    StrokeOrderView(entry: vg, strokeDuration: 0.45, showsReplayButton: false)
                                    Text(ch).jp(15, weight: .bold)
                                }
                                .frame(maxWidth: 110)
                            }
                        }
                        if kanjiVG.entries == nil { ProgressView() }
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .glass(radius: Radius.card, shadowed: false)
            }
        }
    }

    // MARK: Sound rules

    @ViewBuilder
    private var soundSection: some View {
        if let rules {
            Text(settings.l("Âm Hán Việt và âm On đều bắt nguồn từ tiếng Hán cổ nên có quy luật tương ứng. Biết âm Hán Việt, bạn có thể đoán khá chuẩn âm On. Đây là xu hướng, không phải luật tuyệt đối; tỉ lệ dưới đây được đo trên chính các chữ Hán trong app.",
                            "Hán Việt and on'yomi both descend from Middle Chinese, so they correspond regularly. Knowing the Hán Việt lets you predict the on'yomi quite reliably. These are tendencies, not laws; the rates below are measured on the kanji in this app."))
                .font(.footnote).foregroundStyle(p.muted)
            ruleGroup(settings.l("Theo phụ âm cuối", "By final consonant"), rules.finals)
            ruleGroup(settings.l("Theo phụ âm đầu", "By initial consonant"), rules.initials)
            OnyomiQuizView(rules: rules)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        }
    }

    private func ruleGroup(_ title: String, _ list: [OnyomiRule]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title).padding(.top, 6)
            ForEach(list) { rule in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(rule.vi).font(.headline).padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(p.yellow.opacity(0.3)))
                        Image(systemName: "arrow.right").font(.caption.weight(.bold))
                        Text(rule.ja).jp(17, weight: .bold).padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(p.blue.opacity(0.2)))
                    }
                    HStack(spacing: 10) {
                        CapsuleProgress(value: Double(rule.rate) / 100)
                        Text("\(rule.rate)% (\(rule.matched)/\(rule.total))").font(.caption.weight(.bold).monospacedDigit())
                    }
                    chips(rule.examples)
                    if !rule.exceptions.isEmpty {
                        SectionLabel(text: settings.l("Ngoại lệ", "Exceptions"))
                        chips(rule.exceptions)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .solidCard(radius: Radius.card)
            }
        }
    }

    private func chips(_ list: [OnyomiExample]) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(list, id: \.kanji) { ex in
                Button { picked = ex.kanji } label: {
                    HStack(spacing: 6) {
                        Text(ex.kanji).jp(19, weight: .bold)
                        Text(ex.hanviet).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
                        Text(ex.on.joined(separator: "・")).jp(12, weight: .semibold).foregroundStyle(p.blue)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(p.text.opacity(0.05)))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// "Han Viet Khoa (科) -> which on'yomi?" drill, drawn from the rule examples.
private struct OnyomiQuizView: View {
    let rules: OnyomiRules
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    @State private var question: OnyomiRules.Question?
    @State private var picked: String?
    @State private var right = 0
    @State private var total = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: settings.l("Bài tập áp dụng", "Practice"))
                Text("\(settings.l("Đúng", "Correct")) \(right)/\(total)").font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(p.muted)
            }
            if let q = question {
                VStack(alignment: .leading, spacing: 14) {
                    (Text("\(settings.l("Âm Hán Việt", "Hán Việt")) ") + Text(q.example.hanviet).foregroundColor(p.red).bold()
                        + Text(" (\(q.example.kanji)) → \(settings.l("On'yomi nào?", "Which on'yomi?"))"))
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(q.options, id: \.self) { opt in
                            Button { pick(opt, q) } label: {
                                Text(KanjiText.katakanaToHiragana(opt)).jp(20, weight: .bold)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(tint(opt, q)))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(picked != nil)
                            .accessibilityIdentifier("onyomi.option")
                        }
                    }
                    if let picked {
                        HStack {
                            Text(q.example.on.contains(picked) ? settings.l("Chính xác!", "Correct!") : settings.l("Chưa đúng.", "Not quite."))
                                .font(.subheadline.weight(.bold))
                            Text("\(q.example.kanji): " + q.example.on.map(KanjiText.katakanaToHiragana).joined(separator: " / "))
                                .font(.subheadline).foregroundStyle(p.muted)
                            Spacer()
                            Button { next() } label: { Text("\(settings.l("Câu tiếp", "Next")) →") }
                                .buttonStyle(.toriPrimary).accessibilityIdentifier("onyomi.next")
                        }
                    }
                }
                .padding(14).glass(radius: Radius.card, shadowed: false)
            }
        }
        .padding(.top, 14)
        .task { if question == nil { next() } }
    }

    private func tint(_ opt: String, _ q: OnyomiRules.Question) -> Color {
        guard let picked else { return p.card }
        if q.example.on.contains(opt) { return p.green.opacity(0.4) }
        return opt == picked ? p.red.opacity(0.3) : p.card.opacity(0.5)
    }

    private func pick(_ opt: String, _ q: OnyomiRules.Question) {
        guard picked == nil else { return }
        picked = opt
        total += 1
        if q.example.on.contains(opt) { right += 1 }
    }

    private func next() {
        var rng = SystemRandomNumberGenerator()
        question = rules.makeQuestion(using: &rng)
        picked = nil
    }
}
