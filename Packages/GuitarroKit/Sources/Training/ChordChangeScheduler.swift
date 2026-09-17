import Foundation

/// Spaced-repetition state for one chord change.
public struct SkillState: Sendable, Codable, Equatable {
    public var ease: Double
    public var intervalDays: Double
    public var due: Date
    public var reviews: Int
    public var best: Int
    public var last: Int
    public var lastPracticed: Date?

    public init(ease: Double = 2.5, intervalDays: Double = 0, due: Date, reviews: Int = 0, best: Int = 0, last: Int = 0, lastPracticed: Date? = nil) {
        self.ease = ease
        self.intervalDays = intervalDays
        self.due = due
        self.reviews = reviews
        self.best = best
        self.last = last
        self.lastPracticed = lastPracticed
    }

    public var isNew: Bool { reviews == 0 }

    public func isDue(on date: Date) -> Bool { due <= date }
}

/// SM-2 style scheduling of one-minute chord changes.
///
/// A session's changes per minute become a 1…5 rating. Ratings below 3 bring the
/// change back the same day; better ratings stretch the interval by the ease factor.
public enum ChordChangeScheduler {
    public static let maximumIntervalDays = 60.0

    public static func rating(changesPerMinute: Int) -> Int {
        switch changesPerMinute {
        case ..<10: 1
        case ..<20: 2
        case ..<30: 3
        case ..<45: 4
        default: 5
        }
    }

    public static func review(_ state: SkillState, changesPerMinute: Int, on date: Date = .now) -> SkillState {
        var next = state
        next.reviews += 1
        next.last = changesPerMinute
        next.best = max(state.best, changesPerMinute)
        next.lastPracticed = date

        let quality = rating(changesPerMinute: changesPerMinute)
        if quality < 3 {
            next.intervalDays = 0.5
            next.ease = max(1.3, state.ease - 0.2)
        } else {
            switch next.reviews {
            case 1: next.intervalDays = 1
            case 2: next.intervalDays = 3
            default: next.intervalDays = min(maximumIntervalDays, max(1, state.intervalDays) * state.ease)
            }
            let shortfall = Double(5 - quality)
            next.ease = max(1.3, state.ease + 0.1 - shortfall * (0.08 + shortfall * 0.02))
        }
        next.due = date.addingTimeInterval(next.intervalDays * 86_400)
        return next
    }

    /// Picks what to practise next: the most overdue change (weakest first on ties),
    /// then the next unseen change from the curriculum, then whatever comes due soonest.
    public static func next(from states: [ChordPair: SkillState], curriculum: [ChordPair], on date: Date = .now) -> ChordPair? {
        let due = states.filter { $0.value.isDue(on: date) }
        if let weakest = due.min(by: { lhs, rhs in
            if lhs.value.due != rhs.value.due { return lhs.value.due < rhs.value.due }
            return lhs.value.ease < rhs.value.ease
        }) {
            return weakest.key
        }
        if let unseen = curriculum.first(where: { states[$0] == nil }) {
            return unseen
        }
        return states.min { $0.value.due < $1.value.due }?.key ?? curriculum.first
    }

    /// Changes that are due, most overdue first.
    public static func dueChanges(from states: [ChordPair: SkillState], on date: Date = .now) -> [ChordPair] {
        states.filter { $0.value.isDue(on: date) }
            .sorted { $0.value.due < $1.value.due }
            .map(\.key)
    }
}
