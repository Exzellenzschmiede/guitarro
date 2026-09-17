import Foundation

/// One bar of a song laid out on the timeline.
public struct TimelineBar: Hashable, Sendable, Identifiable {
    public let index: Int
    public let sectionIndex: Int
    public let sectionName: String
    public let isSectionStart: Bool
    public let bar: SongBar

    public var id: Int { index }
}

/// A beat to play: which bar, which beat within it, and the chord sounding.
public struct PlaybackBeat: Hashable, Sendable {
    public let barIndex: Int
    public let beat: Int
    public let chordID: String
    public var isDownbeat: Bool { beat == 0 }
}

/// Flattened view of a song's bars with section bookkeeping and loop ranges.
public struct SongTimeline: Sendable, Hashable {
    public let song: Song
    public let bars: [TimelineBar]

    public init(song: Song) {
        self.song = song
        var bars: [TimelineBar] = []
        for (sectionIndex, section) in song.sections.enumerated() {
            for (barInSection, bar) in section.bars.enumerated() {
                bars.append(TimelineBar(
                    index: bars.count,
                    sectionIndex: sectionIndex,
                    sectionName: section.name,
                    isSectionStart: barInSection == 0,
                    bar: bar
                ))
            }
        }
        self.bars = bars
    }

    public var beatsPerBar: Int { song.beatsPerBar }

    /// Bar indices covered by a section, or the whole song when `sectionIndex` is nil.
    public func range(forSection sectionIndex: Int?) -> Range<Int> {
        guard let sectionIndex, song.sections.indices.contains(sectionIndex) else { return 0..<bars.count }
        let start = song.sections[..<sectionIndex].reduce(0) { $0 + $1.bars.count }
        return start..<(start + song.sections[sectionIndex].bars.count)
    }

    /// Every beat of one pass through `range`, in order.
    public func beats(in range: Range<Int>) -> [PlaybackBeat] {
        range.flatMap { barIndex in
            (0..<beatsPerBar).map { beat in
                PlaybackBeat(barIndex: barIndex, beat: beat, chordID: bars[barIndex].bar.chord(atBeat: beat, beatsPerBar: beatsPerBar))
            }
        }
    }

    /// The chord that comes after the given bar (wrapping inside `range`), for a "next chord" preview.
    public func nextChord(after barIndex: Int, in range: Range<Int>) -> String? {
        guard !range.isEmpty else { return nil }
        let current = bars[barIndex].bar.chords.last
        var index = barIndex
        for _ in 0..<range.count {
            index = index + 1 < range.upperBound ? index + 1 : range.lowerBound
            if let first = bars[index].bar.chords.first, first != current { return first }
        }
        return current
    }

    /// Seconds per beat at a tempo scaled by `tempoPercent` (100 = as written).
    public func secondsPerBeat(tempoPercent: Int) -> Double {
        let bpm = Double(song.beatsPerMinute) * Double(max(20, tempoPercent)) / 100
        return 60 / bpm
    }
}
