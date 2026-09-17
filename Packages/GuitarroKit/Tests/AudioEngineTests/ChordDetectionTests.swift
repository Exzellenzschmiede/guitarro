import Testing
import MusicTheory
@testable import AudioEngine

/// Renders a strummed chord with the Karplus-Strong synth: realistic harmonics, worst case for chroma.
/// Small deterministic generator so every test run hears the same strum.
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

private func strum(_ voicingID: String, sampleRate: Double = 48_000, seconds: Double = 1.0, seed: UInt64 = 7) -> [Float] {
    let voicing = ChordLibrary.voicing(id: voicingID)!
    var generator = SplitMix64(state: seed)
    var voices = voicing.pitches(in: .standard).enumerated().map { index, pitch in
        PluckedStringVoice(frequency: pitch.frequency(), sampleRate: sampleRate, velocity: 0.6, startDelay: index * 1500, using: &generator)
    }
    let frames = Int(sampleRate * seconds)
    var output = [Float](repeating: 0, count: frames)
    output.withUnsafeMutableBufferPointer { buffer in
        var offset = 0
        while offset < frames {
            let chunk = min(1024, frames - offset)
            for i in voices.indices {
                voices[i].render(adding: buffer.baseAddress! + offset, frames: chunk)
            }
            offset += chunk
        }
    }
    return output
}

@Suite struct ChordDetectionTests {
    private static let analyzer = ChromaAnalyzer(sampleRate: 48_000)
    private let matcher = ChordMatcher()

    private func detect(_ samples: [Float], offset: Int = 12_000) -> ChordEstimate {
        let window = Array(samples[offset..<(offset + Self.analyzer.windowSize)])
        return matcher.match(Self.analyzer.analyze(window)!)
    }

    @Test(arguments: ["E", "Em", "A", "Am", "D", "Dm", "G", "C", "F", "E7", "A7", "B7", "Bm"], [UInt64(1), 7, 42])
    func recognisesStrummedOpenChords(id: String, seed: UInt64) {
        let voicing = ChordLibrary.voicing(id: id)!
        let estimate = detect(strum(id, seed: seed))
        #expect(estimate.chord == voicing.chord, "\(id) seed \(seed): got \(String(describing: estimate.chord)) at \(estimate.confidence)")
    }

    @Test func chromaPeaksOnChordTones() {
        let frame = Self.analyzer.analyze(Array(strum("Am")[12_000..<(12_000 + 16384)]))!
        let chordTones: Set<Int> = [PitchClass.a.rawValue, PitchClass.c.rawValue, PitchClass.e.rawValue]
        for (index, value) in frame.chroma.enumerated() where !chordTones.contains(index) {
            #expect(value < 0.6, "non-chord tone \(index) too strong: \(value)")
        }
        #expect(frame.chroma[PitchClass.a.rawValue] > 0.5)
        #expect(frame.chroma[PitchClass.e.rawValue] > 0.3)
    }

    @Test func silenceIsNotAChord() {
        let frame = Self.analyzer.analyze([Float](repeating: 0, count: 16384))!
        #expect(matcher.match(frame).chord == nil)
    }

    @Test func singleNoteIsNotAChord() {
        var generator = SplitMix64(state: 3)
        var voice = PluckedStringVoice(frequency: Pitch(.a, octave: 2).frequency(), sampleRate: 48_000, velocity: 0.8, using: &generator)
        var output = [Float](repeating: 0, count: 48_000)
        output.withUnsafeMutableBufferPointer { voice.render(adding: $0.baseAddress!, frames: 48_000) }
        let estimate = detect(output)
        #expect(estimate.chord == nil, "single note read as \(String(describing: estimate.chord)) at \(estimate.confidence)")
    }
}
