import Accelerate
import Foundation

/// Estimates tempo from the autocorrelation of an onset-strength envelope.
public enum TempoEstimator {
    public static func estimate(samples: [Float], sampleRate: Double, hop: Int = 512, minimumBPM: Double = 50, maximumBPM: Double = 200) -> Int? {
        guard samples.count > hop * 8 else { return nil }
        // Energy envelope per hop, then half-wave rectified difference = onset strength.
        var energies: [Float] = []
        energies.reserveCapacity(samples.count / hop)
        samples.withUnsafeBufferPointer { buffer in
            var offset = 0
            while offset + hop <= samples.count {
                var rms: Float = 0
                vDSP_rmsqv(buffer.baseAddress! + offset, 1, &rms, vDSP_Length(hop))
                energies.append(rms)
                offset += hop
            }
        }
        guard energies.count > 16 else { return nil }
        var onset = [Float](repeating: 0, count: energies.count)
        for i in 1..<energies.count {
            onset[i] = max(0, energies[i] - energies[i - 1])
        }
        let mean = onset.reduce(0, +) / Float(onset.count)
        onset = onset.map { $0 - mean }

        let hopSeconds = Double(hop) / sampleRate
        let minLag = max(1, Int(60 / maximumBPM / hopSeconds))
        let maxLag = min(onset.count / 2, Int(60 / minimumBPM / hopSeconds))
        guard maxLag > minLag else { return nil }

        var bestLag = minLag
        var bestValue: Float = -.greatestFiniteMagnitude
        onset.withUnsafeBufferPointer { buffer in
            for lag in minLag...maxLag {
                var dot: Float = 0
                vDSP_dotpr(buffer.baseAddress!, 1, buffer.baseAddress! + lag, 1, &dot, vDSP_Length(onset.count - lag))
                // Log-Gaussian prior around 120 BPM (Ellis 2007) breaks the tie between a beat
                // and its double, which score alike for a strictly periodic onset pattern.
                let bpm = 60 / (Double(lag) * hopSeconds)
                let prior = Float(exp(-0.5 * pow(log2(bpm / 120) / 0.9, 2)))
                let value = dot / Float(onset.count - lag) * prior
                if value > bestValue {
                    bestValue = value
                    bestLag = lag
                }
            }
        }
        guard bestValue > 0 else { return nil }
        return Int((60 / (Double(bestLag) * hopSeconds)).rounded())
    }
}
