import Accelerate
import Foundation

/// Monophonic pitch detector based on the YIN algorithm
/// (de Cheveigné & Kawahara, 2002) with parabolic interpolation.
///
/// The difference function is computed with vDSP dot products, which is fast
/// enough to run on every hop of a live microphone stream.
public struct YINPitchDetector: Sendable {
    public let sampleRate: Double
    public let windowSize: Int
    /// Absolute threshold on the cumulative mean normalised difference. Lower is stricter.
    public let threshold: Float
    public let minimumFrequency: Double
    public let maximumFrequency: Double
    /// Windows with an RMS below this linear level are treated as silence.
    public let silenceThreshold: Float

    public init(
        sampleRate: Double,
        windowSize: Int = 4096,
        threshold: Float = 0.15,
        minimumFrequency: Double = 55,
        maximumFrequency: Double = 1500,
        silenceThreshold: Float = 0.002
    ) {
        precondition(windowSize >= 256, "windowSize must be at least 256 samples")
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.threshold = threshold
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.silenceThreshold = silenceThreshold
    }

    /// Estimates the pitch of `samples`. Only the first `windowSize` samples are used.
    /// Returns `nil` for silence or when no periodicity is found.
    public func estimate(_ input: [Float]) -> PitchEstimate? {
        guard input.count >= windowSize else { return nil }
        let n = windowSize
        let half = n / 2

        // Remove DC and sub-bass rumble (handling noise, room hum) with a one-pole high-pass
        // around 40 Hz; guitar fundamentals start at 82 Hz.
        var samples = [Float](repeating: 0, count: n)
        let alpha = Float(exp(-2 * Double.pi * 40 / sampleRate))
        var previousInput: Float = 0
        var previousOutput: Float = 0
        for i in 0..<n {
            let x = input[i]
            let y = alpha * (previousOutput + x - previousInput)
            samples[i] = y
            previousInput = x
            previousOutput = y
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms >= silenceThreshold else { return nil }

        let tauMin = max(2, Int(sampleRate / maximumFrequency))
        let tauMax = min(half - 1, Int(sampleRate / minimumFrequency))
        guard tauMax > tauMin else { return nil }

        // Prefix sums of squared samples so that the energy of any segment is O(1).
        var squares = [Float](repeating: 0, count: n)
        vDSP_vsq(samples, 1, &squares, 1, vDSP_Length(n))
        var prefix = [Double](repeating: 0, count: n + 1)
        for i in 0..<n {
            prefix[i + 1] = prefix[i] + Double(squares[i])
        }

        // Difference function d(τ) = Σ (x[i] − x[i+τ])² = E(0) + E(τ) − 2·dot(x, x+τ)
        var difference = [Float](repeating: 0, count: tauMax + 1)
        let energy0 = prefix[half]
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for tau in 1...tauMax {
                var dot: Float = 0
                vDSP_dotpr(base, 1, base + tau, 1, &dot, vDSP_Length(half))
                let energyTau = prefix[tau + half] - prefix[tau]
                difference[tau] = Float(max(0, energy0 + energyTau - 2 * Double(dot)))
            }
        }

        // Cumulative mean normalised difference function.
        var cmnd = [Float](repeating: 1, count: tauMax + 1)
        var runningSum: Float = 0
        for tau in 1...tauMax {
            runningSum += difference[tau]
            cmnd[tau] = runningSum > 0 ? difference[tau] * Float(tau) / runningSum : 1
        }

        // Absolute threshold: the first dip below the threshold, followed to its local minimum.
        var tauEstimate = -1
        var tau = tauMin
        while tau <= tauMax {
            if cmnd[tau] < threshold {
                while tau + 1 <= tauMax, cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                tauEstimate = tau
                break
            }
            tau += 1
        }

        if tauEstimate < 0 {
            // No dip below the threshold: fall back to the global minimum if it is at least plausible.
            var minValue = Float.greatestFiniteMagnitude
            var minIndex = tauMin
            for t in tauMin...tauMax where cmnd[t] < minValue {
                minValue = cmnd[t]
                minIndex = t
            }
            guard minValue < 0.5 else { return nil }
            tauEstimate = minIndex
        }

        // Octave guard: a plucked string whose second harmonic is louder than the fundamental
        // produces a shallow first dip at half the true period and a much deeper one at the
        // true period. Only then take the lower octave; for a clean tone both dips are near
        // zero and the shorter period is correct.
        let doubled = tauEstimate * 2
        if doubled + 2 <= tauMax, cmnd[tauEstimate] > 0.06 {
            var lowIndex = doubled
            for t in (doubled - 2)...(doubled + 2) where cmnd[t] < cmnd[lowIndex] {
                lowIndex = t
            }
            if cmnd[lowIndex] < 0.5 * cmnd[tauEstimate] {
                tauEstimate = lowIndex
            }
        }

        // Parabolic interpolation around the minimum for sub-sample precision.
        var refinedTau = Float(tauEstimate)
        if tauEstimate > 1, tauEstimate < tauMax {
            let s0 = cmnd[tauEstimate - 1]
            let s1 = cmnd[tauEstimate]
            let s2 = cmnd[tauEstimate + 1]
            let denominator = 2 * (s0 - 2 * s1 + s2)
            if abs(denominator) > 1e-9 {
                refinedTau += (s0 - s2) / denominator
            }
        }

        let frequency = sampleRate / Double(refinedTau)
        let clarity = max(0, min(1, 1 - cmnd[tauEstimate]))
        return PitchEstimate(frequency: frequency, clarity: clarity, rms: rms)
    }
}
