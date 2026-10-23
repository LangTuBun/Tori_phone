import Foundation

/// Aligns a kanji+okurigana string with its full reading so each kanji run
/// gets its own ruby. Port of src/components/ui/Furigana.tsx.
enum Furigana {
    struct Segment: Hashable, Sendable {
        let text: String
        let reading: String?
    }

    /// Per-character readings for compounds ("教師/きょうし" -> ["きょう", "し"]),
    /// built from data/furigana-map.json. Jukujikun (明日/あした) have no entry.
    private static let map: [String: [String]?] = {
        guard let url = Bundle.main.url(forResource: "furigana-map", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]?].self, from: data) else { return [:] }
        return decoded
    }()

    /// CJK ideographs plus the 々 iteration mark (part of the preceding kanji run).
    static func isKanji(_ c: Character) -> Bool {
        c.unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) || $0.value == 0x3005
        }
    }

    static func hasKanji(_ s: String) -> Bool { s.contains(where: isKanji) }

    private struct Run { var text: [Character]; let isKanji: Bool }

    private static func splitRuns(_ s: String) -> [Run] {
        var runs: [Run] = []
        for ch in s {
            let k = isKanji(ch)
            if let last = runs.last, last.isKanji == k { runs[runs.count - 1].text.append(ch) }
            else { runs.append(Run(text: [ch], isKanji: k)) }
        }
        return runs
    }

    private static func indexOf(_ needle: [Character], in hay: [Character], from start: Int) -> Int? {
        guard !needle.isEmpty else { return min(start, hay.count) }
        guard start >= 0, hay.count >= needle.count else { return nil }
        var i = start
        while i + needle.count <= hay.count {
            if Array(hay[i..<(i + needle.count)]) == needle { return i }
            i += 1
        }
        return nil
    }

    /// Anchors on the literal (non-kanji) runs. Returns nil when a kanji run's
    /// reading boundary cannot be located (its next literal is not in `kana`,
    /// e.g. punctuation): the true split is unknowable without a dictionary, so
    /// the caller shows plain text rather than a confidently wrong alignment.
    ///
    /// Unlike the web's greedy first-match, this tries every place a literal can
    /// anchor and prefers a non-empty reading and a split that consumes the
    /// whole reading, so 歌う (うたう) gets た-ruby instead of none.
    static func align(kanji: String, kana: String) -> [Segment]? {
        let runs = splitRuns(kanji)
        // Brackets and punctuation in the reading ("かけます［でんわを～］") are not sounds.
        let kanaChars = kana.filter { !isNoiseChar($0) }
        return solve(runs, from: 0, pos: 0, kana: Array(kanaChars))?.segments
    }

    private struct Solution { var segments: [Segment]; var end: Int }

    private static let sentencePunctuation: Set<Character> = ["。", "、", "！", "？", "…", "・"]

    /// The part of a literal that can appear in a reading: punctuation and
    /// brackets never do ("ピンク(" anchors as "ピンク").
    private static func anchor(_ run: Run) -> [Character] {
        run.text.filter { !isNoiseChar($0) }
    }

    private static func isNoiseChar(_ c: Character) -> Bool {
        ignorable.contains(c) || open.contains(c) || close.contains(c) || separators.contains(c) || sentencePunctuation.contains(c)
            || c == "［" || c == "］" || c == "[" || c == "]"
    }

    /// A literal run made only of punctuation or brackets.
    private static func isNoise(_ run: Run) -> Bool {
        !run.isKanji && run.text.allSatisfy(isNoiseChar)
    }

    private static func solve(_ runs: [Run], from i: Int, pos: Int, kana: [Character]) -> Solution? {
        guard i < runs.count else { return Solution(segments: [], end: pos) }
        let run = runs[i]
        let text = String(run.text)

        if !run.isKanji {
            // Punctuation never appears in a reading, so it is not an anchor.
            if isNoise(run) {
                guard var rest = solve(runs, from: i + 1, pos: pos, kana: kana) else { return nil }
                rest.segments.insert(Segment(text: text, reading: nil), at: 0)
                return rest
            }
            // A literal must be found in the reading; skipping a missing one would
            // hand its sounds to the next kanji. Bracketed notes have their own pass.
            let a = anchor(run)
            guard let at = indexOf(a, in: kana, from: pos) else { return nil }
            let next = at + a.count
            guard var rest = solve(runs, from: i + 1, pos: next, kana: kana) else { return nil }
            rest.segments.insert(Segment(text: text, reading: nil), at: 0)
            return rest
        }

        // Where may this kanji run's reading end? Wherever the next literal can sit.
        var ends: [Int] = []
        if let next = runs[(i + 1)...].first(where: { !$0.isKanji && !isNoise($0) }) {
            // Kanji, punctuation, kanji ("年～回"): the split between the two is unknowable.
            if let firstAfter = runs[(i + 1)...].first(where: { !isNoise($0) || $0.isKanji }), firstAfter.isKanji { return nil }
            var from = pos
            let a = anchor(next)
            while let idx = indexOf(a, in: kana, from: from) {
                ends.append(idx)
                from = idx + 1
            }
            if ends.isEmpty { return nil }
            // Non-empty readings first; an empty one is the last resort.
            ends = ends.filter { $0 > pos } + ends.filter { $0 <= pos }
        } else {
            if runs[(i + 1)...].contains(where: { $0.isKanji }) { return nil }
            ends = [kana.count]
        }

        var best: Solution?
        for end in ends {
            let reading = pos <= end ? String(kana[pos..<end]) : ""
            guard var rest = solve(runs, from: i + 1, pos: end, kana: kana) else { continue }
            var head: [Segment] = []
            if run.text.count > 1, let split = map["\(text)/\(reading)"] ?? nil, split.count == run.text.count {
                for (ch, r) in zip(run.text, split) { head.append(Segment(text: String(ch), reading: r.isEmpty ? nil : r)) }
            } else {
                head = [Segment(text: text, reading: reading.isEmpty ? nil : reading)]
            }
            rest.segments.insert(contentsOf: head, at: 0)
            if rest.end == kana.count { return rest }       // consumed the whole reading
            if best == nil { best = rest }
        }
        return best
    }

    // MARK: Annotated words

    private static let ignorable: Set<Character> = ["～", "〜", "∼", "~", "○", "◯", "！", "!", "？", "?", " ", "\u{3000}"]
    private static let separators: Set<Character> = ["/", "／", "・", "、", ",", "，"]
    private static let open: Set<Character> = ["（", "("]
    private static let close: Set<Character> = ["）", ")"]

    private struct Piece { var text: [Character]; let isGroup: Bool }

    /// Splits at top-level separators; text inside brackets never splits.
    private static func alternatives(_ s: String) -> [(text: [Character], isSeparator: Bool)] {
        var out: [(text: [Character], isSeparator: Bool)] = []
        var cur: [Character] = []
        var depth = 0
        for ch in s {
            if open.contains(ch) { depth += 1 }
            if close.contains(ch) { depth = max(0, depth - 1) }
            if depth == 0, separators.contains(ch) {
                if !cur.isEmpty { out.append((cur, false)); cur = [] }
                out.append(([ch], true))
            } else { cur.append(ch) }
        }
        if !cur.isEmpty { out.append((cur, false)) }
        return out
    }

    private static func pieces(_ chars: [Character]) -> [Piece] {
        var out: [Piece] = [], cur: [Character] = []
        var depth = 0, group: [Character] = []
        for ch in chars {
            if open.contains(ch) {
                if depth == 0 { if !cur.isEmpty { out.append(Piece(text: cur, isGroup: false)); cur = [] } }
                depth += 1; group.append(ch)
            } else if close.contains(ch), depth > 0 {
                group.append(ch); depth -= 1
                if depth == 0 { out.append(Piece(text: group, isGroup: true)); group = [] }
            } else if depth > 0 { group.append(ch) }
            else { cur.append(ch) }
        }
        if !group.isEmpty { cur.append(contentsOf: group) }
        if !cur.isEmpty { out.append(Piece(text: cur, isGroup: false)) }
        return out
    }

    /// Aligns one alternative whose notes sit in brackets. Bracket content that
    /// is kana only ("する") joins the reading, as does a lone trailing kanji
    /// ("(色)"); any other content is a note that stays plain and out of the
    /// ruby. If the reading omits the inlined text ("満足（する） / まんぞく"),
    /// it is retried with every note left out.
    private static func alignAnnotated(_ chars: [Character], kana: String) -> [Segment]? {
        alignAnnotated(chars, kana: kana, inlining: true) ?? alignAnnotated(chars, kana: kana, inlining: false)
    }

    private static func alignAnnotated(_ chars: [Character], kana: String, inlining: Bool) -> [Segment]? {
        var core: [Character] = []
        var insertions: [(offset: Int, text: String)] = []   // text to put back at an offset in `core`
        for piece in pieces(chars) {
            if !piece.isGroup {
                core.append(contentsOf: piece.text)
                continue
            }
            let inner = Array(piece.text.dropFirst().dropLast())
            let hasKanji = inner.contains(where: isKanji)
            let plainInner = !inner.isEmpty && !inner.contains(where: { ignorable.contains($0) })
            let inline = inlining && !core.isEmpty && plainInner && (!hasKanji || inner.allSatisfy(isKanji))
            if inline {
                insertions.append((core.count, String(piece.text.first!)))
                core.append(contentsOf: inner)
                insertions.append((core.count, String(piece.text.last!)))
            } else {
                insertions.append((core.count, String(piece.text)))
            }
        }
        guard core.contains(where: isKanji), let base = align(kanji: String(core), kana: kana) else { return nil }
        guard !insertions.isEmpty else { return base }

        // Put the brackets and notes back. Between segments they stand alone;
        // inside one (a ruby'd run like 緑色) they ride along in its text.
        var out: [Segment] = []
        var offset = 0
        var pending = insertions[...]
        func flush(upTo limit: Int) {
            while let ins = pending.first, ins.offset <= limit {
                out.append(Segment(text: ins.text, reading: nil)); pending = pending.dropFirst()
            }
        }
        for seg in base {
            let chars = Array(seg.text), n = chars.count
            flush(upTo: offset)
            var text = ""
            for (k, ch) in chars.enumerated() {
                while let ins = pending.first, ins.offset == offset + k, k > 0 { text += ins.text; pending = pending.dropFirst() }
                text.append(ch)
            }
            offset += n
            while let ins = pending.first, ins.offset == offset, ins.text.count == 1, close.contains(ins.text.first!) {
                text += ins.text; pending = pending.dropFirst()   // a closing bracket stays with what it closes
            }
            out.append(Segment(text: text, reading: seg.reading))
        }
        flush(upTo: offset)
        return out
    }

    /// Words written with notes or alternatives ("安心（する）", "葉/葉っぱ"):
    /// the alternative that lines up with the reading best (most okurigana
    /// matched, first on a tie) gets the ruby, the rest stays plain. nil when
    /// none lines up.
    static func alignLenient(kanji: String, kana: String) -> [Segment]? {
        let alts = alternatives(kanji)
        var chosen: [Segment]?, chosenIndex = -1, chosenScore = -1
        for (i, alt) in alts.enumerated() where !alt.isSeparator && alt.text.contains(where: isKanji) {
            guard let segs = alignAnnotated(alt.text, kana: kana) else { continue }
            let score = segs.filter { $0.reading == nil }.reduce(0) { $0 + $1.text.filter { !open.contains($0) && !close.contains($0) && !ignorable.contains($0) }.count }
            if score > chosenScore { chosen = segs; chosenIndex = i; chosenScore = score }
        }
        guard let chosen else { return nil }
        var out: [Segment] = []
        for (i, alt) in alts.enumerated() {
            if i == chosenIndex { out.append(contentsOf: chosen) }
            else { out.append(Segment(text: String(alt.text), reading: nil)) }
        }
        return out
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: [Segment]?] = [:]

    /// `align` is pure in (kanji, kana) and list rows re-mount constantly.
    static func alignCached(kanji: String, kana: String) -> [Segment]? {
        let key = kanji + "\u{0}" + kana
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let hit = cache[key] { return hit }
        let result = align(kanji: kanji, kana: kana) ?? alignLenient(kanji: kanji, kana: kana)
        cache[key] = .some(result)
        return result
    }
}
