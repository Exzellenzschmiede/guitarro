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
/// strings apart. Each note is also measured slightly flat and sharp so a guitar that is
/// not perfectly in tune still lands in its bin. Tables are precomputed once.
public struct ChromaAnalyzer: Sendable {
    public let sampleRate: Double
    public let windowSize: Int
    public let lowestMidi: Int
    public let highestMidi: Int
    /// Notes are measured at 0 and ± this offset; the strongest reading counts.
    public let tuningToleranceCents: Double
    /// Strength of the logarithmic compression applied to note magnitudes before they are
    /// summed into pitch classes (0 = linear). Compression lets quiet treble strings count
    /// next to booming bass strings.
    public let compression: Float
    /// Subtract the share of each note's 3rd, 5th and 7th harmonics from the bins they land
    /// in. Off when the matcher models harmonics in its templates instead.
    public let subtractsHarmonics: Bool

    private let cosTables: [[Float]]
    private let sinTables: [[Float]]
    private let offsetCount: Int

    public var noteCount: Int { highestMidi - lowestMidi + 1 }

    public init(
        sampleRate: Double,
        windowSize: Int = 16384,
        lowestMidi: Int = 40,
        highestMidi: Int = 88,
        a4: Double = Pitch.standardA4Frequency,
        tuningToleranceCents: Double = 20,
        compression: Float = 10,
        subtractsHarmonics: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.lowestMidi = lowestMidi
        self.highestMidi = highestMidi
        self.tuningToleranceCents = tuningToleranceCents
        self.compression = compression
        self.subtractsHarmonics = subtractsHarmonics

        var hann = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&hann, vDSP_Length(windowSize), Int32(vDSP_HANN_DENORM))

        let offsets: [Double] = tuningToleranceCents > 0 ? [-tuningToleranceCents, 0, tuningToleranceCents] : [0]
        offsetCount = offsets.count
        var cosTables: [[Float]] = []
        var sinTables: [[Float]] = []
        for midi in lowestMidi...highestMidi {
            for cents in offsets {
                let frequency = Pitch(midiNumber: midi).frequency(a4: a4) * pow(2, cents / 1200)
                let omega = 2 * Double.pi * frequency / sampleRate
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
                var best: Float = 0
                for offset in 0..<offsetCount {
                    let table = note * offsetCount + offset
                    var real: Float = 0
                    var imaginary: Float = 0
                    vDSP_dotpr(base, 1, cosTables[table], 1, &real, n)
                    vDSP_dotpr(base, 1, sinTables[table], 1, &imaginary, n)
                    best = max(best, sqrt(real * real + imaginary * imaginary) * scale)
                }
                magnitudes[note] = best
            }
        }

        var corrected = magnitudes
        if subtractsHarmonics {
            for note in 0..<noteCount {
                let fundamental = magnitudes[note]
                if note + 19 < noteCount { corrected[note + 19] = max(0, corrected[note + 19] - 0.4 * fundamental) }
                if note + 28 < noteCount { corrected[note + 28] = max(0, corrected[note + 28] - 0.25 * fundamental) }
                if note + 34 < noteCount { corrected[note + 34] = max(0, corrected[note + 34] - 0.3 * fundamental) }
            }
        }

        // Compress relative to the loudest note so the profile reflects which notes sound,
        // not only how loud the bass strings are.
        if compression > 0, let peak = corrected.max(), peak > 0 {
            let logDenominator = log1p(compression)
            for note in 0..<noteCount {
                corrected[note] = log1p(compression * corrected[note] / peak) / logDenominator * peak
            }
        }

        var chroma = [Float](repeating: 0, count: 12)
        for note in 0..<noteCount {
            chroma[(lowestMidi + note) % 12] += corrected[note]
        }
        if let peak = chroma.max(), peak > 0 {
            chroma = chroma.map { $0 / peak }
        }
        return ChromaFrame(chroma: chroma, noteMagnitudes: magnitudes, lowestMidi: lowestMidi, rms: rms)
    }
}
