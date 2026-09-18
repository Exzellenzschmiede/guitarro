import Foundation
import MusicTheory
import Testing
@testable import AudioEngine

/// Prints detection rates over synthesized plucks and strums; the expectations are loose so
/// the numbers double as a tuning bench (`swift test --filter DetectionEvaluation`).
@Suite struct DetectionEvaluationTests {
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func renderPluck(midi: Int, velocity: Float, seconds: Double, sampleRate: Double = 48_000, seed: UInt64) -> [Float] {
        var generator = Seeded(state: seed)
        var voice = PluckedStringVoice(frequency: Pitch(midiNumber: midi).frequency(), sampleRate: sampleRate, velocity: velocity, using: &generator)
        var output = [Float](repeating: 0, count: Int(seconds * sampleRate))
        output.withUnsafeMutableBufferPointer { voice.render(adding: $0.baseAddress!, frames: $0.count) }
        return output
    }

    @Test func pluckDetectionRates() {
        let detector = YINPitchDetector(sampleRate: 48_000)
        let notes = [40, 45, 50, 55, 59, 64, 43, 48, 52, 57, 62, 67, 72]
        for velocity: Float in [0.02, 0.05, 0.15, 0.5] {
            var total = 0, voiced = 0, correct = 0, clear75 = 0, clear6 = 0, wrongOctave = 0
            for (index, midi) in notes.enumerated() {
                let audio = renderPluck(midi: midi, velocity: velocity, seconds: 1.5, seed: UInt64(index + 1))
                let target = Pitch(midiNumber: midi).frequency()
                var start = 0
                while start + 4096 <= audio.count {
                    total += 1
                    if let estimate = detector.estimate(Array(audio[start..<start + 4096])) {
                        voiced += 1
                        let ratio = estimate.frequency / target
                        if abs(ratio - 1) < 0.03 {
                            correct += 1
                            if estimate.clarity >= 0.75 { clear75 += 1 }
                            if estimate.clarity >= 0.6 { clear6 += 1 }
                        } else if abs(ratio - 2) < 0.06 || abs(ratio - 0.5) < 0.03 {
                            wrongOctave += 1
                        }
                    }
                    start += 1024
                }
            }
            print("PLUCK v=\(velocity) frames=\(total) voiced=\(voiced) correct=\(correct) clear>=0.75=\(clear75) clear>=0.6=\(clear6) octaveErrors=\(wrongOctave)")
            #expect(correct > total / 2, "velocity \(velocity)")
        }
    }

    @Test func strumDetectionRates() {
        let sampleRate = 48_000.0
        let analyzer = ChromaAnalyzer(sampleRate: sampleRate)
        let matcher = ChordMatcher()
        for velocity: Float in [0.03, 0.08, 0.2, 0.6] {
            var total = 0, recognised = 0, correct = 0
            for (index, id) in ["Em", "Am", "G", "C", "D", "E", "A", "Dm"].enumerated() {
                let voicing = ChordLibrary.voicing(id: id)!
                var generator = Seeded(state: UInt64(index + 11))
                var voices = voicing.pitches(in: .standard).enumerated().map { stringIndex, pitch in
                    PluckedStringVoice(frequency: pitch.frequency(), sampleRate: sampleRate, velocity: velocity, startDelay: stringIndex * 1500, using: &generator)
                }
                var audio = [Float](repeating: 0, count: Int(2.0 * sampleRate))
                audio.withUnsafeMutableBufferPointer { buffer in
                    for i in voices.indices { voices[i].render(adding: buffer.baseAddress!, frames: buffer.count) }
                }
                var start = 0
                while start + 16384 <= audio.count {
                    total += 1
                    if let frame = analyzer.analyze(Array(audio[start..<start + 16384])) {
                        let estimate = matcher.match(frame)
                        if let chord = estimate.chord {
                            recognised += 1
                            if chord == voicing.chord { correct += 1 }
                        }
                    }
                    start += 4096
                }
            }
            print("STRUM v=\(velocity) frames=\(total) recognised=\(recognised) correct=\(correct)")
            #expect(correct > total / 2, "velocity \(velocity)")
        }
    }
}
