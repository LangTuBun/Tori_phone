import SwiftUI

/// Which radicals the user marked as known; persisted like the web app
/// (`tori.radicals.known`).
@MainActor @Observable
final class RadicalProgress {
    private(set) var known: Set<String>
    private let defaults: UserDefaults?
    private static let key = "tori.radicals.known"

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        known = Set(defaults?.stringArray(forKey: Self.key) ?? [])
    }

    func set(_ glyph: String, known isKnown: Bool) {
        if isKnown { known.insert(glyph) } else { known.remove(glyph) }
        defaults?.set(Array(known), forKey: Self.key)
    }
}

/// The 214 radicals as flashcards, or as a table grouped by stroke count.
struct RadicalsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(KanjiLibrary.self) private var library
    @Environment(KanjiVGStore.self) private var kanjiVG
    @Environment(\.palette) private var p

    private enum Tab: Hashable { case cards, table }

    @State private var progress = RadicalProgress()
    @State private var tab: Tab = .cards
    @State private var glyphFirst = true
    @State private var onlyUnknown = false
    @State private var order: [Int] = []
    @State private var pos = 0
    @State private var flipped = false
    @State private var picked: String?
    @State private var examples: [String: [String]] = [:]

    /// bothu.pdf draws a few radicals in their traditional form; KanjiVG uses the Japanese one.
    private static let japaneseForm = ["黑": "黒", "黃": "黄", "龍": "竜", "龜": "亀"]

    private var radicals: [Radical] { library.radicals }

    private var deck: [Int] {
        order.filter { i in i < radicals.count && (!onlyUnknown || !progress.known.contains(radicals[i].glyph)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    GlassSegmented(options: [(Tab.cards, "Flashcard"), (Tab.table, settings.l("Bảng 214 bộ", "All 214"))],
                                   selection: $tab)
                    if radicals.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if tab == .cards {
                        cards
                    } else {
                        table
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.l("Bộ thủ", "Radicals"))
            .kanjiSheet($picked)
            .task(id: radicals.count) {
                if order.isEmpty { order = Array(radicals.indices) }
                await kanjiVG.loadIfNeeded()
            }
            .task(id: kanjiVG.entries?.count) { buildExamples() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.l("Ôn tập 214 bộ thủ tiếng Nhật. Lật thẻ để xem tên Hán Việt, ý nghĩa và các chữ Hán ví dụ.",
                            "Master the 214 Japanese radicals. Flip cards to review Hán Việt names, meanings, and example kanji."))
                .font(.footnote).foregroundStyle(p.muted)
            HStack(spacing: 10) {
                Text(settings.l("Đã thuộc \(progress.known.count)/\(radicals.count)", "Known \(progress.known.count)/\(radicals.count)"))
                    .font(.caption.weight(.semibold)).foregroundStyle(p.muted)
                CapsuleProgress(value: radicals.isEmpty ? 0 : Double(progress.known.count) / Double(radicals.count))
            }
        }
    }

    // MARK: Cards

    @ViewBuilder
    private var cards: some View {
        let deck = deck
        HStack(spacing: 8) {
            Chip(title: glyphFirst ? settings.l("Chữ → Tên", "Glyph → Name") : settings.l("Tên → Chữ", "Name → Glyph"), selected: false) {
                glyphFirst.toggle(); flipped = false
            }
            Chip(title: settings.l("Xáo trộn", "Shuffle"), selected: false) {
                order.shuffle(); pos = 0; flipped = false
            }
            Chip(title: settings.l("Chỉ bộ chưa thuộc", "Unknown only"), selected: onlyUnknown) {
                onlyUnknown.toggle(); pos = 0; flipped = false
            }
        }
        if deck.isEmpty {
            Text(settings.l("Bạn đã thuộc hết 214 bộ!", "You know all 214 radicals!"))
                .font(.headline).frame(maxWidth: .infinity).padding(32).glass(radius: Radius.sheet)
        } else {
            let at = min(pos, deck.count - 1)
            let r = radicals[deck[at]]
            Button { withAnimation(.easeOut(duration: 0.2)) { flipped.toggle() } } label: { cardFace(r, at: at, total: deck.count) }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("radical.card")

            if flipped {
                let list = Array((examples[r.glyph] ?? examples[Self.japaneseForm[r.glyph] ?? ""] ?? []).prefix(8))
                if !list.isEmpty {
                    HStack(spacing: 8) {
                        Text(settings.l("Chữ ví dụ", "Examples")).font(.caption.weight(.bold)).foregroundStyle(p.muted)
                        ForEach(list, id: \.self) { ch in
                            Button { picked = ch } label: { Text(ch).jp(22).frame(width: 40, height: 40).solidCard(radius: Radius.small) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                }
            }

            HStack {
                Button { move(-1, count: deck.count) } label: { Image(systemName: "chevron.left").frame(width: 24) }
                Button { withAnimation { flipped.toggle() } } label: { Text(settings.l("Lật", "Flip")) }
                Button { move(1, count: deck.count) } label: { Image(systemName: "chevron.right").frame(width: 24) }
                Spacer(minLength: 0)
            }
            .buttonStyle(.toriGlass)
            HStack(spacing: 10) {
                Button { mark(r, known: false, count: deck.count) } label: { Text(settings.l("Chưa thuộc", "Not yet")).frame(maxWidth: .infinity) }
                    .buttonStyle(.toriGlass).accessibilityIdentifier("radical.unknown")
                Button { mark(r, known: true, count: deck.count) } label: { Text(settings.l("Đã thuộc", "Known")).frame(maxWidth: .infinity) }
                    .buttonStyle(.toriPrimary).accessibilityIdentifier("radical.known")
            }
        }
    }

    private func cardFace(_ r: Radical, at: Int, total: Int) -> some View {
        let showGlyph = glyphFirst != flipped
        return VStack(spacing: 12) {
            Text("\(at + 1) / \(total)").font(.caption2.weight(.bold).monospacedDigit()).foregroundStyle(p.muted)
            if showGlyph {
                Text(r.glyph).jp(120, weight: .bold)
            } else {
                VStack(spacing: 6) {
                    Text(r.hanviet).font(.system(size: 44, weight: .black)).minimumScaleFactor(0.6)
                    if !r.meaning.isEmpty { Text(r.meaning).font(.title3.weight(.semibold)).foregroundStyle(p.muted) }
                }
            }
            if flipped {
                HStack(spacing: 10) {
                    if !glyphFirst { Text(r.glyph).jp(36, weight: .bold) }
                    Text(settings.l("\(r.strokes) nét", "\(r.strokes) strokes")).font(.subheadline.weight(.semibold)).foregroundStyle(p.muted)
                }
            } else {
                Text(settings.l("Chạm để lật", "Tap to flip")).font(.footnote).foregroundStyle(p.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(20)
        .glass(strong: true, radius: Radius.sheet)
        .accessibilityElement(children: .combine)
    }

    private func move(_ delta: Int, count: Int) {
        flipped = false
        pos = count == 0 ? 0 : (min(pos, count - 1) + delta + count) % count
    }

    private func mark(_ r: Radical, known: Bool, count: Int) {
        progress.set(r.glyph, known: known)
        // In "unknown only" the marked card leaves the deck, so the next slides in.
        if onlyUnknown && known { flipped = false } else { move(1, count: count) }
    }

    // MARK: Table

    private var table: some View {
        let groups = Dictionary(grouping: radicals, by: \.strokes).sorted { $0.key < $1.key }
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(groups, id: \.key) { strokes, list in
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: settings.l("\(strokes) nét", "\(strokes) strokes"))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                        ForEach(list) { r in
                            Button { picked = Self.japaneseForm[r.glyph] ?? r.glyph } label: {
                                VStack(spacing: 2) {
                                    Text(r.glyph).jp(30, weight: .bold)
                                    Text(r.hanviet).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .fill(progress.known.contains(r.glyph) ? p.green.opacity(0.22) : p.card))
                                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(p.hairline, lineWidth: 1))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
    }

    /// Kanji built from each radical, for the card's example row.
    private func buildExamples() {
        guard let entries = kanjiVG.entries else { return }
        var map: [String: [String]] = [:]
        for (char, entry) in entries where library.known.contains(char) {
            for el in Set((entry.components ?? []).compactMap(\.element)) where el != char {
                map[el, default: []].append(char)
            }
        }
        examples = map.mapValues { $0.sorted() }
    }
}
