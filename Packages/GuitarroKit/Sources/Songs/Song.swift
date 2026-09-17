import Foundation
import MusicTheory

/// One bar of a song: one chord for the whole bar, or two chords splitting it in half.
public struct SongBar: Hashable, Sendable, Codable {
    /// Voicing ids from `ChordLibrary`, 1 or 2 entries.
    public let chords: [String]

    public init(_ chords: String...) {
        precondition((1...2).contains(chords.count), "A bar holds one or two chords")
        self.chords = chords
    }

    /// The chord sounding on a given beat (0-based) of a bar with `beatsPerBar` beats.
    public func chord(atBeat beat: Int, beatsPerBar: Int) -> String {
        guard chords.count == 2 else { return chords[0] }
        return beat < (beatsPerBar + 1) / 2 ? chords[0] : chords[1]
    }
}

public struct SongSection: Hashable, Sendable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let bars: [SongBar]

    public init(id: String, name: String, bars: [SongBar]) {
        self.id = id
        self.name = name
        self.bars = bars
    }
}

public struct Song: Hashable, Sendable, Codable, Identifiable {
    public enum Difficulty: Int, Sendable, Codable, Comparable {
        case beginner = 1, easy, intermediate
        public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let id: String
    public let title: String
    public let artist: String
    public let key: String
    public let beatsPerMinute: Int
    public let beatsPerBar: Int
    public let sections: [SongSection]

    public init(id: String, title: String, artist: String, key: String, beatsPerMinute: Int, beatsPerBar: Int = 4, sections: [SongSection]) {
        self.id = id
        self.title = title
        self.artist = artist
        self.key = key
        self.beatsPerMinute = beatsPerMinute
        self.beatsPerBar = beatsPerBar
        self.sections = sections
    }

    /// Distinct chords in order of first appearance.
    public var chordIDs: [String] {
        var seen: [String] = []
        for section in sections {
            for bar in section.bars {
                for chord in bar.chords where !seen.contains(chord) {
                    seen.append(chord)
                }
            }
        }
        return seen
    }

    public var barCount: Int { sections.reduce(0) { $0 + $1.bars.count } }

    /// Beginner: up to three open chords. Easy: open chords only. Intermediate: a barre chord is involved.
    public var difficulty: Difficulty {
        let voicings = chordIDs.compactMap { ChordLibrary.voicing(id: $0) }
        if voicings.contains(where: { $0.barre != nil }) { return .intermediate }
        return chordIDs.count <= 3 ? .beginner : .easy
    }
}
