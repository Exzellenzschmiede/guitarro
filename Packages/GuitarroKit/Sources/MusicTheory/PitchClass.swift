/// One of the twelve pitch classes of the chromatic scale.
public enum PitchClass: Int, CaseIterable, Sendable, Codable, Hashable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    /// Creates a pitch class from any semitone offset (wraps around the octave).
    public init(semitone: Int) {
        self = PitchClass(rawValue: ((semitone % 12) + 12) % 12)!
    }

    public var isNatural: Bool {
        switch self {
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp: false
        default: true
        }
    }

    /// The display name, e.g. "C♯" or "H" (German style for B).
    public func name(style: NoteNamingStyle = .international, accidentals: AccidentalStyle = .sharps) -> String {
        let sharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let flats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
        var name = (accidentals == .sharps ? sharps : flats)[rawValue]
        if style == .german {
            switch name {
            case "B": name = "H"
            case "B♭": name = "B"
            default: break
            }
        }
        return name
    }
}

/// How note names are spelled. German-speaking countries write B as "H" and B♭ as "B".
public enum NoteNamingStyle: String, Sendable, Codable, CaseIterable {
    case international
    case german
}

public enum AccidentalStyle: String, Sendable, Codable, CaseIterable {
    case sharps
    case flats
}
