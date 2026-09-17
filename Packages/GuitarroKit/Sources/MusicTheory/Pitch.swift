import Foundation

/// A concrete pitch identified by its MIDI note number (69 = A4).
public struct Pitch: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public static let standardA4Frequency: Double = 440
    public static let a4 = Pitch(midiNumber: 69)

    public let midiNumber: Int

    public init(midiNumber: Int) {
        self.midiNumber = midiNumber
    }

    public init(_ pitchClass: PitchClass, octave: Int) {
        midiNumber = (octave + 1) * 12 + pitchClass.rawValue
    }

    public var pitchClass: PitchClass { PitchClass(semitone: midiNumber) }

    /// Scientific pitch notation octave (C4 is middle C, A4 = 440 Hz).
    public var octave: Int { midiNumber / 12 - 1 }

    public func frequency(a4: Double = standardA4Frequency) -> Double {
        a4 * pow(2, Double(midiNumber - 69) / 12)
    }

    /// The fractional MIDI number of an arbitrary frequency.
    public static func exactMidiNumber(forFrequency frequency: Double, a4: Double = standardA4Frequency) -> Double {
        69 + 12 * log2(frequency / a4)
    }

    /// The closest pitch to a frequency and the deviation from it in cents (−50…50).
    public static func nearest(toFrequency frequency: Double, a4: Double = standardA4Frequency) -> (pitch: Pitch, cents: Double) {
        let exact = exactMidiNumber(forFrequency: frequency, a4: a4)
        let rounded = exact.rounded()
        return (Pitch(midiNumber: Int(rounded)), (exact - rounded) * 100)
    }

    /// How far a frequency is from this pitch, in cents. Positive means sharp.
    public func cents(fromFrequency frequency: Double, a4: Double = standardA4Frequency) -> Double {
        1200 * log2(frequency / self.frequency(a4: a4))
    }

    public func transposed(by semitones: Int) -> Pitch {
        Pitch(midiNumber: midiNumber + semitones)
    }

    public func name(style: NoteNamingStyle = .international, accidentals: AccidentalStyle = .sharps, includeOctave: Bool = true) -> String {
        let base = pitchClass.name(style: style, accidentals: accidentals)
        return includeOctave ? "\(base)\(octave)" : base
    }

    public var description: String { name() }

    public static func < (lhs: Pitch, rhs: Pitch) -> Bool {
        lhs.midiNumber < rhs.midiNumber
    }
}
