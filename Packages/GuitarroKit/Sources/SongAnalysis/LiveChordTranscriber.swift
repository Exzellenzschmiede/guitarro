import Foundation
import MusicTheory

/// Collects microphone chord estimates while a track plays elsewhere (e.g. the system music
/// player) and turns them into a chord timeline keyed to the player's clock.
public struct LiveChordTranscriber: Sendable {
    public struct Frame: Sendable, Hashable {
        public let time: Double
        public let scores: [Float]
        public let silence: Bool
        public let chroma: [Float]

        public init(time: Double, scores: [Float], silence: Bool, chroma: [Float]) {
            self.time = time
            self.scores = scores
            self.silence = silence
            self.chroma = chroma
        }
    }

    public let candidates: [Chord]
    public var minimumSegmentDuration: Double
    public var switchPenalty: Float
    public var keyBonus: Float
    private(set) public var frames: [Frame] = []

    public init(candidates: [Chord], minimumSegmentDuration: Double = 0.5, switchPenalty: Float = 0.12, keyBonus: Float = 0.06) {
        self.candidates = candidates
        self.minimumSegmentDuration = minimumSegmentDuration
        self.switchPenalty = switchPenalty
        self.keyBonus = keyBonus
    }

    public var isEmpty: Bool { frames.isEmpty }

    /// Adds a frame. Frames arriving out of order (after a seek backwards) replace what was there.
    public mutating func append(_ frame: Frame) {
        if let last = frames.last, frame.time < last.time {
            frames.removeAll { $0.time >= frame.time }
        }
        frames.append(frame)
    }

    public mutating func reset() {
        frames.removeAll()
    }

    /// Builds the analysis. `duration` is the track length reported by the player.
    public func finish(duration: Double) -> SongAnalysis {
        guard frames.count > 1 else {
            return SongAnalysis(duration: duration, key: nil, beatsPerMinute: nil, segments: [])
        }
        var summed = [Float](repeating: 0, count: 12)
        for frame in frames where !frame.silence {
            for i in 0..<12 { summed[i] += frame.chroma[i] }
        }
        let key = KeyDetector.detect(chroma: summed)
        let diatonic = key?.scale ?? []
        let width = frames[0].scores.count
        let frameScores = frames.map { frame -> [Float] in
            var scores = frame.scores.count == width ? frame.scores : [Float](repeating: 0, count: width)
            if !diatonic.isEmpty {
                for (index, chord) in candidates.enumerated() where index < width && Set(chord.pitchClasses).isSubset(of: diatonic) {
                    scores[index] += keyBonus
                }
            }
            return scores
        }
        let path = ChordSequenceDecoder.decode(frameScores: frameScores, silence: frames.map(\.silence), switchPenalty: switchPenalty)

        // Segments from runs of equal states, using the real frame times.
        var raw: [ChordSegment] = []
        var runStart = frames[0].time
        var runState = path[0]
        for index in 1..<path.count where path[index] != runState {
            raw.append(ChordSegment(start: runStart, duration: frames[index].time - runStart, chord: runState.map { candidates[$0] }))
            runStart = frames[index].time
            runState = path[index]
        }
        raw.append(ChordSegment(start: runStart, duration: max(0.1, duration - runStart), chord: runState.map { candidates[$0] }))

        // Absorb blips shorter than the minimum into their predecessor.
        var merged: [ChordSegment] = []
        for segment in raw {
            if segment.duration < minimumSegmentDuration, !merged.isEmpty {
                merged[merged.count - 1].duration += segment.duration
            } else if let last = merged.last, last.chord == segment.chord {
                merged[merged.count - 1].duration += segment.duration
            } else {
                merged.append(segment)
            }
        }
        return SongAnalysis(duration: duration, key: key, beatsPerMinute: nil, segments: merged)
    }
}
