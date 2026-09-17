#if DEBUG
import AudioEngine
import Foundation
import MusicTheory

/// Renders a strummed chord progression to samples (simulator demo only).
enum DemoSongRenderer {
    static func render(chordIDs: [String], secondsPerChord: Double, bpm: Double, sampleRate: Double) -> [Float] {
        let frames = Int(sampleRate * secondsPerChord * Double(chordIDs.count))
        var output = [Float](repeating: 0, count: frames)
        var voices: [PluckedStringVoice] = []
        let beat = 60 / bpm
        output.withUnsafeMutableBufferPointer { buffer in
            var offset = 0
            var nextStrike = 0.0
            while offset < frames {
                let time = Double(offset) / sampleRate
                if time >= nextStrike {
                    let index = min(chordIDs.count - 1, Int(time / secondsPerChord))
                    if let voicing = ChordLibrary.voicing(id: chordIDs[index]) {
                        for (string, pitch) in voicing.pitches(in: .standard).enumerated() {
                            voices.append(PluckedStringVoice(frequency: pitch.frequency(), sampleRate: sampleRate, velocity: 0.5, startDelay: string * 400, sustain: 1.2))
                        }
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
}

/// Minimal 16-bit PCM WAV writer.
enum WAVWriter {
    static func write(samples: [Float], sampleRate: Double, to url: URL) throws {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        let byteRate = UInt32(sampleRate) * 2
        let dataSize = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(byteRate); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(dataSize)
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * 32767))
        }
        try data.write(to: url)
    }
}
#endif
