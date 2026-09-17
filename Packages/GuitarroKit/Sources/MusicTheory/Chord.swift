public enum ChordQuality: String, CaseIterable, Sendable, Codable, Hashable {
    case major
    case minor
    case dominantSeventh
    case minorSeventh
    case majorSeventh
    case suspendedSecond
    case suspendedFourth
    case diminished
    case augmented

    /// The intervals above the root that make up the chord.
    public var intervals: [Interval] {
        switch self {
        case .major: [.unison, .majorThird, .perfectFifth]
        case .minor: [.unison, .minorThird, .perfectFifth]
        case .dominantSeventh: [.unison, .majorThird, .perfectFifth, .minorSeventh]
        case .minorSeventh: [.unison, .minorThird, .perfectFifth, .minorSeventh]
        case .majorSeventh: [.unison, .majorThird, .perfectFifth, .majorSeventh]
        case .suspendedSecond: [.unison, .majorSecond, .perfectFifth]
        case .suspendedFourth: [.unison, .perfectFourth, .perfectFifth]
        case .diminished: [.unison, .minorThird, .tritone]
        case .augmented: [.unison, .majorThird, .minorSixth]
        }
    }

    /// Chord symbol suffix, e.g. "m" for minor or "7" for a dominant seventh.
    public var symbol: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .dominantSeventh: "7"
        case .minorSeventh: "m7"
        case .majorSeventh: "maj7"
        case .suspendedSecond: "sus2"
        case .suspendedFourth: "sus4"
        case .diminished: "dim"
        case .augmented: "aug"
        }
    }
}

/// A chord as an abstract set of pitch classes (no specific voicing).
public struct Chord: Hashable, Sendable, Codable, Identifiable {
    public let root: PitchClass
    public let quality: ChordQuality

    public init(_ root: PitchClass, _ quality: ChordQuality = .major) {
        self.root = root
        self.quality = quality
    }

    public var id: String { "\(root.rawValue).\(quality.rawValue)" }

    public var intervals: [Interval] { quality.intervals }

    /// The chord tones in order of their intervals (root first).
    public var pitchClasses: [PitchClass] {
        intervals.map { PitchClass(semitone: root.rawValue + $0.semitones) }
    }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        interval(of: pitchClass) != nil
    }

    /// The chord tone's interval above the root, or `nil` if the pitch class is not part of the chord.
    public func interval(of pitchClass: PitchClass) -> Interval? {
        let interval = Interval.between(root, pitchClass)
        return intervals.contains(interval) ? interval : nil
    }

    /// Chord symbol such as "Em", "A7" or "Hm" (German style).
    public func symbol(style: NoteNamingStyle = .international, accidentals: AccidentalStyle = .sharps) -> String {
        root.name(style: style, accidentals: accidentals) + quality.symbol
    }
}
