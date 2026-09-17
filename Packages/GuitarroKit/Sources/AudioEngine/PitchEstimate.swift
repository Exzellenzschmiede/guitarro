/// The result of analysing one window of audio.
public struct PitchEstimate: Sendable, Equatable {
    /// Fundamental frequency in Hz.
    public let frequency: Double
    /// Confidence in the estimate, 0…1. Values above ~0.8 are reliable for tuning.
    public let clarity: Float
    /// RMS level of the analysed window (linear, 0…1).
    public let rms: Float

    public init(frequency: Double, clarity: Float, rms: Float) {
        self.frequency = frequency
        self.clarity = clarity
        self.rms = rms
    }
}
