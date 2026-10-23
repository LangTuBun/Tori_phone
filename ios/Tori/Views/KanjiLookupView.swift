import SwiftUI

/// 字引: find a kanji by the character, Han Viet (with or without tones),
/// kana reading or meaning, or by drawing it.
struct KanjiLookupView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(KanjiLibrary.self) private var library
    @Environment(KanjiVGStore.self) private var kanjiVG
    @Environment(\.palette) private var p

    private enum Mode: Hashable { case search, draw }

    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var results: [KanjiRecord] = []
    @State private var strokes: [KanjiRecognizer.Stroke] = []
    @State private var candidates: [KanjiRecognizer.Candidate]?
    @State private var guesses: [String] = []
    @State private var picked: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(settings.l("Tìm bằng chữ Hán, âm Hán Việt (gõ có hoặc không dấu: “minh”, “đại”), cách đọc kana hoặc nghĩa; hoặc vẽ tay chữ bạn đang thấy.",
                                    "Search by kanji, Hán Việt (with or without tones), kana reading or meaning, or draw the character you're looking at."))
                        .font(.footnote).foregroundStyle(p.muted)
                    GlassSegmented(options: [(Mode.search, settings.l("Tìm kiếm", "Search")), (Mode.draw, settings.l("Vẽ tay", "Draw"))],
                                   selection: $mode)
                    switch mode {
                    case .search: searchMode
                    case .draw: drawMode
                    }
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.lookup"))
            .kanjiSheet($picked, chars: mode == .search ? results.map(\.char) : guesses)
            .task(id: "\(query)|\(library.ready)") {
                results = library.ready ? library.search(query) : []
            }
            .task(id: "\(library.ready)|\(kanjiVG.entries?.count ?? 0)") { await buildCandidates() }
            .task(id: strokes.count) { guesses = candidates.map { KanjiRecognizer.recognize(strokes, candidates: $0) } ?? [] }
            .task { await kanjiVG.loadIfNeeded() }
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    // MARK: Search

    private var searchMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(settings.l("Kanji, Hán Việt (minh), kana hoặc nghĩa…", "Kanji, Hán Việt (minh), kana or meaning…"), text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(.horizontal, 14).frame(minHeight: 46)
                .glass(radius: 23, shadowed: false)
                .accessibilityIdentifier("lookup.field")
            Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                 ? settings.l("\(library.records.count) chữ Hán trong app", "\(library.records.count) kanji in the app")
                 : settings.l("\(results.count) kết quả", "\(results.count) results"))
                .font(.caption.weight(.semibold)).foregroundStyle(p.muted)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(results) { r in
                    Button { picked = r.char } label: { tile(r) }.buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func tile(_ r: KanjiRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(r.char).jp(32, weight: .black)
                Spacer(minLength: 4)
                if let hv = r.hanviet { Text(hv).font(.footnote.weight(.black)).lineLimit(1) }
            }
            Text(settings.text(r.meaning)).font(.caption).foregroundStyle(p.muted).lineLimit(2)
                .frame(minHeight: 30, alignment: .topLeading)
            if !r.on.isEmpty {
                Text(r.on.prefix(3).joined(separator: "・")).jp(11, weight: .semibold).foregroundStyle(p.blue).lineLimit(1)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: Radius.small)
    }

    // MARK: Draw

    private var drawMode: some View {
        VStack(alignment: .leading, spacing: 12) {
            DrawPad(strokes: $strokes).frame(maxWidth: 380)
            HStack(spacing: 10) {
                Button { _ = strokes.popLast() } label: { Text(settings.l("Hoàn tác nét", "Undo stroke")) }
                    .disabled(strokes.isEmpty).accessibilityIdentifier("lookup.undo")
                Button { strokes = [] } label: { Text(settings.l("Xóa hết", "Clear")) }
                    .disabled(strokes.isEmpty).accessibilityIdentifier("lookup.clear")
                Text(settings.l("\(strokes.count) nét", "\(strokes.count) strokes")).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
            }
            .buttonStyle(.toriGlass)
            Text(settings.l("Vẽ đúng thứ tự nét sẽ cho kết quả chính xác nhất. Chỉ tìm được các chữ có sẵn dữ liệu nét trong app.",
                            "Drawing the strokes in the correct order works best. Only kanji with stroke data in the app can be found."))
                .font(.caption).foregroundStyle(p.muted)
            if candidates == nil {
                HStack(spacing: 8) { ProgressView(); Text(settings.l("Đang tải dữ liệu nét…", "Loading stroke data…")).font(.footnote) }
                    .foregroundStyle(p.muted)
            } else if strokes.isEmpty {
                Text(settings.l("Hãy vẽ một chữ vào khung.", "Draw a character in the box.")).font(.footnote).foregroundStyle(p.muted)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(guesses, id: \.self) { ch in
                    Button { picked = ch } label: {
                        if let r = library.record(ch) { tile(r) }
                        else { Text(ch).jp(32, weight: .black).frame(maxWidth: .infinity, minHeight: 72).solidCard(radius: Radius.small) }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    /// Feature maps for ~1100 glyphs, built once off the main thread as soon as
    /// the stroke data is in (not on the first stroke of the pad).
    private func buildCandidates() async {
        guard candidates == nil, library.ready, let entries = kanjiVG.entries else { return }
        let chars = Set(library.records.map(\.char))
        candidates = await Task.detached(priority: .userInitiated) {
            KanjiRecognizer.makeCandidates(entries, chars: chars)
        }.value
    }
}
