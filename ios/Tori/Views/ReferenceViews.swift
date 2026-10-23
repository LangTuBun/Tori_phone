import SwiftUI

// MARK: - Verb forms

struct VerbFormsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    @State private var expanded: Set<String> = []

    var body: some View {
        let sets = data.verbForms(settings.level)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    LevelPicker()
                    ForEach(sets, id: \.label) { set in
                        if sets.count > 1 { SectionLabel(text: set.label).padding(.top, 6) }
                        if let groups = set.data.groups, !groups.isEmpty { groupsSection(groups) }
                        SectionLabel(text: settings.t("ios.verbForms.forms"))
                        ForEach(set.data.forms) { f in formCard(f, key: "\(set.label)-\(f.id)") }
                        if let cheat = set.data.cheatSheet { cheatSheet(cheat) }
                        if let ex = set.data.keyExceptions, !ex.isEmpty {
                            SectionLabel(text: settings.t("verbForms.keyExceptions"))
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(ex.enumerated()), id: \.offset) { _, e in
                                    Label { Text(settings.text(e)).font(.footnote) } icon: {
                                        Image(systemName: "exclamationmark.circle").foregroundStyle(p.red)
                                    }
                                }
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.verbForms"))
        }
    }

    private func groupsSection(_ groups: [VerbGroup]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: settings.t("ios.verbForms.groups"))
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.text(g.name)).font(.subheadline.weight(.bold))
                    Text(settings.text(g.note)).font(.footnote).foregroundStyle(p.muted)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Array(g.sample.enumerated()), id: \.offset) { _, s in
                            VStack(spacing: 1) {
                                RubyText(s.masuRuby ?? s.masu, size: 15)
                                Text(settings.text(s.meaning)).font(.system(size: 10)).foregroundStyle(p.muted)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.text.opacity(0.05)))
                        }
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).solidCard(radius: Radius.small)
            }
        }
    }

    private func formCard(_ f: VerbForm, key: String) -> some View {
        let open = expanded.contains(key)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if open { expanded.remove(key) } else { expanded.insert(key) }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.titleJa).jp(18)
                        Text(settings.text(f.title)).font(.footnote).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(p.muted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(14).contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 12) {
                    Text(settings.text(f.meaning)).font(.footnote)
                    if !f.rules.isEmpty {
                        SectionLabel(text: settings.t("ios.verbForms.rules"))
                        ForEach(Array(f.rules.enumerated()), id: \.offset) { _, r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(groupName(r.group)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(p.accent)
                                Text(settings.text(r.rule)).font(.subheadline)
                                let note = settings.text(r.note)
                                if !note.isEmpty { Text(note).font(.caption).foregroundStyle(p.muted) }
                            }
                        }
                    }
                    if !f.examples.isEmpty {
                        SectionLabel(text: settings.t("ios.verbForms.examples"))
                        ForEach(Array(f.examples.enumerated()), id: \.offset) { _, e in
                            HStack(spacing: 8) {
                                RubyText(e.masuRuby ?? e.masu, size: 15)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(p.muted)
                                RubyText(e.resultRuby ?? e.result, size: 15)
                                if let neg = e.resultNeg, !neg.isEmpty {
                                    Text("/").foregroundStyle(p.muted)
                                    RubyText(e.resultNegRuby ?? neg, size: 15)
                                }
                            }
                        }
                    }
                    if !f.exceptions.isEmpty {
                        SectionLabel(text: settings.t("verbForms.exceptions"))
                        ForEach(Array(f.exceptions.enumerated()), id: \.offset) { _, e in
                            Text("• " + settings.text(e)).font(.footnote)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .solidCard(radius: Radius.small)
    }

    private func groupName(_ id: FlexID) -> String {
        Int(id.raw).map { settings.t("verbForms.groupN", ["n": $0]) } ?? id.raw.uppercased()
    }

    private func cheatSheet(_ c: CheatSheet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("verbForms.cheatSheet"))
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        ForEach(Array(c.headers.enumerated()), id: \.offset) { _, h in
                            Text(settings.text(h)).font(.caption.weight(.bold)).foregroundStyle(p.accent)
                        }
                    }
                    Divider().overlay(p.hairline)
                    ForEach(Array(c.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(settings.text(cell)).jp(14, weight: .regular).fixedSize()
                            }
                        }
                    }
                }
                .padding(14)
            }
            .solidCard(radius: Radius.small)
        }
    }
}

// MARK: - Counters

