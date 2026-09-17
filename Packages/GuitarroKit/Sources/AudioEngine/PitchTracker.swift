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
        let pipeline = WindowedAnalysisPipeline(
            windowSize: configuration.windowSize,
            hopSize: configuration.hopSize,
            continuation: continuation
        ) { window in
            detector.estimate(window)
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

    public func stop() {
        capture.stop()
        lock.lock()
        let pipeline = self.pipeline
        self.pipeline = nil
        lock.unlock()
        pipeline?.finish()
    }
}
