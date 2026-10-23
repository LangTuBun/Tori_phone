import SwiftUI

struct KanjiView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    @State private var query = ""
    @State private var selected: SelectedGroup?

    private struct SelectedGroup: Identifiable {
        let group: KanjiGroup
        let chapter: Int
        let src: LevelSource
        var id: String { "\(src.rawValue):\(group.id)" }
    }

    var body: some View {
        let chapters = data.kanjiChapters(settings.level)
        let visible: [(TaggedKanjiChapter, [KanjiGroup])] = chapters
            .map { c in (c, c.chapter.groups.filter { Search.kanjiGroup($0, matches: query) }) }
            .filter { !$0.1.isEmpty }
        let total = visible.reduce(0) { $0 + $1.1.count }

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    LevelPicker()
                    Text(settings.t("kanji.groupsCount", ["n": total])).font(.caption).foregroundStyle(p.muted)

                    if visible.isEmpty {
                        EmptyStateView(symbol: "magnifyingglass", message: settings.t("kanji.noResults"))
                    }
                    ForEach(visible, id: \.0.id) { chapter, groups in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "\(chapter.src.rawValue) · " + settings.t("common.chapterN", ["n": chapter.chapter.chapter]))
                                .padding(.top, 8)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                ForEach(groups) { g in
                                    Button { selected = SelectedGroup(group: g, chapter: chapter.chapter.chapter, src: chapter.src) } label: {
                                        KanjiTile(group: g)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.kanji"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("kanji.searchPlaceholder"))
            .sheet(item: $selected) { s in
                KanjiGroupSheet(group: s.group, chapter: s.chapter)
                    .presentationDetents([.large])
                    .presentationCornerRadius(Radius.sheet)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
}

private struct KanjiTile: View {
    let group: KanjiGroup
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 12) {
            Text(group.anchor).jp(40, weight: .medium).frame(width: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.hanviet ?? "").font(.footnote.weight(.bold)).lineLimit(1)
                Text(settings.text(group.meaning)).font(.caption).foregroundStyle(p.muted).lineLimit(1)
                Text(settings.t("ios.kanji.words", ["n": group.words.count])).font(.caption2).foregroundStyle(p.muted.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .solidCard(radius: Radius.card)
        .accessibilityElement(children: .combine)
    }
}

struct KanjiGroupSheet: View {
    let group: KanjiGroup
    let chapter: Int
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(settings.t("common.chapterN", ["n": chapter])).font(.caption).foregroundStyle(p.muted)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36).background(Circle().fill(p.text.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.t("common.close"))
                }

                VStack(spacing: 8) {
                    Text(group.anchor).jp(96, weight: .medium)
                    if let h = group.hanviet { Text(h).font(.title3.weight(.bold)) }
                    Text(settings.text(group.meaning)).font(.subheadline).foregroundStyle(p.muted)
                    if !group.onyomi.isEmpty { readingRow(settings.t("ios.kanji.onyomi"), group.onyomi) }
                    if !group.kunyomi.isEmpty { readingRow(settings.t("ios.kanji.kunyomi"), group.kunyomi) }
                }
                .frame(maxWidth: .infinity).padding(20)
                .glass(strong: true, radius: Radius.sheet)

                SectionLabel(text: settings.t("kanji.relatedWords"))
                ForEach(Array(group.words.enumerated()), id: \.offset) { _, w in
                    HStack(spacing: 12) {
                        FuriganaWord(kanji: w.kanji, kana: w.kana, size: 22).frame(minWidth: 84, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.text(w.meaning)).font(.footnote)
                            Text("\(w.hanviet) · \(w.onkun)").font(.caption2).foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 0)
                        SpeakButton(text: w.kana)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .solidCard(radius: Radius.small)
                }
            }
            .padding(16)
        }
    }

    private func readingRow(_ label: String, _ items: [String]) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(items, id: \.self) { r in
                    Text(r).jp(14, weight: .medium)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(p.accent.opacity(0.12)))
                }
            }
        }
    }
}