struct CountersView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    @State private var categoryID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let counters = data.content.counters {
                    let selected = counters.categories.first { $0.id == categoryID } ?? counters.categories.first
                    VStack(alignment: .leading, spacing: 14) {
                        Text(settings.text(counters.intro)).font(.footnote).foregroundStyle(p.muted)
                        Text(settings.t("ios.counters.n5only")).font(.caption.weight(.semibold)).foregroundStyle(p.accent)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(counters.categories) { c in
                                    Chip(title: settings.text(c.shortTitle), selected: c.id == selected?.id) { categoryID = c.id }
                                }
                            }
                        }
                        .scrollClipDisabled()

                        if let c = selected { table(c) }

                        if !counters.bigNumberExamples.isEmpty {
                            SectionLabel(text: settings.t("counters.bigExamplesTitle")).padding(.top, 8)
                            ForEach(Array(counters.bigNumberExamples.enumerated()), id: \.offset) { _, e in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.kanji).jp(18)
                                        Text(e.kana).jp(12, weight: .regular).foregroundStyle(p.muted)
                                    }
                                    Spacer()
                                    Text(settings.text(e.meaning)).font(.footnote).foregroundStyle(p.muted)
                                }
                                .padding(14).solidCard(radius: Radius.small)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .toriScreen(title: settings.t("nav.counters"))
        }
    }

    private func table(_ c: CounterCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.text(c.title)).font(.headline)
            if let u = c.usage { Text(settings.text(u)).font(.footnote).foregroundStyle(p.muted) }
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        ForEach(c.columns, id: \.self) { col in
                            Text(settings.t("counters.columns.\(col)")).font(.caption.weight(.bold)).foregroundStyle(p.accent)
                        }
                    }
                    Divider().overlay(p.hairline)
                    ForEach(Array(c.rows.enumerated()), id: \.offset) { _, r in
                        GridRow {
                            ForEach(c.columns, id: \.self) { col in
                                cell(r, col).foregroundStyle(r.isException == true ? p.red : p.text)
                            }
                        }
                    }
                }
                .padding(14)
            }
            .solidCard(radius: Radius.small)
            if let f = c.footnote {
                Text(settings.text(f)).font(.caption).foregroundStyle(p.muted)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func cell(_ r: CounterRow, _ col: String) -> some View {
        switch col {
        case "number": Text(r.number).font(.footnote.weight(.semibold)).fixedSize()
        case "kanji": Text(r.kanji).jp(16).fixedSize()
        case "kana": Text(r.kana).jp(14, weight: .regular).fixedSize()
        case "romaji": Text(r.romaji ?? "").font(.footnote).fixedSize()
        case "meaning": Text(settings.text(r.meaning)).font(.footnote).frame(maxWidth: 200, alignment: .leading)
        default: Text(settings.text(r.note)).font(.caption).foregroundStyle(p.muted).frame(maxWidth: 220, alignment: .leading)
        }
    }
}

// MARK: - Homophones

struct HomophonesView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    @State private var selected: HomophoneGroup?
    @State private var challenge = false

    var body: some View {
        let groups = data.content.homophones.sorted { $0.difficultyScore > $1.difficultyScore }
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Text(settings.t("homophones.subtitle")).font(.footnote).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { challenge = true } label: {
                        Label(settings.t("homophones.randomChallenge"), systemImage: "dice").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.toriPrimary)
                    .accessibilityIdentifier("homophones.challenge")

                    ForEach(groups) { g in
                        Button { selected = g } label: {
                            HStack(spacing: 12) {
                                Text(g.reading).jp(22)
                                Spacer(minLength: 8)
                                Text(g.words.map(\.kanji).joined(separator: " · ")).jp(16, weight: .regular).foregroundStyle(p.muted).lineLimit(1)
                                Text(settings.t("homophones.wordsCount", ["n": g.words.count])).font(.caption2).foregroundStyle(p.muted)
                            }
                            .padding(14).frame(maxWidth: .infinity, minHeight: 56).solidCard(radius: Radius.small)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("homophones.title"))
            .sheet(item: $selected) { g in
                HomophoneSheet(group: g, hidden: false, next: nil)
                    .presentationDetents([.medium, .large]).presentationCornerRadius(Radius.sheet)
                    .toriSheetBackground()
            }
            .sheet(isPresented: $challenge) {
                ChallengeSheet(groups: groups)
                    .presentationDetents([.medium, .large]).presentationCornerRadius(Radius.sheet)
                    .toriSheetBackground()
            }
        }
    }
}

private struct ChallengeSheet: View {
    let groups: [HomophoneGroup]
    @State private var current: HomophoneGroup?
    @State private var round = 0

    var body: some View {
        if let current {
            HomophoneSheet(group: current, hidden: true) {
                self.current = groups.randomElement()
                round += 1
            }
            .id(round)
        } else {
            Color.clear.onAppear { current = groups.randomElement() }
        }
    }
}

private struct HomophoneSheet: View {
    let group: HomophoneGroup
    let hidden: Bool
    let next: (() -> Void)?

    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p
    @State private var revealed = false

