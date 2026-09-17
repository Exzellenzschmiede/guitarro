/// One concrete way to play a chord: what happens on each string.
public struct ChordVoicing: Hashable, Sendable, Codable, Identifiable {
    public enum StringAction: Hashable, Sendable, Codable {
        case muted
        case open
        case fretted(fret: Int, finger: Int)

        /// The sounding fret (0 for open), or `nil` when the string is muted.
        public var fret: Int? {
            switch self {
            case .muted: nil
            case .open: 0
            case .fretted(let fret, _): fret
            }
        }

        public var finger: Int? {
            if case .fretted(_, let finger) = self { return finger }
            return nil
        }
    }

    public struct Barre: Hashable, Sendable, Codable {
        public let fret: Int
        public let fromString: Int
        public let toString: Int
        public let finger: Int

        public init(fret: Int, fromString: Int, toString: Int, finger: Int = 1) {
            self.fret = fret
            self.fromString = fromString
            self.toString = toString
            self.finger = finger
        }
    }

    public let id: String
    public let chord: Chord
    /// One action per string, lowest string first.
    public let strings: [StringAction]
    public let barre: Barre?

    public init(id: String, chord: Chord, strings: [StringAction], barre: Barre? = nil) {
        self.id = id
        self.chord = chord
        self.strings = strings
        self.barre = barre
    }

    /// Creates a voicing from chord-chart shorthand, lowest string first:
    /// `frets` uses "x" for muted, "0" for open and a digit for the fret;
    /// `fingers` uses a digit per string (0 where no finger is used).
    public init(id: String, chord: Chord, frets: String, fingers: String, barre: Barre? = nil) {
        precondition(frets.count == fingers.count, "frets and fingers must cover the same strings")
        let actions = zip(frets, fingers).map { fret, finger -> StringAction in
            if fret == "x" || fret == "X" { return .muted }
            guard let fretNumber = fret.wholeNumberValue else {
                preconditionFailure("Invalid fret character '\(fret)' in voicing \(id)")
            }
            if fretNumber == 0 { return .open }
            return .fretted(fret: fretNumber, finger: finger.wholeNumberValue ?? 0)
        }
        self.init(id: id, chord: chord, strings: actions, barre: barre)
    }

    /// All sounding positions (open strings included), lowest string first.
    public var positions: [FretboardPosition] {
        strings.enumerated().compactMap { index, action in
            action.fret.map { FretboardPosition(string: index, fret: $0) }
        }
    }

    public var mutedStrings: Set<Int> {
        Set(strings.indices.filter { strings[$0] == .muted })
    }

    /// The pitches that sound when strumming this voicing in the given tuning, lowest first.
    public func pitches(in tuning: Tuning) -> [Pitch] {
        positions.map { tuning.pitch(at: $0) }
    }

    public var lowestFrettedFret: Int? {
        strings.compactMap { $0.fret }.filter { $0 > 0 }.min()
    }

    public var highestFret: Int {
        strings.compactMap { $0.fret }.max() ?? 0
    }
}

/// Built-in voicings for the essential open and first-position chords.
public enum ChordLibrary {
    public static let openChords: [ChordVoicing] = [
        ChordVoicing(id: "E", chord: Chord(.e), frets: "022100", fingers: "023100"),
        ChordVoicing(id: "Em", chord: Chord(.e, .minor), frets: "022000", fingers: "023000"),
        ChordVoicing(id: "E7", chord: Chord(.e, .dominantSeventh), frets: "020100", fingers: "020100"),
        ChordVoicing(id: "A", chord: Chord(.a), frets: "x02220", fingers: "x01230"),
        ChordVoicing(id: "Am", chord: Chord(.a, .minor), frets: "x02210", fingers: "x02310"),
        ChordVoicing(id: "A7", chord: Chord(.a, .dominantSeventh), frets: "x02020", fingers: "x02030"),
        ChordVoicing(id: "Asus2", chord: Chord(.a, .suspendedSecond), frets: "x02200", fingers: "x01200"),
        ChordVoicing(id: "D", chord: Chord(.d), frets: "xx0232", fingers: "xx0132"),
        ChordVoicing(id: "Dm", chord: Chord(.d, .minor), frets: "xx0231", fingers: "xx0231"),
        ChordVoicing(id: "D7", chord: Chord(.d, .dominantSeventh), frets: "xx0212", fingers: "xx0213"),
        ChordVoicing(id: "Dsus4", chord: Chord(.d, .suspendedFourth), frets: "xx0233", fingers: "xx0134"),
        ChordVoicing(id: "G", chord: Chord(.g), frets: "320003", fingers: "210003"),
        ChordVoicing(id: "G7", chord: Chord(.g, .dominantSeventh), frets: "320001", fingers: "320001"),
        ChordVoicing(id: "C", chord: Chord(.c), frets: "x32010", fingers: "x32010"),
        ChordVoicing(id: "C7", chord: Chord(.c, .dominantSeventh), frets: "x32310", fingers: "x32410"),
        ChordVoicing(
            id: "F", chord: Chord(.f), frets: "133211", fingers: "134211",
            barre: ChordVoicing.Barre(fret: 1, fromString: 0, toString: 5)
        ),
        ChordVoicing(id: "B7", chord: Chord(.b, .dominantSeventh), frets: "x21202", fingers: "x21304"),
        ChordVoicing(
            id: "Bm", chord: Chord(.b, .minor), frets: "x24432", fingers: "x13421",
            barre: ChordVoicing.Barre(fret: 2, fromString: 1, toString: 5)
        ),
        ChordVoicing(
            id: "F#m", chord: Chord(.fSharp, .minor), frets: "244222", fingers: "134111",
            barre: ChordVoicing.Barre(fret: 2, fromString: 0, toString: 5)
        ),
    ]

    public static func voicing(id: String) -> ChordVoicing? {
        openChords.first { $0.id == id }
    }
}
