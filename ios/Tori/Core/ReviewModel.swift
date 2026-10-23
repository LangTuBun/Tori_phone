import Foundation
import Observation

struct KanjiPoolEntry: Hashable, Sendable {
    let id: String
    let word: KanjiWord
    let group: KanjiGroup
    let chapter: Int
}

enum ReviewCard: Identifiable, Hashable {
    case vocab(id: String, cardType: String, entry: VocabEntry)
    case kanji(id: String, entry: KanjiPoolEntry)

    var id: String {
        switch self {
        case .vocab(let id, _, _): id
        case .kanji(let id, _): id
        }
    }

    var cardType: String {
        switch self {
        case .vocab(_, let type, _): type
        case .kanji: "kanji"
        }
    }
}

/// Review session state machine, ported from the logic in src/pages/Review.tsx.
@MainActor @Observable
final class ReviewModel {
    enum Mode: Hashable { case vocab, kanji }
    enum Phase { case setup, session, done }

    /// Again/Hard come back this many cards later in the same session.
    static let requeueGap = 4
    static let countPresets = [10, 20, 30, 50]

    var mode: Mode = .vocab
    var phase: Phase = .setup
    private(set) var queue: [ReviewCard] = []
    private(set) var index = 0
    var flipped = false
    private(set) var reviewed = 0

    var current: ReviewCard? { queue.indices.contains(index) ? queue[index] : nil }
    var progress: Double { queue.isEmpty ? 0 : Double(index) / Double(queue.count) }

    /// Due first, then new, then not-yet-due; capped at `count`, then shuffled.
    static func buildQueue(ids: [String], count: Int, store: ProgressStore,
                           resolve: (SRSCard) -> ReviewCard?,
                           shuffle: ([SRSCard]) -> [SRSCard] = { $0.shuffled() }) -> [ReviewCard] {
        let due = store.dueCards(in: ids)
        let scheduled = store.scheduledCards(in: ids)
        let fresh = store.newCards(in: ids, limit: count)
        let selected = Array((due + fresh + scheduled).prefix(count))
        return shuffle(selected).compactMap(resolve)
    }

    func start(with cards: [ReviewCard]) {
        queue = cards
        index = 0
        flipped = false
        reviewed = 0
        phase = cards.isEmpty ? .setup : .session
    }

    func rate(_ rating: Rating, store: ProgressStore) {
        guard let card = current else { return }
        store.review(card.id, cardType: card.cardType, rating: rating)
        reviewed += 1
        if rating.requeues {
            let at = min(queue.count, index + 1 + Self.requeueGap)
            queue.insert(card, at: at)
        }
        if index + 1 >= queue.count {
            phase = .done
        } else {
            index += 1
            flipped = false
        }
    }

    func backToSetup() {
        phase = .setup
        queue = []
        index = 0
        flipped = false
    }
}
