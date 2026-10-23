import Foundation

/// Classic SM-2 scheduler, a line-for-line port of src/lib/srs.ts.
enum Rating: Int, CaseIterable, Sendable {
    case again = 1, hard, good, easy

    /// SM-2 quality (0-5): AGAIN is a full lapse, the rest are correct recalls.
    var quality: Int {
        switch self {
        case .again: 0
        case .hard: 3
        case .good: 4
        case .easy: 5
        }
    }

    /// Again/Hard resurface a few cards later in the same session.
    var requeues: Bool { self == .again || self == .hard }
}

enum SRS {
    static func schedule(_ card: SRSCard, rating: Rating, now: Date = Date(), calendar: Calendar = .current) -> SRSCard {
        var interval = card.interval
        var repetition = card.repetition
        var easeFactor = card.easeFactor
        var lapseCount = card.lapseCount
        let quality = Double(rating.quality)

        if rating == .again {
            repetition = 0
            interval = 1
            lapseCount += 1
        } else {
            if repetition == 0 { interval = 1 }
            else if repetition == 1 { interval = 6 }
            else { interval = max(1, Int((Double(interval) * easeFactor).rounded())) }
            repetition += 1
        }

        // SM-2 ease-factor update, applied on every review.
        easeFactor = max(1.3, easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))

        var updated = card
        updated.interval = interval
        updated.repetition = repetition
        updated.easeFactor = easeFactor
        updated.lapseCount = lapseCount
        updated.reviewCount += 1
        updated.lastReview = now
        updated.nextReview = calendar.date(byAdding: .day, value: interval, to: now)
        updated.state = rating == .again ? .learning : (interval >= 21 ? .mastered : .review)
        return updated
    }

    static func isDue(_ card: SRSCard, now: Date = Date()) -> Bool {
        if card.state == .new { return true }
        guard let next = card.nextReview else { return true }
        return next <= now
    }
}
