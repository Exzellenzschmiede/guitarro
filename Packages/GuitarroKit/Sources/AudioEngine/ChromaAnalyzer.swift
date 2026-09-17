import Accelerate
import Foundation
import MusicTheory

/// One analysed window: per-note magnitudes and the 12-bin pitch-class profile.
public struct ChromaFrame: Sendable, Equatable {
    /// Normalised 0…1, index = `PitchClass.rawValue`.
    public let chroma: [Float]
    /// Linear magnitude per note from `lowestMidi` upwards.
    public let noteMagnitudes: [Float]
    public let lowestMidi: Int
    public let rms: Float
}

/// Computes a pitch-class profile (chromagram) by projecting a Hann-windowed frame onto
/// sine/cosine pairs tuned to every semitone of the guitar's range.
///
/// Compared with an FFT this puts every bin exactly on a note, which keeps the low
/// strings apart. Tables are precomputed once; each frame costs ~100 dot products.
public struct ChromaAnalyzer: Sendable {
    public let sampleRate: Double
    public let windowSize: Int
    public let lowestMidi: Int
    public let highestMidi: Int

    private let cosTables: [[Float]]
    private let sinTables: [[Float]]

    public var noteCount: Int { highestMidi - lowestMidi + 1 }

    public init(sampleRate: Double, windowSize: Int = 16384, lowestMidi: Int = 40, highestMidi: Int = 88, a4: Double = Pitch.standardA4Frequency) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.lowestMidi = lowestMidi
        self.highestMidi = highestMidi

        var hann = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&hann, vDSP_Length(windowSize), Int32(vDSP_HANN_DENORM))

        var cosTables: [[Float]] = []
        var sinTables: [[Float]] = []
        for midi in lowestMidi...highestMidi {
            let omega = 2 * Double.pi * Pitch(midiNumber: midi).frequency(a4: a4) / sampleRate
            var cosine = [Float](repeating: 0, count: windowSize)
            var sine = [Float](repeating: 0, count: windowSize)
            for i in 0..<windowSize {
                let phase = omega * Double(i)
                cosine[i] = hann[i] * Float(cos(phase))
                sine[i] = hann[i] * Float(sin(phase))
            }
            cosTables.append(cosine)
            sinTables.append(sine)
        }
        self.cosTables = cosTables
        self.sinTables = sinTables
    }

    /// Analyses the first `windowSize` samples.
    public func analyze(_ samples: [Float]) -> ChromaFrame? {
        guard samples.count >= windowSize else { return nil }
        let n = vDSP_Length(windowSize)

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, n)

        var magnitudes = [Float](repeating: 0, count: noteCount)
        let scale = 4 / Float(windowSize)
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for note in 0..<noteCount {
                var real: Float = 0
                var imaginary: Float = 0
                vDSP_dotpr(base, 1, cosTables[note], 1, &real, n)
                vDSP_dotpr(base, 1, sinTables[note], 1, &imaginary, n)
                magnitudes[note] = sqrt(real * real + imaginary * imaginary) * scale
            }
        }

        // Harmonic correction: a plucked string's 3rd and 5th harmonics land a fifth and a
        // major third above its octaves. Subtract the expected share so they do not masquerade
        // as chord tones (the 3rd harmonic of E would otherwise read as B).
        var corrected = magnitudes
        for note in 0..<noteCount {
            let fundamental = magnitudes[note]
            if note + 19 < noteCount { corrected[note + 19] = max(0, corrected[note + 19] - 0.4 * fundamental) }
            if note + 28 < noteCount { corrected[note + 28] = max(0, corrected[note + 28] - 0.25 * fundamental) }
            // 7th harmonic sits a flat minor seventh above (+33.7 semitones) and mimics a 7th chord.
            if note + 34 < noteCount { corrected[note + 34] = max(0, corrected[note + 34] - 0.3 * fundamental) }
        }

        var chroma = [Float](repeating: 0, count: 12)
        for note in 0..<noteCount {
            // Bass notes carry the root on guitar: weight the lowest octave a little more.
            let weight: Float = lowestMidi + note < 52 ? 1.25 : 1
            chroma[(lowestMidi + note) % 12] += corrected[note] * weight
        }
        if let peak = chroma.max(), peak > 0 {
            chroma = chroma.map { $0 / peak }
        }
        return ChromaFrame(chroma: chroma, noteMagnitudes: magnitudes, lowestMidi: lowestMidi, rms: rms)
    }
}
