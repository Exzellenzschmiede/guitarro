import AVFAudio
import Foundation
import os

/// Plays plucked-string tones through the speaker. Polyphonic, low latency.
public final class TonePlayer: @unchecked Sendable {
    private static let maximumVoices = 8

    private let engine = AVAudioEngine()
    private let voices = OSAllocatedUnfairLock(initialState: [PluckedStringVoice]())
    private let sourceNode: AVAudioSourceNode
    public let sampleRate: Double

    public init() {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        sampleRate = hardwareRate > 0 ? hardwareRate : 48_000
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let voices = self.voices

        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let output = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let frames = Int(frameCount)
            output.update(repeating: 0, count: frames)
            voices.withLockUnchecked { bank in
                for index in bank.indices {
                    bank[index].render(adding: output, frames: frames)
                }
                bank.removeAll { !$0.isActive }
            }
            for index in 0..<frames {
                output[index] = max(-1, min(1, output[index] * 0.6))
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    /// Plucks a single string.
    public func pluck(frequency: Double, velocity: Float = 0.8, delay: TimeInterval = 0) {
        ensureRunning()
        let voice = PluckedStringVoice(
            frequency: frequency,
            sampleRate: sampleRate,
            velocity: velocity,
            startDelay: Int(delay * sampleRate)
        )
        voices.withLock { bank in
            bank.append(voice)
            if bank.count > Self.maximumVoices {
                bank.removeFirst(bank.count - Self.maximumVoices)
            }
        }
    }

    /// A short metronome click. Accented clicks are higher and louder.
    public func click(accent: Bool = false) {
        ensureRunning()
        let voice = PluckedStringVoice(
            frequency: accent ? 2000 : 1500,
            sampleRate: sampleRate,
            velocity: accent ? 0.9 : 0.6,
            sustain: 0.05
        )
        voices.withLock { bank in
            bank.append(voice)
            if bank.count > Self.maximumVoices {
                bank.removeFirst(bank.count - Self.maximumVoices)
            }
        }
    }

    /// Strums several strings, lowest first, with a short gap between them.
    public func strum(frequencies: [Double], spacing: TimeInterval = 0.045, velocity: Float = 0.7, delay: TimeInterval = 0) {
        for (index, frequency) in frequencies.enumerated() {
            pluck(frequency: frequency, velocity: velocity, delay: delay + Double(index) * spacing)
        }
    }

    public func stop() {
        voices.withLock { $0.removeAll() }
        engine.stop()
    }

    private func ensureRunning() {
        guard !engine.isRunning else { return }
        try? AudioSession.activate()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            Logger(subsystem: "de.kaniut.guitarro", category: "TonePlayer").error("Could not start playback: \(error.localizedDescription, privacy: .public)")
        }
    }
}
