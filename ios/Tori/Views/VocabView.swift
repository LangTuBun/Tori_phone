import SwiftUI

struct VocabView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(ProgressStore.self) private var progress
    @Environment(\.palette) private var p

    @State private var query = ""
    @State private var group: String?
    @State private var pos: String?
    @State private var selected: VocabEntry?

    var body: some View {
        let vocab = data.vocab(settings.level)
        let groups = Array(Set(vocab.map(Japanese.groupKey))).sorted(by: Japanese.compareGroupKeys)
        let posList = Array(Set(vocab.map(\.pos))).sorted()
        let filtered = Search.vocab(vocab, query: query, group: group, pos: pos, romaji: data.romaji(of:))

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    LevelPicker().padding(.bottom, 4)

                    HStack(spacing: 8) {
                        filterMenu(title: group.map(groupLabel) ?? settings.t("ios.vocab.allGroups"), active: group != nil) {
                            Button(settings.t("common.all")) { group = nil }
                            ForEach(groups, id: \.self) { g in Button(groupLabel(g)) { group = g } }
                        }
                        filterMenu(title: pos.map { settings.t("pos.\($0)") } ?? settings.t("vocab.allPos"), active: pos != nil) {
                            Button(settings.t("common.all")) { pos = nil }
                            ForEach(posList, id: \.self) { x in Button(settings.t("pos.\(x)")) { pos = x } }
                        }
                        Spacer(minLength: 0)
                        Text(settings.t("ios.vocab.count", ["n": filtered.count]))
                            .font(.caption).foregroundStyle(p.muted)
                    }
                    .padding(.bottom, 4)

                    if filtered.isEmpty {
                        EmptyStateView(symbol: "magnifyingglass", message: settings.t("ios.noResults"))
                    }
                    ForEach(filtered) { v in
                        VocabRow(entry: v, state: progress.cards[v.id]?.state ?? .new) { selected = v }
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.vocabulary"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("vocab.searchPlaceholder"))
            .onChange(of: settings.level) { group = nil; pos = nil }
            .sheet(item: $selected) { v in
                VocabDetailView(entry: v)
                    .presentationDetents([.large])
                    .presentationCornerRadius(Radius.sheet)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private func groupLabel(_ g: String) -> String {
        g == "?" ? settings.t("vocab.unknownChapter") : Japanese.isChapterKey(g) ? settings.t("common.chapterN", ["n": g]) : g
    }

    private func filterMenu<Content: View>(title: String, active: Bool, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            HStack(spacing: 6) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(active ? p.accentFg : p.text)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(Capsule().fill(active ? AnyShapeStyle(p.accent) : AnyShapeStyle(p.card)))
            .overlay(Capsule().strokeBorder(active ? Color.clear : p.hairline, lineWidth: 1))
        }
    }
}

private struct VocabRow: View {
    let entry: VocabEntry
    let state: SRSState
    let onTap: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    FuriganaWord(kanji: entry.kanji, kana: entry.kana, size: 22)
                        .frame(minWidth: 70, alignment: .leading)
                    Text(settings.text(entry.meanings))
                        .font(.footnote).foregroundStyle(p.muted)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 4) {
                        PosTag(pos: entry.pos)
                        if state != .new { stateDot }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            SpeakButton(text: entry.kana)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(minHeight: 60)
        .solidCard(radius: Radius.small)
        .accessibilityElement(children: .contain)
    }

    private var stateDot: some View {
        let color: Color = switch state {
        case .learning: p.red
        case .review: p.yellow
        case .mastered: p.green
        case .new: p.muted
        }
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(settings.t("common.stats.\(state == .learning ? "learning" : state.rawValue)"))
                .font(.system(size: 10, weight: .medium)).foregroundStyle(p.muted)
        }
    }
}

struct VocabDetailView: View {
    let entry: VocabEntry
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PosTag(pos: entry.pos)
                    if let c = entry.chapter, c > 0 {
                        Text(settings.t("common.chapterN", ["n": c])).font(.caption).foregroundStyle(p.muted)
                    } else if let cat = entry.category {
                        Text(cat).font(.caption).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36).background(Circle().fill(p.text.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.t("common.close"))
                }

                VStack(spacing: 10) {
                    FuriganaWord(kanji: entry.kanji, kana: entry.kana, size: 52)
                    Text(settings.text(entry.meanings)).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    HStack(spacing: 14) {
                        SpeakButton(text: entry.kana)
                        PitchAccentView(kana: entry.kana, pitch: entry.pitch)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .glass(strong: true, radius: Radius.sheet)

                if !entry.examples.isEmpty {
                    SectionLabel(text: settings.t("common.examples"))
                    ForEach(Array(entry.examples.enumerated()), id: \.offset) { _, ex in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.ja).jp(17, weight: .medium)
                                if let kana = ex.kana, !kana.isEmpty {
                                    Text(kana).jp(12, weight: .regular).foregroundStyle(p.muted)
                                }
                                Text(settings.text(ex.translation)).font(.footnote).foregroundStyle(p.muted)
                            }
                            Spacer(minLength: 0)
                            SpeakButton(text: ex.ja)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .solidCard(radius: Radius.small)
                    }
                }

                let homophones = entry.homophones.compactMap { data.vocabByID[$0] }
                if !homophones.isEmpty {
                    SectionLabel(text: settings.t("vocab.homophones"))
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(homophones) { h in
                            VStack(spacing: 2) {
                                Text(h.kanji.isEmpty ? h.kana : h.kanji).jp(18)
                                Text(settings.text(h.meanings)).font(.caption2).foregroundStyle(p.muted)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8).solidCard(radius: Radius.small)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
