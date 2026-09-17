import AudioEngine
import Foundation
import MusicTheory

/// Analyses decoded audio into a chord timeline, key and tempo.
public struct ChordTimelineAnalyzer: Sendable {
    public var sampleRate: Double
    public var windowSize: Int
    public var hopSize: Int
    public var minimumSegmentDuration: Double
    public var switchPenalty: Float
    /// Bonus for chords that fit the detected key.
    public var keyBonus: Float
    public var candidates: [Chord]

    public init(sampleRate: Double = 22_050, windowSize: Int = 8192, hopSize: Int = 4096, minimumSegmentDuration: Double = 0.4, switchPenalty: Float = 0.12, keyBonus: Float = 0.06, candidates: [Chord] = ChordMatcher.defaultCandidates) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.minimumSegmentDuration = minimumSegmentDuration
        self.switchPenalty = switchPenalty
        self.keyBonus = keyBonus
        self.candidates = candidates
    }

    /// `progress` receives 0…1 as frames are analysed.
    public func analyze(samples: [Float], progress: (@Sendable (Double) -> Void)? = nil) -> SongAnalysis {
        let duration = Double(samples.count) / sampleRate
        let analyzer = ChromaAnalyzer(sampleRate: sampleRate, windowSize: windowSize)
        let matcher = ChordMatcher(candidates: candidates)
        let hopSeconds = Double(hopSize) / sampleRate

        var frames: [ChromaFrame] = []
        var offset = 0
        let total = max(1, (samples.count - windowSize) / hopSize + 1)
        while offset + windowSize <= samples.count {
            if let frame = analyzer.analyze(Array(samples[offset..<(offset + windowSize)])) {
                frames.append(frame)
            }
            offset += hopSize
            if frames.count % 50 == 0 { progress?(Double(frames.count) / Double(total) * 0.9) }
        }
        guard !frames.isEmpty else {
            return SongAnalysis(duration: duration, key: nil, beatsPerMinute: nil, segments: [])
        }

        // Key from the loud frames' summed chroma.
        var summed = [Float](repeating: 0, count: 12)
        for frame in frames where frame.rms >= matcher.minimumRMS {
            for i in 0..<12 { summed[i] += frame.chroma[i] }
        }
        let key = KeyDetector.detect(chroma: summed)
        let diatonic = key?.scale ?? []

        let frameScores = frames.map { frame -> [Float] in
            var scores = matcher.scores(for: frame.chroma)
            if !diatonic.isEmpty {
                for (index, chord) in candidates.enumerated() where Set(chord.pitchClasses).isSubset(of: diatonic) {
                    scores[index] += keyBonus
                }
            }
            return scores
        }
        let silence = frames.map { $0.rms < matcher.minimumRMS }
        let path = ChordSequenceDecoder.decode(frameScores: frameScores, silence: silence, switchPenalty: switchPenalty)
        var segments = ChordSequenceDecoder.segments(from: path, candidates: candidates, hopSeconds: hopSeconds, minimumDuration: minimumSegmentDuration)
        // Stretch the last segment to the real end of the track.
        if var last = segments.popLast() {
            last.duration = max(last.duration, duration - last.start)
            segments.append(last)
        }
        let bpm = TempoEstimator.estimate(samples: samples, sampleRate: sampleRate)
        progress?(1)
        return SongAnalysis(duration: duration, key: key, beatsPerMinute: bpm, segments: segments)
    }
}
