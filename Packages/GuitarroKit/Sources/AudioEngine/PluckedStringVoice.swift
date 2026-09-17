import Foundation

/// One Karplus-Strong string: a noise burst circulating through a fractional delay line
/// with a gentle low-pass filter, which decays into a plucked-string tone.
struct PluckedStringVoice: Sendable {
    private var buffer: [Float]
    private var writeIndex = 0
    private var previous: Float = 0
    private let delay: Float
    private let decay: Float
    private var startDelay: Int
    private var quietFrames = 0
    private(set) var isActive = true

    /// - Parameters:
    ///   - frequency: fundamental in Hz
    ///   - sampleRate: output sample rate
    ///   - velocity: 0…1, scales the excitation
    ///   - startDelay: frames to wait before the pluck starts (used for strums)
    ///   - sustain: seconds until the tone has decayed to roughly −40 dB
    init(frequency: Double, sampleRate: Double, velocity: Float = 0.8, startDelay: Int = 0, sustain: Double = 2.5) {
        var generator = SystemRandomNumberGenerator()
        self.init(frequency: frequency, sampleRate: sampleRate, velocity: velocity, startDelay: startDelay, sustain: sustain, using: &generator)
    }

    /// Deterministic variant: the excitation noise comes from `generator`.
    init<G: RandomNumberGenerator>(frequency: Double, sampleRate: Double, velocity: Float = 0.8, startDelay: Int = 0, sustain: Double = 2.5, using generator: inout G) {
        // The two-point average in the loop adds half a sample of delay.
        let loopLength = max(2, sampleRate / max(20, frequency) - 0.5)
        delay = Float(loopLength)
        decay = Float(pow(0.01, 1 / (max(20, frequency) * sustain)))
        self.startDelay = max(0, startDelay)

        let count = Int(loopLength.rounded(.up)) + 2
        var noise = (0..<count).map { _ in Float.random(in: -1...1, using: &generator) * velocity }
        // One smoothing pass takes the harshest edge off the excitation.
        for i in 0..<(count - 1) {
            noise[i] = 0.5 * (noise[i] + noise[i + 1])
        }
        buffer = noise
    }

    /// Adds this voice's output to `output`.
    mutating func render(adding output: UnsafeMutablePointer<Float>, frames: Int) {
        var frame = 0
        if startDelay > 0 {
            let skipped = min(startDelay, frames)
            startDelay -= skipped
            frame = skipped
        }
        guard frame < frames else { return }

        let count = buffer.count
        let length = Float(count)
        var peak: Float = 0
        while frame < frames {
            var readPosition = Float(writeIndex) - delay
            if readPosition < 0 { readPosition += length }
            let index0 = Int(readPosition)
            let fraction = readPosition - Float(index0)
            let index1 = index0 + 1 == count ? 0 : index0 + 1
            let sample = buffer[index0] * (1 - fraction) + buffer[index1] * fraction

            buffer[writeIndex] = decay * 0.5 * (sample + previous)
            previous = sample
            writeIndex = writeIndex + 1 == count ? 0 : writeIndex + 1

            output[frame] += sample
            peak = max(peak, abs(sample))
            frame += 1
        }

        if peak < 0.0005 {
            quietFrames += frames
            if quietFrames > 4096 { isActive = false }
        } else {
            quietFrames = 0
        }
    }
}
