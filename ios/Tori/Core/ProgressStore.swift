import Foundation
import Observation

/// The only user data in the app: SRS card state and learned grammar points.
/// Persisted as one small JSON file in Application Support (the web app keeps
/// the same data in localStorage under `tori-vocab` / `tori-grammar`).
@MainActor @Observable
final class ProgressStore {
    private(set) var cards: [String: SRSCard] = [:]
    private(set) var totalReviewed = 0
    private(set) var learnedGrammar: Set<String> = []

    private let fileURL: URL?

    private struct Snapshot: Codable {
        var cards: [String: SRSCard]
        var totalReviewed: Int
        var learnedGrammar: [String]
    }

    /// `fileURL == nil` keeps everything in memory (tests).
    init(fileURL: URL? = ProgressStore.defaultURL) {
        self.fileURL = fileURL
        load()
    }

    nonisolated static var defaultURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("tori-progress.json")
    }

    // MARK: SRS (mirrors src/store/vocab-store.ts; every query is scoped to ids)

    func card(_ id: String) -> SRSCard { cards[id] ?? .makeDefault(id: id) }

    func dueCards(in ids: [String], now: Date = Date()) -> [SRSCard] {
        ids.compactMap { id in
            guard let c = cards[id], c.state != .new, SRS.isDue(c, now: now) else { return nil }
            return c
        }
    }

    func newCards(in ids: [String], limit: Int? = nil) -> [SRSCard] {
        let fresh = ids.filter { cards[$0] == nil || cards[$0]?.state == .new }
        let picked = limit.map { Array(fresh.prefix($0)) } ?? fresh
        return picked.map { .makeDefault(id: $0) }
    }

    func scheduledCards(in ids: [String], now: Date = Date()) -> [SRSCard] {
        ids.compactMap { id in
            guard let c = cards[id], c.state != .new, !SRS.isDue(c, now: now) else { return nil }
            return c
        }
    }

    func review(_ id: String, cardType: String, rating: Rating, now: Date = Date()) {
        var base = card(id)
        base.cardType = cardType
        cards[id] = SRS.schedule(base, rating: rating, now: now)
        totalReviewed += 1
        save()
    }

    // MARK: Grammar

    func isLearned(_ id: String) -> Bool { learnedGrammar.contains(id) }

    func toggleLearned(_ id: String) {
        if learnedGrammar.contains(id) { learnedGrammar.remove(id) } else { learnedGrammar.insert(id) }
        save()
    }

    func reset() {
        cards = [:]
        totalReviewed = 0
        learnedGrammar = []
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        cards = snap.cards
        totalReviewed = snap.totalReviewed
        learnedGrammar = Set(snap.learnedGrammar)
    }

    private func save() {
        guard let fileURL else { return }
        let snap = Snapshot(cards: cards, totalReviewed: totalReviewed, learnedGrammar: learnedGrammar.sorted())
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snap).write(to: fileURL, options: .atomic)
        } catch {
            // Progress is a convenience; a failed write must never crash a review.
            print("ProgressStore save failed: \(error)")
        }
    }
}
