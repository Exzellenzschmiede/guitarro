import Foundation

/// A guitar tuning: the open-string pitches ordered from the lowest (6th) string to the highest (1st).
public struct Tuning: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let strings: [Pitch]

    public init(id: String, strings: [Pitch]) {
        self.id = id
        self.strings = strings
    }

    public var stringCount: Int { strings.count }

    public func transposed(by semitones: Int, id: String) -> Tuning {
        Tuning(id: id, strings: strings.map { $0.transposed(by: semitones) })
    }

    // MARK: Presets

    public static let standard = Tuning(id: "standard", strings: [
        Pitch(.e, octave: 2), Pitch(.a, octave: 2), Pitch(.d, octave: 3),
        Pitch(.g, octave: 3), Pitch(.b, octave: 3), Pitch(.e, octave: 4),
    ])

    public static let dropD = Tuning(id: "dropD", strings: [
        Pitch(.d, octave: 2), Pitch(.a, octave: 2), Pitch(.d, octave: 3),
        Pitch(.g, octave: 3), Pitch(.b, octave: 3), Pitch(.e, octave: 4),
    ])

    public static let halfStepDown = standard.transposed(by: -1, id: "halfStepDown")

    public static let dadgad = Tuning(id: "dadgad", strings: [
        Pitch(.d, octave: 2), Pitch(.a, octave: 2), Pitch(.d, octave: 3),
        Pitch(.g, octave: 3), Pitch(.a, octave: 3), Pitch(.d, octave: 4),
    ])

    public static let openG = Tuning(id: "openG", strings: [
        Pitch(.d, octave: 2), Pitch(.g, octave: 2), Pitch(.d, octave: 3),
        Pitch(.g, octave: 3), Pitch(.b, octave: 3), Pitch(.d, octave: 4),
    ])

    public static let openD = Tuning(id: "openD", strings: [
        Pitch(.d, octave: 2), Pitch(.a, octave: 2), Pitch(.d, octave: 3),
        Pitch(.fSharp, octave: 3), Pitch(.a, octave: 3), Pitch(.d, octave: 4),
    ])

    public static let presets: [Tuning] = [.standard, .dropD, .halfStepDown, .dadgad, .openG, .openD]

    // MARK: String matching

    public struct StringMatch: Sendable, Equatable {
        /// Index into `strings` (0 = lowest string).
        public let index: Int
        /// Conventional string number (6 = lowest string on a six-string guitar).
        public let stringNumber: Int
        public let pitch: Pitch
        /// Deviation of the played frequency from the string's target pitch in cents.
        public let cents: Double
    }

    /// The open string whose pitch is closest to the given frequency.
    public func nearestString(toFrequency frequency: Double, a4: Double = Pitch.standardA4Frequency) -> StringMatch {
        precondition(!strings.isEmpty, "A tuning needs at least one string")
        var best = StringMatch(index: 0, stringNumber: strings.count, pitch: strings[0], cents: strings[0].cents(fromFrequency: frequency, a4: a4))
        for (index, pitch) in strings.enumerated().dropFirst() {
            let cents = pitch.cents(fromFrequency: frequency, a4: a4)
            if abs(cents) < abs(best.cents) {
                best = StringMatch(index: index, stringNumber: strings.count - index, pitch: pitch, cents: cents)
            }
        }
        return best
    }
}
