/// A musical interval measured in semitones.
public struct Interval: Hashable, Sendable, Codable, Comparable {
    public let semitones: Int

    public init(semitones: Int) {
        self.semitones = semitones
    }

    public static let unison = Interval(semitones: 0)
    public static let minorSecond = Interval(semitones: 1)
    public static let majorSecond = Interval(semitones: 2)
    public static let minorThird = Interval(semitones: 3)
    public static let majorThird = Interval(semitones: 4)
    public static let perfectFourth = Interval(semitones: 5)
    public static let tritone = Interval(semitones: 6)
    public static let perfectFifth = Interval(semitones: 7)
    public static let minorSixth = Interval(semitones: 8)
    public static let majorSixth = Interval(semitones: 9)
    public static let minorSeventh = Interval(semitones: 10)
    public static let majorSeventh = Interval(semitones: 11)
    public static let octave = Interval(semitones: 12)

    /// The interval reduced to within one octave.
    public var simple: Interval {
        Interval(semitones: ((semitones % 12) + 12) % 12)
    }

    /// Stable identifier such as "majorThird", used as a localization key suffix.
    public var name: String {
        Self.names[simple.semitones]
    }

    /// Compact chord-chart label such as "R", "♭3", "5" or "♭7".
    public var shortLabel: String {
        Self.shortLabels[simple.semitones]
    }

    /// The ascending interval from one pitch class to another (0…11 semitones).
    public static func between(_ from: PitchClass, _ to: PitchClass) -> Interval {
        Interval(semitones: ((to.rawValue - from.rawValue) % 12 + 12) % 12)
    }

    public static func < (lhs: Interval, rhs: Interval) -> Bool {
        lhs.semitones < rhs.semitones
    }

    private static let names = [
        "unison", "minorSecond", "majorSecond", "minorThird", "majorThird", "perfectFourth",
        "tritone", "perfectFifth", "minorSixth", "majorSixth", "minorSeventh", "majorSeventh",
    ]

    private static let shortLabels = ["R", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]
}
