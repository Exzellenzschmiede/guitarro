import MusicTheory

/// A chord change to practise, identified by the two voicing ids from `ChordLibrary`.
public struct ChordPair: Hashable, Sendable, Codable, Identifiable {
    public let from: String
    public let to: String

    public init(_ from: String, _ to: String) {
        self.from = from
        self.to = to
    }

    public var id: String { "\(from)>\(to)" }

    public init?(id: String) {
        let parts = id.split(separator: ">", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        self.init(parts[0], parts[1])
    }

    public var fromVoicing: ChordVoicing? { ChordLibrary.voicing(id: from) }
    public var toVoicing: ChordVoicing? { ChordLibrary.voicing(id: to) }
}

/// The order in which beginners meet chord changes: easiest and most useful first.
public enum ChordChangeCurriculum {
    public static let beginner: [ChordPair] = [
        ChordPair("Em", "Am"),
        ChordPair("Am", "E"),
        ChordPair("E", "A"),
        ChordPair("A", "D"),
        ChordPair("D", "G"),
        ChordPair("G", "C"),
        ChordPair("C", "Am"),
        ChordPair("G", "Em"),
        ChordPair("D", "A"),
        ChordPair("C", "G"),
        ChordPair("Dm", "Am"),
        ChordPair("A", "E7"),
        ChordPair("G", "D"),
        ChordPair("C", "F"),
        ChordPair("Am", "F"),
        ChordPair("E", "B7"),
        ChordPair("D", "Bm"),
    ]
}
