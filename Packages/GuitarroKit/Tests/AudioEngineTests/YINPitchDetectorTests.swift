import Foundation
import Testing
@testable import AudioEngine

private func synthesize(
    frequency: Double,
    sampleRate: Double = 48_000,
    count: Int = 4096,
    amplitude: Float = 0.5,
    harmonics: [(multiple: Double, amplitude: Float)] = []
) -> [Float] {
    (0..<count).map { i in
        let t = Double(i) / sampleRate
        var value = amplitude * Float(sin(2 * .pi * frequency * t))
        for harmonic in harmonics {
            value += harmonic.amplitude * Float(sin(2 * .pi * frequency * harmonic.multiple * t))
        }
        return value
    }
}

@Suite struct YINPitchDetectorTests {
    let detector = YINPitchDetector(sampleRate: 48_000)

    @Test(arguments: [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 440.0, 659.26])
    func detectsPureTones(frequency: Double) {
        let estimate = detector.estimate(synthesize(frequency: frequency))
        #expect(estimate != nil)
        guard let estimate else { return }
        #expect(abs(estimate.frequency - frequency) / frequency < 0.003)
        #expect(estimate.clarity > 0.9)
    }

    @Test func silenceReturnsNil() {
        #expect(detector.estimate([Float](repeating: 0, count: 4096)) == nil)
        #expect(detector.estimate(synthesize(frequency: 110, amplitude: 0.001)) == nil)
    }

    @Test func tooShortBufferReturnsNil() {
        #expect(detector.estimate(synthesize(frequency: 110, count: 1024)) == nil)
    }

    @Test func harmonicRichToneKeepsFundamental() {
        // A plucked low E has strong upper harmonics; the detector must not jump an octave.
        let signal = synthesize(
            frequency: 82.41,
            amplitude: 0.3,
            harmonics: [(2, 0.5), (3, 0.35), (4, 0.2), (5, 0.1)]
        )
        let estimate = detector.estimate(signal)
        #expect(estimate != nil)
        guard let estimate else { return }
        #expect(abs(estimate.frequency - 82.41) / 82.41 < 0.01)
    }

    @Test func noiseIsRejectedOrUnclear() {
        var generator = SystemRandomNumberGenerator()
        let noise = (0..<4096).map { _ in Float.random(in: -0.5...0.5, using: &generator) }
        let estimate = detector.estimate(noise)
        #expect(estimate == nil || estimate!.clarity < 0.7)
    }

    @Test func respectsReferenceSampleRate() {
        let detector44 = YINPitchDetector(sampleRate: 44_100)
        let estimate = detector44.estimate(synthesize(frequency: 220, sampleRate: 44_100))
        #expect(estimate != nil)
        guard let estimate else { return }
        #expect(abs(estimate.frequency - 220) / 220 < 0.003)
    }
}
