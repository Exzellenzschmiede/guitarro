import Foundation

/// Captures the microphone and streams chord estimates.
public final class ChordTracker: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var windowSize = 16384
        public var hopSize = 4096
        public var matcher = ChordMatcher()

        public init() {}
    }

    private let capture = AudioCapture()
    private let configuration: Configuration
    private let lock = NSLock()
    private var pipeline: WindowedAnalysisPipeline<ChordEstimate>?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public var isRunning: Bool { capture.isRunning }

    public func start() throws -> AsyncStream<ChordEstimate> {
        let sampleRate = try capture.prepare()
        let analyzer = ChromaAnalyzer(sampleRate: sampleRate, windowSize: configuration.windowSize)
        let matcher = configuration.matcher
        let (stream, continuation) = AsyncStream<ChordEstimate>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let gate = GateBox()
        let pipeline = WindowedAnalysisPipeline(
            windowSize: configuration.windowSize,
            hopSize: configuration.hopSize,
            continuation: continuation
        ) { window in
            guard gate.process(rms: InputMeter.rms(window)), let frame = analyzer.analyze(window) else {
                return ChordEstimate.silence
            }
            return matcher.match(frame)
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
