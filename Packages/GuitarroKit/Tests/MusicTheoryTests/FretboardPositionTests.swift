import Testing
@testable import MusicTheory

@Suite struct FretboardPositionTests {
    @Test func pitchAtPosition() {
        #expect(Tuning.standard.pitch(at: FretboardPosition(string: 1, fret: 3)) == Pitch(.c, octave: 3))
        #expect(Tuning.standard.pitch(at: FretboardPosition(string: 5, fret: 0)) == Pitch(.e, octave: 4))
        #expect(Tuning.standard.pitch(at: FretboardPosition(string: 0, fret: 12)) == Pitch(.e, octave: 3))
    }

    @Test func positionsOfPitch() {
        let positions = Tuning.standard.positions(of: Pitch(.e, octave: 4), maxFret: 12)
        #expect(positions == [
            FretboardPosition(string: 3, fret: 9),
            FretboardPosition(string: 4, fret: 5),
            FretboardPosition(string: 5, fret: 0),
        ])
    }

    @Test func positionsOfPitchClassCoverEveryString() {
        let positions = Tuning.standard.positions(of: .a, maxFret: 12)
        #expect(Set(positions.map(\.string)) == Set(0..<6))
        #expect(positions.contains(FretboardPosition(string: 1, fret: 0)))
        #expect(positions.contains(FretboardPosition(string: 1, fret: 12)))
    }

    @Test func ordering() {
        #expect(FretboardPosition(string: 0, fret: 5) < FretboardPosition(string: 1, fret: 0))
        #expect(FretboardPosition(string: 2, fret: 1) < FretboardPosition(string: 2, fret: 2))
    }
}
