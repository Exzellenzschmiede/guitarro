import Foundation
import Testing
import MusicTheory
@testable import AudioEngine
@testable import SongAnalysis

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A synthetic "song": the given chords strummed in turn, each for `seconds`, restruck every beat.
private func renderSong(_ chordIDs: [String], seconds: Double, bpm: Double = 100, sampleRate: Double = 22_050) -> [Float] {
    var generator = SplitMix64(state: 11)
    let frames = Int(sampleRate * seconds * Double(chordIDs.count))
    var output = [Float](repeating: 0, count: frames)
    var voices: [PluckedStringVoice] = []
    let beat = 60 / bpm
    output.withUnsafeMutableBufferPointer { buffer in
        var offset = 0
        var nextStrike = 0.0
        while offset < frames {
            let time = Double(offset) / sampleRate
            if time >= nextStrike {
                let index = min(chordIDs.count - 1, Int(time / seconds))
                let voicing = ChordLibrary.voicing(id: chordIDs[index])!
                for (string, pitch) in voicing.pitches(in: .standard).enumerated() {
                    voices.append(PluckedStringVoice(frequency: pitch.frequency(), sampleRate: sampleRate, velocity: 0.5, startDelay: string * 400, sustain: 1.2, using: &generator))
                }
                nextStrike += beat
            }
            let chunk = min(512, frames - offset)
            for i in voices.indices { voices[i].render(adding: buffer.baseAddress! + offset, frames: chunk) }
            voices.removeAll { !$0.isActive }
            offset += chunk
        }
    }
    return output
}

@Suite struct KeyDetectorTests {
    @Test func findsCMajorFromItsScale() {
        var chroma = [Float](repeating: 0.1, count: 12)
        for pc in [PitchClass.c, .d, .e, .f, .g, .a, .b] { chroma[pc.rawValue] = 1 }
        chroma[PitchClass.c.rawValue] = 1.6
        chroma[PitchClass.g.rawValue] = 1.3
        let key = KeyDetector.detect(chroma: chroma)
        #expect(key == MusicalKey(tonic: .c, mode: .major))
        #expect(MusicalKey(tonic: .a, mode: .minor).scale == MusicalKey(tonic: .c, mode: .major).scale)
        #expect(MusicalKey(tonic: .b, mode: .minor).name(style: .german) == "Hm")
    }
}

@Suite struct ChordSequenceDecoderTests {
    @Test func smoothsSingleFrameBlips() {
        // Candidate 0 dominates, one frame prefers candidate 1: the penalty should keep 0.
        var scores = [[Float]](repeating: [0.9, 0.6], count: 10)
        scores[5] = [0.7, 0.75]
        let path = ChordSequenceDecoder.decode(frameScores: scores, silence: [Bool](repeating: false, count: 10))
        #expect(path == [Int?](repeating: 0, count: 10))
    }

    @Test func followsRealChanges() {
        var scores = [[Float]](repeating: [0.9, 0.5], count: 6)
        scores += [[Float]](repeating: [0.5, 0.9], count: 6)
        let path = ChordSequenceDecoder.decode(frameScores: scores, silence: [Bool](repeating: false, count: 12))
        #expect(path.prefix(6).allSatisfy { $0 == 0 })
        #expect(path.suffix(6).allSatisfy { $0 == 1 })
    }

    @Test func silenceBecomesNoChordAndSegmentsMerge() {
        let scores = [[Float]](repeating: [0.9, 0.5], count: 8)
        let silence = [true, true, false, false, false, false, true, true]
        let path = ChordSequenceDecoder.decode(frameScores: scores, silence: silence)
        #expect(path[0] == nil && path[7] == nil && path[3] == 0)
        let segments = ChordSequenceDecoder.segments(from: path, candidates: [Chord(.c), Chord(.g)], hopSeconds: 0.5, minimumDuration: 0.4)
        #expect(segments.count == 3)
        #expect(segments[1].chord == Chord(.c))
        #expect(abs(segments[1].start - 1.0) < 0.001)
        #expect(abs(segments[1].duration - 2.0) < 0.001)
    }
}

