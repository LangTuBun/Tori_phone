import SwiftUI

struct KanjiView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(\.palette) private var p

    @State private var query = ""
    @State private var selected: SelectedGroup?
    /// `TaggedKanjiChapter.id` of the chapter to show, nil for all.
    @State private var chapterFilter: String?

    fileprivate struct SelectedGroup: Identifiable {
        let group: KanjiGroup
        let chapter: Int
        let src: LevelSource
        var id: String { "\(src.rawValue):\(group.id)" }
    }

    var body: some View {
        let chapters = data.kanjiChapters(settings.level)
        let visible: [(TaggedKanjiChapter, [KanjiGroup])] = chapters
            .filter { chapterFilter == nil || $0.id == chapterFilter }
            .map { c in (c, c.chapter.groups.filter { Search.kanjiGroup($0, matches: query) }) }
            .filter { !$0.1.isEmpty }
        let total = visible.reduce(0) { $0 + $1.1.count }
        let flat = visible.flatMap { c, groups in groups.map { SelectedGroup(group: $0, chapter: c.chapter.chapter, src: c.src) } }

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    LevelPicker()
                    HStack(spacing: 10) {
                        chapterMenu(chapters)
                        Spacer(minLength: 0)
                        Text(settings.t("kanji.groupsCount", ["n": total])).font(.caption).foregroundStyle(p.muted)
                    }

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
            .onChange(of: settings.level) { chapterFilter = nil }
            .sheet(item: $selected) { s in
                KanjiGroupSheet(group: s.group, chapter: s.chapter, list: flat) { selected = $0 }
                    .presentationDetents([.large])
                    .presentationCornerRadius(Radius.sheet)
                    .toriSheetBackground()
            }
        }
    }
}

extension KanjiView {
    /// "Chương 1 (94)": a chapter and how many words it holds, like the web select.
    @ViewBuilder
    fileprivate func chapterMenu(_ chapters: [TaggedKanjiChapter]) -> some View {
        let label: String = chapterFilter.flatMap { id in chapters.first { $0.id == id } }.map { chapterTitle($0, in: chapters) }
            ?? settings.t("common.all")
        Menu {
            Button(settings.t("common.all")) { chapterFilter = nil }
            ForEach(chapters) { c in
                Button("\(chapterTitle(c, in: chapters)) (\(c.chapter.wordCount))") { chapterFilter = c.id }
            }
        } label: {
            HStack(spacing: 6) {
                Text(settings.l("Chương", "Chapter").uppercased()).font(.system(size: 10, weight: .black)).tracking(0.8).foregroundStyle(p.muted)
                Text(label).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(chapterFilter == nil ? p.text : p.accentFg)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(Capsule().fill(chapterFilter == nil ? AnyShapeStyle(p.card) : AnyShapeStyle(p.accent)))
            .overlay(Capsule().strokeBorder(chapterFilter == nil ? p.hairline : Color.clear, lineWidth: 1))
        }
        .accessibilityIdentifier("kanji.chapterFilter")
    }

    /// With both levels shown, chapter numbers repeat, so the title carries the level.
    private func chapterTitle(_ c: TaggedKanjiChapter, in all: [TaggedKanjiChapter]) -> String {
        let name = settings.t("common.chapterN", ["n": c.chapter.chapter])
        return Set(all.map(\.src)).count > 1 ? "\(c.src.rawValue) · \(name)" : name
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
    fileprivate var list: [KanjiView.SelectedGroup] = []
    fileprivate var select: (KanjiView.SelectedGroup) -> Void = { _ in }
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @Environment(KanjiVGStore.self) private var kanjiVG

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

                if let vg = kanjiVG.entry(for: group.anchor) {
                    StrokeOrderView(entry: vg).frame(maxWidth: 260).frame(maxWidth: .infinity)
                }

                SectionLabel(text: settings.t("kanji.relatedWords"))
                ForEach(Array(group.words.enumerated()), id: \.offset) { _, w in KanjiWordRow(word: w) }
            }
            .padding(16)
        }
        .id(group.id)
        .task { await kanjiVG.loadIfNeeded() }
        .safeAreaInset(edge: .bottom) {
            if let current = list.first(where: { $0.group.id == group.id }),
               let pg = list.pager(around: current, select: select) {
                DetailPager(position: pg.position, total: list.count, prev: pg.prev, next: pg.next)
            }
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
