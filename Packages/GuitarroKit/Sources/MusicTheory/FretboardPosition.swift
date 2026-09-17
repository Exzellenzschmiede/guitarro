/// A location on the fretboard: string index (0 = lowest string) and fret (0 = open).
public struct FretboardPosition: Hashable, Sendable, Codable, Comparable {
    public let string: Int
    public let fret: Int

    public init(string: Int, fret: Int) {
        self.string = string
        self.fret = fret
    }

    public static func < (lhs: FretboardPosition, rhs: FretboardPosition) -> Bool {
        (lhs.string, lhs.fret) < (rhs.string, rhs.fret)
    }
}

public extension Tuning {
    /// The pitch sounding at a position.
    func pitch(at position: FretboardPosition) -> Pitch {
        strings[position.string].transposed(by: position.fret)
    }

    /// Every position up to `maxFret` that produces exactly this pitch.
    func positions(of pitch: Pitch, maxFret: Int) -> [FretboardPosition] {
        strings.enumerated().compactMap { index, open in
            let fret = pitch.midiNumber - open.midiNumber
            return (0...maxFret).contains(fret) ? FretboardPosition(string: index, fret: fret) : nil
        }
    }

    /// Every position up to `maxFret` that produces this pitch class in any octave.
    func positions(of pitchClass: PitchClass, maxFret: Int) -> [FretboardPosition] {
        strings.enumerated().flatMap { index, open in
            (0...maxFret).compactMap { fret in
                open.transposed(by: fret).pitchClass == pitchClass ? FretboardPosition(string: index, fret: fret) : nil
            }
        }
    }
}
