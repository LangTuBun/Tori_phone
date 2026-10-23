import SwiftUI

struct GrammarView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(ProgressStore.self) private var progress
    @Environment(\.palette) private var p

    @State private var query = ""
    @State private var summaryCategory: GrammarCategory?

    private struct Section: Identifiable {
        let category: GrammarCategory
        let points: [GrammarPoint]
        let source: String
        var id: String { source + category.slug }
    }

    private func sections(_ level: Level) -> [Section] {
        func build(_ cats: [GrammarCategory], _ points: [GrammarPoint], _ source: String) -> [Section] {
            cats.sorted { $0.order < $1.order }.map { c in
                Section(category: c, points: Search.grammar(points.filter { $0.category == c.slug }, query: query)
                    .sorted { $0.order < $1.order }, source: source)
            }
            .filter { !$0.points.isEmpty }
        }
        var out: [Section] = []
        if level != .n4 { out += build(data.content.categoriesN5, data.content.grammarN5, "N5") }
        if level != .n5 { out += build(data.content.categoriesN4, data.content.grammarN4, "N4") }
        return out
    }

    var body: some View {
        let all = data.grammar(settings.level)
        let learned = all.filter { progress.isLearned($0.id) }.count
        let secs = sections(settings.level)

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    LevelPicker()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.t("grammar.learnedProgress", ["n": learned, "total": all.count]))
                            .font(.footnote.weight(.semibold))
                        CapsuleProgress(value: all.isEmpty ? 0 : Double(learned) / Double(all.count))
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard()

                    if secs.isEmpty { Text(settings.t("grammar.noResults")).foregroundStyle(p.muted).padding(.top, 30) }

                    ForEach(secs) { s in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(s.category.romanNumeral).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(p.accent)
                                Text(settings.text(s.category.title)).font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                if s.category.summary != nil {
                                    Button { summaryCategory = s.category } label: {
                                        Image(systemName: "text.book.closed").font(.system(size: 14, weight: .semibold))
                                            .frame(width: 34, height: 34).background(Circle().fill(p.accent.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(settings.t("grammar.chapterSummary.title"))
                                }
                            }
                            .padding(.top, 8)
                            ForEach(s.points) { g in
                                NavigationLink(value: g) { GrammarRow(point: g, learned: progress.isLearned(g.id)) }
                                    .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.grammar"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("grammar.searchPlaceholder"))
            .navigationDestination(for: GrammarPoint.self) { GrammarDetailView(point: $0) }
            .sheet(item: $summaryCategory) { c in
                ChapterSummarySheet(category: c)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(Radius.sheet)
                    .toriSheetBackground()
            }
        }
    }
}

private struct GrammarRow: View {
    let point: GrammarPoint
    let learned: Bool
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(point.pattern).jp(17).multilineTextAlignment(.leading)
                Text(settings.text(point.meaning)).font(.footnote).foregroundStyle(p.muted).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            if learned { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.green) }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(p.muted.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .solidCard(radius: Radius.small)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

struct GrammarDetailView: View {
    let point: GrammarPoint
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(ProgressStore.self) private var progress
    @Environment(\.palette) private var p

    @State private var showFurigana = true
    @State private var showRomaji = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !settings.text(point.explanation).isEmpty {
                    Text(settings.text(point.explanation)).font(.body).fixedSize(horizontal: false, vertical: true)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).solidCard()
                }

                if let rules = point.formationRules, !rules.isEmpty { formation(rules) }
                if let pr = point.pragmatics { pragmatics(pr) }
                examples
                if let notes = point.notesAndPitfalls, !notes.isEmpty { pitfalls(notes) }
                links(settings.t("grammar.related"), ids: point.relatedGrammar)
                links(settings.t("grammar.opposing"), ids: point.opposingGrammar ?? [])
            }
            .padding(16)
        }
        .toriScreen(title: "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            RubyText(point.patternRuby ?? point.pattern, size: 26, showFurigana: showFurigana)
            if let r = point.patternRomaji, !r.isEmpty {
                Text(r).font(.footnote).foregroundStyle(p.muted)
            }
            Text(settings.text(point.meaning)).font(.title3.weight(.semibold))
            if let tones = point.pragmatics?.tones, !tones.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(tones, id: \.self) { t in
                        Text(settings.t("grammar.tone.\(t)")).font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(p.accent.opacity(0.14))).foregroundStyle(p.accent)
                    }
                }
            }
            Button { progress.toggleLearned(point.id) } label: {
                let learned = progress.isLearned(point.id)
                Label(settings.t(learned ? "grammar.learned" : "grammar.markLearned"),
                      systemImage: learned ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.toriGlass)
            .accessibilityIdentifier("grammar.toggleLearned")
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .glass(strong: true, radius: Radius.sheet)
    }

    private func formation(_ rules: [ConnectionRule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("grammar.formation.title"))
            ForEach(Array(rules.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.pos).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(p.accent)
                    Text(r.label(settings.lang)).font(.subheadline)
                    Text(r.exampleStr).jp(15, weight: .medium)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
            }
        }
    }

    private func pragmatics(_ pr: Pragmatics) -> some View {
        let rows: [(String, LocalizedText?)] = [
            ("grammar.pragmatics.intent", pr.intent),
            ("grammar.pragmatics.stance", pr.speakerStance),
            ("grammar.pragmatics.nuance", pr.emotionalNuance),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("grammar.pragmatics.title"))
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.0) { key, value in
                    if let value, !settings.text(value).isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.t(key)).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
                            Text(settings.text(value)).font(.subheadline)
                        }
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
        }
    }

    @ViewBuilder
    private var examples: some View {
        let rich = point.richExamples ?? []
        if !rich.isEmpty || !point.examples.isEmpty {
            HStack {
                SectionLabel(text: settings.t("grammar.examples.richTitle"))
                Toggle(settings.t("grammar.examples.showFurigana"), isOn: $showFurigana).toggleStyle(.button).font(.caption)
                Toggle(settings.t("grammar.examples.showRomaji"), isOn: $showRomaji).toggleStyle(.button).font(.caption)
            }
            if !rich.isEmpty {
                ForEach(Array(rich.enumerated()), id: \.offset) { _, ex in
                    exampleCard(ja: ex.ja, ruby: ex.jaRuby, kana: ex.kana, romaji: ex.romaji,
                                translation: settings.text(ex.translation),
                                note: settings.text(ex.contextualExplanation),
                                badge: settings.t("grammar.examples.category.\(ex.category)"))
                }
            } else {
                ForEach(Array(point.examples.enumerated()), id: \.offset) { _, ex in
                    exampleCard(ja: ex.ja, ruby: ex.jaRuby, kana: ex.kana ?? "", romaji: "",
                                translation: settings.text(ex.translation), note: "", badge: nil)
                }
            }
        }
    }

    private func exampleCard(ja: String, ruby: String?, kana: String, romaji: String,
                             translation: String, note: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                if let badge { Text(badge).font(.system(size: 10, weight: .bold)).foregroundStyle(p.accent) }
                RubyText(ruby ?? ja, size: 18, showFurigana: showFurigana)
                if showRomaji, !romaji.isEmpty { Text(romaji).font(.caption).foregroundStyle(p.muted) }
                Text(translation).font(.footnote).foregroundStyle(p.muted)
                if !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(p.text.opacity(0.75))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            SpeakButton(text: ja)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
    }

    private func pitfalls(_ notes: [GrammarPitfall]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("grammar.notes.title"))
            ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.t("grammar.notes.type.\(n.type)")).font(.system(size: 10, weight: .bold)).foregroundStyle(p.red)
                    Text(settings.text(n.title)).font(.subheadline.weight(.semibold))
                    Text(settings.text(n.description)).font(.footnote).foregroundStyle(p.muted)
                    ForEach(Array((n.examples ?? []).enumerated()), id: \.offset) { _, e in
                        VStack(alignment: .leading, spacing: 2) {
                            Label { Text(e.incorrect).jp(14) } icon: { Image(systemName: "xmark.circle.fill").foregroundStyle(p.red) }
                            Label { Text(e.correct).jp(14) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.green) }
                            if let x = e.explanation, !settings.text(x).isEmpty {
                                Text(settings.text(x)).font(.caption).foregroundStyle(p.muted)
                            }
                        }
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
            }
        }
    }

    @ViewBuilder
    private func links(_ title: String, ids: [String]) -> some View {
        let targets = ids.compactMap { data.grammarByID[$0] }
        if !targets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: title)
                ForEach(targets) { g in
                    NavigationLink(value: g) { GrammarRow(point: g, learned: progress.isLearned(g.id)) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

// MARK: - Chapter summary

struct ChapterSummarySheet: View {
    let category: GrammarCategory
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: settings.t("grammar.chapterSummary.title"))
                Text(settings.text(category.title)).font(.title3.weight(.bold))
                if let s = category.summary {
                    Text(settings.text(s.text)).font(.body).fixedSize(horizontal: false, vertical: true)
                    if let ex = s.examples, !ex.isEmpty {
                        SectionLabel(text: settings.t("grammar.chapterSummary.examplesTitle"))
                        ForEach(Array(ex.enumerated()), id: \.offset) { _, e in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.pattern).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(p.accent)
                                Text(e.ja).jp(17, weight: .medium)
                                Text(settings.text(LocalizedText(vi: e.vi, en: e.en))).font(.footnote).foregroundStyle(p.muted)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
