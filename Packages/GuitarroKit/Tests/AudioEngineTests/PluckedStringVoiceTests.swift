import Testing
@testable import AudioEngine

@Suite struct PluckedStringVoiceTests {
    private func render(frequency: Double, seconds: Double, sampleRate: Double = 48_000) -> ([Float], PluckedStringVoice) {
        var voice = PluckedStringVoice(frequency: frequency, sampleRate: sampleRate, velocity: 0.8)
        let frames = Int(sampleRate * seconds)
        var output = [Float](repeating: 0, count: frames)
        output.withUnsafeMutableBufferPointer { buffer in
            var offset = 0
            while offset < frames {
                let chunk = min(512, frames - offset)
                voice.render(adding: buffer.baseAddress! + offset, frames: chunk)
                offset += chunk
            }
        }
        return (output, voice)
    }

    @Test(arguments: [82.41, 110.0, 220.0, 329.63, 659.26])
    func producesTheRequestedPitch(frequency: Double) {
        let (output, _) = render(frequency: frequency, seconds: 0.5)
        // Skip the noisy attack, analyse the sustained part.
        let window = Array(output[4096..<(4096 + 4096)])
        let detector = YINPitchDetector(sampleRate: 48_000)
        let estimate = detector.estimate(window)
        #expect(estimate != nil)
        guard let estimate else { return }
        #expect(abs(estimate.frequency - frequency) / frequency < 0.01, "\(frequency) Hz read as \(estimate.frequency)")
    }

    @Test func decaysAndBecomesInactive() {
        let (output, voice) = render(frequency: 220, seconds: 6)
        #expect(!voice.isActive)
        let early = output[1000..<3000].map(abs).max() ?? 0
        let late = output[(output.count - 3000)..<(output.count - 1000)].map(abs).max() ?? 0
        #expect(early > 0.05)
        #expect(late < 0.001)
    }

    @Test func startDelayPostponesTheAttack() {
        var voice = PluckedStringVoice(frequency: 220, sampleRate: 48_000, velocity: 0.8, startDelay: 1000)
        var output = [Float](repeating: 0, count: 2000)
        output.withUnsafeMutableBufferPointer { buffer in
            voice.render(adding: buffer.baseAddress!, frames: 2000)
        }
        #expect(output[0..<1000].allSatisfy { $0 == 0 })
        #expect(output[1000..<2000].contains { $0 != 0 })
        #expect(voice.isActive)
    }
}
