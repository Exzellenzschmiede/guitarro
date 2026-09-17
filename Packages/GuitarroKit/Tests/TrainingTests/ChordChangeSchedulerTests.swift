import Foundation
import Testing
@testable import Training

@Suite struct ChordChangeSchedulerTests {
    let day = 86_400.0
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func ratingBands() {
        #expect(ChordChangeScheduler.rating(changesPerMinute: 4) == 1)
        #expect(ChordChangeScheduler.rating(changesPerMinute: 15) == 2)
        #expect(ChordChangeScheduler.rating(changesPerMinute: 25) == 3)
        #expect(ChordChangeScheduler.rating(changesPerMinute: 40) == 4)
        #expect(ChordChangeScheduler.rating(changesPerMinute: 60) == 5)
    }

    @Test func goodSessionsStretchTheInterval() {
        var state = SkillState(due: start)
        state = ChordChangeScheduler.review(state, changesPerMinute: 35, on: start)
        #expect(state.reviews == 1)
        #expect(state.intervalDays == 1)
        #expect(state.due == start.addingTimeInterval(day))
        #expect(state.best == 35)

        state = ChordChangeScheduler.review(state, changesPerMinute: 50, on: state.due)
        #expect(state.intervalDays == 3)

        let third = ChordChangeScheduler.review(state, changesPerMinute: 50, on: state.due)
        #expect(third.intervalDays > 3)
        #expect(third.ease > state.ease)
        #expect(third.best == 50)
    }

    @Test func weakSessionsComeBackTheSameDay() {
        var state = SkillState(ease: 2.5, intervalDays: 6, due: start, reviews: 3, best: 40, last: 40)
        state = ChordChangeScheduler.review(state, changesPerMinute: 8, on: start)
        #expect(state.intervalDays == 0.5)
        #expect(state.ease == 2.3)
        #expect(state.best == 40)
        #expect(state.last == 8)
    }

    @Test func easeNeverDropsBelowFloor() {
        var state = SkillState(ease: 1.35, due: start)
        state = ChordChangeScheduler.review(state, changesPerMinute: 2, on: start)
        #expect(state.ease == 1.3)
    }

    @Test func intervalIsCapped() {
        var state = SkillState(ease: 3, intervalDays: 50, due: start, reviews: 8)
        state = ChordChangeScheduler.review(state, changesPerMinute: 60, on: start)
        #expect(state.intervalDays == ChordChangeScheduler.maximumIntervalDays)
    }

    @Test func nextPrefersDueThenUnseenThenSoonest() {
        let curriculum = ChordChangeCurriculum.beginner
        #expect(ChordChangeScheduler.next(from: [:], curriculum: curriculum, on: start) == curriculum[0])

        var states: [ChordPair: SkillState] = [
            curriculum[0]: SkillState(due: start.addingTimeInterval(day), reviews: 1),
        ]
        #expect(ChordChangeScheduler.next(from: states, curriculum: curriculum, on: start) == curriculum[1])

        states[curriculum[1]] = SkillState(ease: 1.8, due: start.addingTimeInterval(-day), reviews: 2)
        states[curriculum[2]] = SkillState(ease: 2.5, due: start.addingTimeInterval(-day), reviews: 2)
        #expect(ChordChangeScheduler.next(from: states, curriculum: curriculum, on: start) == curriculum[1])

        let everythingSeen = Dictionary(uniqueKeysWithValues: curriculum.enumerated().map { index, pair in
            (pair, SkillState(due: start.addingTimeInterval(Double(index + 1) * day), reviews: 1))
        })
        #expect(ChordChangeScheduler.next(from: everythingSeen, curriculum: curriculum, on: start) == curriculum[0])
    }

    @Test func pairIdentifiersRoundTrip() {
        let pair = ChordPair("F#m", "E")
        #expect(ChordPair(id: pair.id) == pair)
        #expect(pair.fromVoicing?.chord.symbol() == "F♯m")
        #expect(ChordPair(id: "broken") == nil)
    }

    @Test func curriculumUsesKnownVoicings() {
        for pair in ChordChangeCurriculum.beginner {
            #expect(pair.fromVoicing != nil, "\(pair.from)")
            #expect(pair.toVoicing != nil, "\(pair.to)")
        }
    }
}
