import Testing
@testable import MusicTheory

@Suite struct PitchTests {
    @Test func a4IsConcertPitch() {
        #expect(Pitch.a4.midiNumber == 69)
        #expect(Pitch.a4.frequency() == 440)
        #expect(Pitch(.a, octave: 4) == .a4)
        #expect(Pitch.a4.frequency(a4: 442) == 442)
    }

    @Test func lowEFrequency() {
        #expect(abs(Pitch(.e, octave: 2).frequency() - 82.4069) < 0.001)
    }

    @Test func nearestPitchAndCents() {
        let result = Pitch.nearest(toFrequency: 83)
        #expect(result.pitch == Pitch(.e, octave: 2))
        #expect(abs(result.cents - 12.4) < 0.5)

        let exact = Pitch.nearest(toFrequency: 440)
        #expect(exact.pitch == .a4)
        #expect(abs(exact.cents) < 0.0001)
    }

    @Test func centsFromFrequency() {
        #expect(abs(Pitch.a4.cents(fromFrequency: 880) - 1200) < 0.0001)
        #expect(abs(Pitch.a4.cents(fromFrequency: 220) + 1200) < 0.0001)
    }

    @Test func octaveBoundaries() {
        #expect(Pitch(midiNumber: 60).name() == "C4")
        #expect(Pitch(midiNumber: 59).name() == "B3")
        #expect(Pitch(midiNumber: 60).octave == 4)
    }

    @Test func namingStyles() {
        let b3 = Pitch(.b, octave: 3)
        #expect(b3.name() == "B3")
        #expect(b3.name(style: .german) == "H3")
        #expect(b3.name(includeOctave: false) == "B")

        let aSharp = Pitch(.aSharp, octave: 3)
        #expect(aSharp.name() == "A♯3")
        #expect(aSharp.name(accidentals: .flats) == "B♭3")
        #expect(aSharp.name(style: .german, accidentals: .flats) == "B3")
    }

    @Test func pitchClassWrapsAround() {
        #expect(PitchClass(semitone: 12) == .c)
        #expect(PitchClass(semitone: -1) == .b)
        #expect(PitchClass(semitone: 13) == .cSharp)
    }
}
