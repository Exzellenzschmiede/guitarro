import Testing
@testable import MusicTheory

@Suite struct TuningTests {
    @Test func standardTuningStrings() {
        let names = Tuning.standard.strings.map { $0.name(includeOctave: false) }
        #expect(names == ["E", "A", "D", "G", "B", "E"])
        #expect(Tuning.standard.strings.first == Pitch(.e, octave: 2))
        #expect(Tuning.standard.strings.last == Pitch(.e, octave: 4))
    }

    @Test func halfStepDownTransposesEveryString() {
        #expect(Tuning.halfStepDown.strings.first == Pitch(.dSharp, octave: 2))
        #expect(Tuning.halfStepDown.strings.last == Pitch(.dSharp, octave: 4))
    }

    @Test func nearestStringExactMatch() {
        let match = Tuning.standard.nearestString(toFrequency: 110)
        #expect(match.index == 1)
        #expect(match.stringNumber == 5)
        #expect(match.pitch == Pitch(.a, octave: 2))
        #expect(abs(match.cents) < 0.0001)
    }

    @Test func nearestStringPrefersClosest() {
        // 300 Hz lies between B3 (246.9) and E4 (329.6); E4 is closer in cents.
        let match = Tuning.standard.nearestString(toFrequency: 300)
        #expect(match.pitch == Pitch(.e, octave: 4))
        #expect(match.cents < 0)
    }

    @Test func presetsHaveUniqueIds() {
        let ids = Tuning.presets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
