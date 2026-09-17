import Foundation
import SwiftData
import Training

/// Persisted spaced-repetition state for one chord change.
@Model
final class ChordChangeProgress {
    @Attribute(.unique) var pairID: String
    var ease: Double
    var intervalDays: Double
    var due: Date
    var reviews: Int
    var best: Int
    var last: Int
    var lastPracticed: Date?

    init(pairID: String, state: SkillState) {
        self.pairID = pairID
        ease = state.ease
        intervalDays = state.intervalDays
        due = state.due
        reviews = state.reviews
        best = state.best
        last = state.last
        lastPracticed = state.lastPracticed
    }

    var state: SkillState {
        get {
            SkillState(ease: ease, intervalDays: intervalDays, due: due, reviews: reviews, best: best, last: last, lastPracticed: lastPracticed)
        }
        set {
            ease = newValue.ease
            intervalDays = newValue.intervalDays
            due = newValue.due
            reviews = newValue.reviews
            best = newValue.best
            last = newValue.last
            lastPracticed = newValue.lastPracticed
        }
    }
}

extension Array where Element == ChordChangeProgress {
    /// Maps stored progress to scheduler input, ignoring pairs the curriculum no longer knows.
    var skillStates: [ChordPair: SkillState] {
        var states: [ChordPair: SkillState] = [:]
        for progress in self {
            if let pair = ChordPair(id: progress.pairID) {
                states[pair] = progress.state
            }
        }
        return states
    }
}
