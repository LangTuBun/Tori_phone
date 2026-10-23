import SwiftUI

struct ReviewView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(ProgressStore.self) private var progress
    @Environment(\.navigate) private var navigate
    @Environment(\.palette) private var p

    @State private var model = ReviewModel()
    @State private var group: String?
    @State private var minnaLesson: Int?
    @State private var kanjiChapter: Int?
    @State private var pos: String?
    @State private var count = 20       // 0 means "all"

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .setup: setup
                case .session: session
                case .done: done
                }
            }
            .toriScreen(title: settings.t("review.title"))
            .navigationBarTitleDisplayMode(model.phase == .setup ? .large : .inline)
            .onChange(of: settings.level) { group = nil; minnaLesson = nil; kanjiChapter = nil; pos = nil }
        }
    }

    // MARK: Pools

    private var vocabPool: [VocabEntry] {
        data.vocab(settings.level).filter {
            (group == nil || Japanese.groupKey($0) == group)
                && (minnaLesson == nil || $0.minna == minnaLesson)
                && (pos == nil || $0.pos == pos)
        }
    }

    private var kanjiPool: [KanjiPoolEntry] {
        var out: [KanjiPoolEntry] = []
        for c in data.kanjiChapters(settings.level) {
            if let kanjiChapter, c.chapter.chapter != kanjiChapter { continue }
            for g in c.chapter.groups {
                for (wi, w) in g.words.enumerated() {
                    out.append(KanjiPoolEntry(id: "\(c.src.rawValue):\(g.id)::w\(wi)", word: w, group: g, chapter: c.chapter.chapter))
                }
            }
        }
        return out
    }

    private func start(poolIDs: [String], effective: Int) {
        let cards: [ReviewCard]
        if model.mode == .vocab {
            let byID = Dictionary(uniqueKeysWithValues: vocabPool.map { ($0.id, $0) })
            cards = ReviewModel.buildQueue(ids: poolIDs, count: effective, store: progress) { c in
                byID[c.vocabId].map { .vocab(id: c.vocabId, cardType: c.cardType, entry: $0) }
            }
        } else {
            let byID = Dictionary(uniqueKeysWithValues: kanjiPool.map { ($0.id, $0) })
            cards = ReviewModel.buildQueue(ids: poolIDs, count: effective, store: progress) { c in
                byID[c.vocabId].map { .kanji(id: c.vocabId, entry: $0) }
            }
        }
        model.start(with: cards)
    }

    // MARK: Setup

    private var setup: some View {
        let isVocab = model.mode == .vocab
        let vocab = data.vocab(settings.level)
        let groups = Array(Set(vocab.map(Japanese.groupKey))).sorted(by: Japanese.compareGroupKeys)
        let minnaLessons = Array(Set(vocab.compactMap(\.minna))).sorted()
        let posList = Array(Set(vocab.map(\.pos))).sorted()
        let kanjiChapters = Array(Set(data.kanjiChapters(settings.level).map(\.chapter.chapter))).sorted()
        let poolIDs = isVocab ? vocabPool.map(\.id) : kanjiPool.map(\.id)
        let poolSize = poolIDs.count
        let due = progress.dueCards(in: poolIDs).count
        let effective = count == 0 ? poolSize : min(count, poolSize)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LevelPicker()
                GlassSegmented(options: [(ReviewModel.Mode.vocab, settings.t("review.vocabTab")),
                                         (ReviewModel.Mode.kanji, settings.t("review.kanjiTab") + " 漢字")],
                               selection: $model.mode)
                    .accessibilityIdentifier("review.mode")

                VStack(alignment: .leading, spacing: 18) {
                    if isVocab {
                        if !minnaLessons.isEmpty {
                            chipSection(settings.t("review.minnaLabel")) {
                                Chip(title: settings.t("common.all"), selected: minnaLesson == nil) { minnaLesson = nil }
                                ForEach(minnaLessons, id: \.self) { n in
                                    Chip(title: settings.t("vocab.lessonN", ["n": n]), selected: minnaLesson == n) { minnaLesson = minnaLesson == n ? nil : n }
                                }
                            }
                        }
                        chipSection(settings.t("review.chapterCategoryLabel")) {
                            Chip(title: settings.t("common.all"), selected: group == nil) { group = nil }
                            ForEach(groups, id: \.self) { g in
                                Chip(title: groupLabel(g), selected: group == g) { group = group == g ? nil : g }
                            }
                        }
                        chipSection(settings.t("review.posLabel")) {
                            Chip(title: settings.t("common.all"), selected: pos == nil) { pos = nil }
                            ForEach(posList, id: \.self) { x in
                                Chip(title: settings.t("pos.\(x)"), selected: pos == x) { pos = pos == x ? nil : x }
                            }
                        }
                    } else {
                        chipSection(settings.t("review.chapterLabel")) {
                            Chip(title: settings.t("common.all"), selected: kanjiChapter == nil) { kanjiChapter = nil }
                            ForEach(kanjiChapters, id: \.self) { c in
                                Chip(title: settings.t("common.chapterN", ["n": c]), selected: kanjiChapter == c) { kanjiChapter = kanjiChapter == c ? nil : c }
                            }
                        }
                    }

                    chipSection(settings.t("review.countLabel")) {
                        ForEach(ReviewModel.countPresets, id: \.self) { n in
                            Chip(title: "\(n) \(settings.t("review.wordsSuffix"))", selected: count == n) { count = n }
                        }
                        Chip(title: "\(settings.t("common.all")) (\(poolSize))", selected: count == 0) { count = 0 }
                    }
                }
                .padding(18)
                .glass(radius: Radius.sheet)

                VStack(alignment: .leading, spacing: 12) {
                    if poolSize == 0 {
                        Text(settings.t(isVocab ? "review.noMatchWords" : "review.noMatchKanji")).foregroundStyle(p.red).font(.subheadline.weight(.semibold))
                    } else {
                        (Text("\(due) \(settings.t("review.due"))").foregroundStyle(p.red).fontWeight(.semibold)
                         + Text(" · \(poolSize) \(settings.t(isVocab ? "review.wordsInScope" : "review.kanjiInScope")) · \(settings.t("review.willReview")) ").foregroundStyle(p.muted)
                         + Text("\(effective)").fontWeight(.semibold))
                            .font(.footnote)
                    }
                    Button { start(poolIDs: poolIDs, effective: effective) } label: {
                        Text(settings.t("review.start")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.toriPrimary)
                    .disabled(effective == 0)
                    .accessibilityIdentifier("review.start")
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
        }
    }

    private func groupLabel(_ g: String) -> String {
        g == "?" ? settings.t("vocab.unknownChapter") : Japanese.isChapterKey(g) ? settings.t("common.chapterN", ["n": g]) : g
    }

    private func chipSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }.padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Session

    private var session: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    Button { model.backToSetup() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 40, height: 40).glass(radius: 20, shadowed: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.t("review.changeFilter"))
                    .accessibilityIdentifier("review.close")
                    CapsuleProgress(value: model.progress)
                    Text("\(model.index + 1) / \(model.queue.count)")
                        .font(.footnote.weight(.semibold).monospacedDigit()).foregroundStyle(p.muted)
                        .accessibilityIdentifier("review.counter")
                }

                if let card = model.current {
                    Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { model.flipped = true } } label: {
                        CardFace(card: card, flipped: model.flipped)
                            .frame(maxWidth: .infinity, minHeight: 340)
                            .padding(22)
                            .glass(strong: true, radius: Radius.sheet)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(model.flipped)
                    .accessibilityIdentifier("review.card")
                    .id(card.id + "\(model.index)")
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

                    if model.flipped {
                        HStack(spacing: 10) {
                            ForEach(Rating.allCases, id: \.self) { r in ratingButton(r) }
                        }
                    } else {
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { model.flipped = true } } label: {
                            Text(settings.t("review.showAnswer")).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.toriPrimary)
                        .accessibilityIdentifier("review.showAnswer")
                    }
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeOut(duration: 0.25), value: model.index)
        }
    }

    private func ratingButton(_ r: Rating) -> some View {
        let (key, color): (String, Color) = switch r {
        case .again: ("ios.rating.again", p.red)
        case .hard: ("ios.rating.hard", p.yellow)
        case .good: ("ios.rating.good", p.blue)
        case .easy: ("ios.rating.easy", p.green)
        }
        return Button {
            withAnimation(.easeOut(duration: 0.25)) { model.rate(r, store: progress) }
        } label: {
            Text(settings.t(key))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(color.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(color.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("review.rate.\(r.rawValue)")
    }

    // MARK: Done

    private var done: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 8) {
                Text(settings.t("review.done")).font(.title.weight(.bold))
                Text("\(model.reviewed)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("review.doneCount")
                Text(settings.t(model.mode == .vocab ? "review.wordsReviewed" : "review.kanjiReviewed"))
                    .font(.subheadline).foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity).padding(28)
            .glass(strong: true, radius: Radius.sheet)

            HStack(spacing: 12) {
                Button { model.backToSetup() } label: { Text(settings.t("review.continueReview")).frame(maxWidth: .infinity) }
                    .buttonStyle(.toriPrimary).accessibilityIdentifier("review.continue")
                Button { model.backToSetup(); navigate(.home) } label: { Text(settings.t("review.homeBtn")).frame(maxWidth: .infinity) }
                    .buttonStyle(.toriGlass)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Card faces

private struct CardFace: View {
    let card: ReviewCard
    let flipped: Bool
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    var body: some View {
        VStack(spacing: 12) {
            switch card {
            case .vocab(_, let cardType, let entry): vocab(entry, cardType: cardType)
            case .kanji(_, let entry): kanji(entry)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .foregroundStyle(p.text)
    }

    private func prompt(_ key: String) -> some View {
        Text(settings.t(key).uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(p.muted)
    }

    @ViewBuilder
    private func vocab(_ e: VocabEntry, cardType: String) -> some View {
        if !flipped {
            prompt(cardType == "meaning" ? "review.whatMeaning" : cardType == "reading" ? "review.howRead" : "review.whatWord")
            Group {
                if cardType == "meaning" { FuriganaWord(kanji: e.kanji, kana: e.kana, size: 52) }
                else if cardType == "reading" { Text(e.kanji.isEmpty ? e.kana : e.kanji).jp(52) }
                else { Text(settings.text(e.meanings)).font(.system(size: 34, weight: .bold)).minimumScaleFactor(0.5) }
            }
            .padding(.vertical, 18)
            if cardType != "meaning" && cardType != "reading", !e.kana.isEmpty {
                Text(e.kana).jp(22, weight: .regular).foregroundStyle(p.muted)
            }
            prompt("review.tapReveal").padding(.top, 14)
        } else {
            PosTag(pos: e.pos)
            FuriganaWord(kanji: e.kanji, kana: e.kana, size: 48).padding(.vertical, 6)
            PitchAccentView(kana: e.kana, pitch: e.pitch)
            Text(settings.text(e.meanings)).font(.title2.weight(.semibold))
            if let c = e.chapter, c > 0 {
                Text(settings.t("common.chapterN", ["n": c])).font(.caption).foregroundStyle(p.muted)
            } else if let cat = e.category {
                Text(cat).font(.caption).foregroundStyle(p.muted)
            }
            if let ex = e.examples.first {
                Divider().overlay(p.hairline).padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.ja).jp(15)
                    Text(settings.text(ex.translation)).font(.caption).foregroundStyle(p.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func kanji(_ e: KanjiPoolEntry) -> some View {
        if !flipped {
            prompt("review.kanjiQuestion")
            FuriganaWord(kanji: e.word.kanji, kana: e.word.kana, size: 52).padding(.vertical, 18)
            prompt("review.tapReveal").padding(.top, 14)
        } else {
            HStack(spacing: 8) {
                if !e.word.hanviet.isEmpty {
                    Text(e.word.hanviet).font(.footnote.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(p.text.opacity(0.08)))
                }
                Text(e.word.onkun).font(.caption.weight(.semibold)).foregroundStyle(onkunTone(e.word.onkun))
            }
            FuriganaWord(kanji: e.word.kanji, kana: e.word.kana, size: 46).padding(.vertical, 6)
            Text(settings.text(e.word.meaning)).font(.title2.weight(.semibold))
            (Text(settings.t("review.sameGroup") + " ").foregroundStyle(p.muted) + Text(e.group.anchor).font(.system(size: 17, design: .serif)))
                .font(.caption)
            let siblings = e.group.words.filter { $0 != e.word }.prefix(3)
            if !siblings.isEmpty {
                Divider().overlay(p.hairline).padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: settings.t("review.siblingWords"))
                    ForEach(Array(siblings.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(w.kanji).jp(15).frame(minWidth: 56, alignment: .leading)
                            Text("\(settings.text(w.meaning)) (\(w.hanviet))").font(.caption).foregroundStyle(p.muted)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    /// src/lib/kanji.ts `onkunTone`.
    private func onkunTone(_ onkun: String) -> Color {
        if onkun.contains("Juku") || onkun.contains("Ate") { return Color(hex: 0x9333EA) }
        let on = onkun.contains("On"), kun = onkun.contains("Kun")
        if on && kun { return p.muted }
        return on ? p.blue : p.green
    }
}