    var body: some View {
        let show = !hidden || revealed
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(group.reading).jp(48)
                    SpeakButton(text: group.reading)
                    Text(settings.t("homophones.wordsShareSound", ["n": group.words.count]))
                        .font(.footnote).foregroundStyle(p.muted)
                }
                .frame(maxWidth: .infinity).padding(20).glass(strong: true, radius: Radius.sheet)

                if show {
                    ForEach(Array(group.words.enumerated()), id: \.offset) { _, w in
                        HStack {
                            Text(w.kanji).jp(26)
                            Spacer()
                            Text(settings.text(w.meaning)).font(.subheadline).foregroundStyle(p.muted)
                        }
                        .padding(14).solidCard(radius: Radius.small)
                    }
                } else {
                    Button { withAnimation { revealed = true } } label: {
                        Text(settings.t("homophones.revealAll")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.toriPrimary)
                    .accessibilityIdentifier("homophones.reveal")
                }

                if let next, show {
                    Button(action: next) { Text(settings.t("homophones.nextGroup")).frame(maxWidth: .infinity) }
                        .buttonStyle(.toriGlass)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(Speaker.self) private var speaker
    @Environment(\.palette) private var p
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    card(settings.t("settings.languageTitle")) {
                        GlassSegmented(options: Lang.allCases.map { ($0, $0.label) }, selection: $settings.lang)
                            .accessibilityIdentifier("settings.lang")
                    }
                    card(settings.t("settings.levelTitle")) {
                        LevelPicker()
                        Text(settings.t("settings.levelDescription")).font(.caption).foregroundStyle(p.muted)
                    }
                    card(settings.t("vocab.book")) {
                        BookPicker()
                        Text(settings.l("Mặc định là các chương của Tori. Chọn Minna no Nihongo để học theo từng bài của giáo trình đó; từ chỉ có trong Minna chỉ hiện ở đây.",
                                        "Tori's own chapters by default. Pick Minna no Nihongo to study by that textbook's lessons; words that exist only in Minna show up there alone."))
                            .font(.caption).foregroundStyle(p.muted)
                    }
                    card(settings.t("ios.settings.theme")) {
                        GlassSegmented(options: [(BackgroundMode.gradient, "Gradient"),
                                                 (BackgroundMode.scene, settings.l("Hình nền", "Background"))],
                                       selection: Binding(get: { settings.backgroundMode }, set: { settings.backgroundMode = $0 }))
                            .accessibilityIdentifier("settings.backgroundMode")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(settings.backgroundMode == .scene ? ThemeID.scenes : ThemeID.gradients) { id in themeThumb(id) }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollClipDisabled()
                        Text(settings.backgroundMode == .scene
                             ? settings.l("Hình nền có chi tiết để kính khúc xạ. Chọn một cảnh bạn thích.", "Backgrounds give the glass something to refract. Pick a scene you like.")
                             : settings.t("ios.settings.themeDescription"))
                            .font(.caption).foregroundStyle(p.muted)
                    }
                    card(settings.t("settings.voiceTitle")) {
                        HStack {
                            Text(speaker.voiceName.map { settings.t("settings.voiceStatusFound", ["name": $0]) }
                                 ?? settings.t("settings.voiceStatusDefault")).font(.footnote)
                            Spacer()
                            SpeakButton(text: "こんにちは、とりです。")
                        }
                    }
                    card(settings.t("ios.settings.data")) {
                        Text(settings.t("ios.settings.reviewed", ["n": progress.totalReviewed])).font(.footnote).foregroundStyle(p.muted)
                        Button(role: .destructive) { confirmReset = true } label: {
                            Text(settings.t("ios.settings.resetProgress")).foregroundStyle(p.red).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.toriGlass)
                        .accessibilityIdentifier("settings.reset")
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("ios.settings.title"))
            .confirmationDialog(settings.t("ios.settings.resetConfirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(settings.t("ios.settings.resetProgress"), role: .destructive) { progress.reset() }
                Button(settings.t("ios.settings.cancel"), role: .cancel) {}
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: Radius.card, shadowed: false)
    }

    /// One gallery card: the background itself, with a sample glass chip on it.
    private func themeThumb(_ id: ThemeID) -> some View {
        let on = settings.theme == id
        let pal = Palette.make(id)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button { withAnimation(.easeOut(duration: 0.25)) { settings.theme = id } } label: {
            VStack(spacing: 8) {
                ThemePreview(theme: id)
                    .frame(width: 112, height: 196)
                    .overlay(alignment: .bottom) {
                        Text("Aa").font(.headline).foregroundStyle(pal.text)
                            .frame(width: 84, height: 40)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(pal.edge, lineWidth: 1))
                            .padding(.bottom, 14)
                    }
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(on ? p.accent : p.hairline, lineWidth: on ? 3 : 1))
                Text(settings.t("ios.theme.\(id.rawValue)")).font(.caption.weight(on ? .bold : .medium))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.theme.\(id.rawValue)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
