import Foundation

/// Captures the microphone and streams monophonic pitch estimates.
/// A `nil` element means the current window is silent or has no clear pitch.
public final class PitchTracker: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var windowSize = 4096
        public var hopSize = 1024
        public var minimumFrequency = 55.0
        public var maximumFrequency = 1500.0
        public var threshold: Float = 0.15

        public init() {}
    }

    private let capture = AudioCapture()
    private let configuration: Configuration
    private let lock = NSLock()
    private var pipeline: WindowedAnalysisPipeline<PitchEstimate?>?
    private var level = InputLevel()

    /// Level of the most recent window and the gate it had to pass, for meters and hints.
    public struct InputLevel: Sendable, Equatable {
        public var rms: Float = 0
        public var threshold: Float = 0
        public var isOpen = false

        public init(rms: Float = 0, threshold: Float = 0, isOpen: Bool = false) {
            self.rms = rms
            self.threshold = threshold
            self.isOpen = isOpen
        }

        /// RMS in dBFS, clamped to −80.
        public var decibels: Float { rms > 0 ? max(-80, 20 * log10(rms)) : -80 }
    }

    public var inputLevel: InputLevel {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public var isRunning: Bool { capture.isRunning }

    /// Starts capturing. The returned stream ends when `stop()` is called or the consumer cancels.
    public func start() throws -> AsyncStream<PitchEstimate?> {
        let sampleRate = try capture.prepare()
        let detector = YINPitchDetector(
            sampleRate: sampleRate,
            windowSize: configuration.windowSize,
            threshold: configuration.threshold,
            minimumFrequency: configuration.minimumFrequency,
            maximumFrequency: configuration.maximumFrequency
        )
        let (stream, continuation) = AsyncStream<PitchEstimate?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let gate = GateBox()
        let pipeline = WindowedAnalysisPipeline(
            windowSize: configuration.windowSize,
            hopSize: configuration.hopSize,
            continuation: continuation
        ) { [weak self] window in
            let rms = InputMeter.rms(window)
            let open = gate.process(rms: rms)
            self?.setLevel(InputLevel(rms: rms, threshold: gate.threshold, isOpen: open))
            return open ? detector.estimate(window) : nil
        }

        lock.lock()
        self.pipeline = pipeline
        lock.unlock()

        try capture.start(bufferSize: configuration.hopSize) { samples in
            pipeline.append(samples)
        }
        continuation.onTermination = { [weak self] _ in self?.stop() }
        return stream
    }

    private func setLevel(_ newValue: InputLevel) {
        lock.lock()
        level = newValue
        lock.unlock()
    }

    public func stop() {
        capture.stop()
        lock.lock()
        let pipeline = self.pipeline
        self.pipeline = nil
        lock.unlock()
        pipeline?.finish()
    }
}