@Suite struct TempoEstimatorTests {
    @Test func findsClickTrackTempo() {
        let sampleRate = 22_050.0
        let bpm = 120.0
        var samples = [Float](repeating: 0, count: Int(sampleRate * 8))
        var t = 0.0
        while t < 8 {
            let start = Int(t * sampleRate)
            for i in 0..<400 where start + i < samples.count {
                samples[start + i] = Float(sin(Double(i) * 0.5)) * Float(1 - Double(i) / 400)
            }
            t += 60 / bpm
        }
        let estimate = TempoEstimator.estimate(samples: samples, sampleRate: sampleRate)
        #expect(estimate != nil)
        #expect(abs(Double(estimate ?? 0) - bpm) <= 3, "got \(String(describing: estimate))")
    }
}

@Suite struct ChordTimelineAnalyzerTests {
    @Test func recoversAStrummedProgression() {
        let progression = ["G", "D", "Em", "C"]
        let samples = renderSong(progression, seconds: 3)
        let analysis = ChordTimelineAnalyzer().analyze(samples: samples)
        let chords = analysis.segments.compactMap(\.chord)
        #expect(analysis.key?.mode == .major)
        #expect(chords.count >= 4, "segments: \(analysis.segments.map { "\($0.chord?.symbol() ?? "–")@\($0.start)" })")
        // Each expected chord should be the chord heard in the middle of its stretch.
        for (index, id) in progression.enumerated() {
            let middle = (Double(index) + 0.5) * 3
            #expect(analysis.segment(at: middle)?.chord == ChordLibrary.voicing(id: id)?.chord, "at \(middle)s: \(String(describing: analysis.segment(at: middle)?.chord))")
        }
        #expect(abs(analysis.duration - 12) < 0.01)
        #expect(analysis.nextChordSegment(after: 1.0)?.chord == Chord(.d))
    }
}

@Suite struct LiveChordTranscriberTests {
    private let candidates = [Chord(.g), Chord(.d), Chord(.e, .minor), Chord(.c)]

    private func frame(time: Double, best: Int?, chroma tonic: PitchClass? = nil) -> LiveChordTranscriber.Frame {
        var scores = [Float](repeating: 0.5, count: 4)
        if let best { scores[best] = 0.9 }
        var chroma = [Float](repeating: 0.1, count: 12)
        if let tonic {
            for pc in candidates[best ?? 0].pitchClasses { chroma[pc.rawValue] = 1 }
            chroma[tonic.rawValue] = 1.2
        }
        return LiveChordTranscriber.Frame(time: time, scores: scores, silence: best == nil, chroma: chroma)
    }

    @Test func buildsSegmentsFromPlayerTimes() {
        var transcriber = LiveChordTranscriber(candidates: candidates)
        var time = 0.0
        for chord in [0, 1, 2, 3] {
            for _ in 0..<24 {
                transcriber.append(frame(time: time, best: chord, chroma: .g))
                time += 0.085
            }
        }
        let analysis = transcriber.finish(duration: 10)
        #expect(analysis.segments.compactMap(\.chord) == candidates)
        #expect(abs(analysis.segments[1].start - 24 * 0.085) < 0.01)
        #expect(abs(analysis.segments.last!.end - 10) < 0.001)
        #expect(analysis.key == MusicalKey(tonic: .g, mode: .major))
    }

    @Test func seekingBackwardsReplacesLaterFrames() {
        var transcriber = LiveChordTranscriber(candidates: candidates)
        for i in 0..<20 { transcriber.append(frame(time: Double(i) * 0.1, best: 0)) }
        transcriber.append(frame(time: 0.5, best: 1))
        #expect(transcriber.frames.count == 6)
        #expect(transcriber.frames.last?.time == 0.5)
    }

    @Test func emptyTranscriptionHasNoSegments() {
        let transcriber = LiveChordTranscriber(candidates: candidates)
        #expect(transcriber.finish(duration: 30).segments.isEmpty)
    }
}
