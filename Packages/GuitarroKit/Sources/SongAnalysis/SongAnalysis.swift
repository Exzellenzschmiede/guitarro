import Foundation
import MusicTheory

/// One stretch of a song with a single chord (or silence when `chord` is nil).
public struct ChordSegment: Hashable, Sendable, Codable, Identifiable {
    public var start: Double
    public var duration: Double
    public var chord: Chord?

    public init(start: Double, duration: Double, chord: Chord?) {
        self.start = start
        self.duration = duration
        self.chord = chord
    }

    public var end: Double { start + duration }
    public var id: Double { start }

    public func contains(_ time: Double) -> Bool {
        time >= start && time < end
    }
}

public struct MusicalKey: Hashable, Sendable, Codable {
    public enum Mode: String, Sendable, Codable { case major, minor }

    public let tonic: PitchClass
    public let mode: Mode

    public init(tonic: PitchClass, mode: Mode) {
        self.tonic = tonic
        self.mode = mode
    }

    /// Pitch classes of the key's scale.
    public var scale: Set<PitchClass> {
        let steps = mode == .major ? [0, 2, 4, 5, 7, 9, 11] : [0, 2, 3, 5, 7, 8, 10]
        return Set(steps.map { PitchClass(semitone: tonic.rawValue + $0) })
    }

    public func name(style: NoteNamingStyle = .international) -> String {
        tonic.name(style: style) + (mode == .minor ? "m" : "")
    }
}

/// The result of analysing a whole track.
public struct SongAnalysis: Hashable, Sendable, Codable {
    public var duration: Double
    public var key: MusicalKey?
    public var beatsPerMinute: Int?
    public var segments: [ChordSegment]

    public init(duration: Double, key: MusicalKey?, beatsPerMinute: Int?, segments: [ChordSegment]) {
        self.duration = duration
        self.key = key
        self.beatsPerMinute = beatsPerMinute
        self.segments = segments
    }

    public func segment(at time: Double) -> ChordSegment? {
        segments.first { $0.contains(time) }
    }

    /// The next segment with a different chord after `time`.
    public func nextChordSegment(after time: Double) -> ChordSegment? {
        guard let current = segment(at: time) else { return segments.first { $0.start > time && $0.chord != nil } }
        return segments.first { $0.start >= current.end && $0.chord != nil && $0.chord != current.chord }
    }

    /// Distinct chords in order of appearance.
    public var chords: [Chord] {
        var seen: [Chord] = []
        for segment in segments {
            if let chord = segment.chord, !seen.contains(chord) { seen.append(chord) }
        }
        return seen
    }
}
