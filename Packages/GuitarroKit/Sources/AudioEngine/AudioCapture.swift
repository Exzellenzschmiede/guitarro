import AVFAudio
import Foundation
import os

public enum AudioCaptureError: Error, Sendable, LocalizedError {
    case microphoneUnavailable
    case engineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .microphoneUnavailable: "No microphone input is available."
        case .engineFailed(let message): message
        }
    }
}

/// Captures mono microphone audio and hands sample blocks to a handler on a background queue.
public final class AudioCapture: @unchecked Sendable {
    private static let logger = Logger(subsystem: "de.kaniut.guitarro", category: "AudioCapture")

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "de.kaniut.guitarro.audio-capture", qos: .userInteractive)
    private let lock = NSLock()
    private var running = false

    public init() {}

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    /// The input sample rate the hardware will deliver. Activates the audio session.
    public func prepare() throws -> Double {
        try AudioSession.activate()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.microphoneUnavailable
        }
        return format.sampleRate
    }

    /// Starts capturing. `handler` receives blocks of roughly `bufferSize` samples.
    public func start(bufferSize: Int, handler: @escaping @Sendable ([Float]) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        precondition(!running, "AudioCapture is already running")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.microphoneUnavailable
        }
        Self.logger.notice("Input format: \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) channel(s)")

        let queue = self.queue
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            queue.async { handler(samples) }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioCaptureError.engineFailed(error.localizedDescription)
        }
        running = true
    }

    public func stop() {
        lock.lock()
        guard running else {
            lock.unlock()
            return
        }
        running = false
        lock.unlock()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    deinit {
        stop()
    }
}

/// Accumulates samples in a ring buffer and runs an analysis once per hop.
/// All mutation happens on the capture queue.
final class WindowedAnalysisPipeline<Output: Sendable>: @unchecked Sendable {
    private let hopSize: Int
    private let analyze: @Sendable ([Float]) -> Output
    private let continuation: AsyncStream<Output>.Continuation
    private var ring: [Float]
    private var window: [Float]
    private var writeIndex = 0
    private var filled = 0
    private var samplesSinceHop = 0

    init(windowSize: Int, hopSize: Int, continuation: AsyncStream<Output>.Continuation, analyze: @escaping @Sendable ([Float]) -> Output) {
        self.hopSize = hopSize
        self.analyze = analyze
        self.continuation = continuation
        ring = [Float](repeating: 0, count: windowSize)
        window = [Float](repeating: 0, count: windowSize)
    }

    /// Feeds samples in and emits one result per hop, even for input buffers larger than a hop.
    func append(_ samples: [Float]) {
        let capacity = ring.count
        for sample in samples {
            ring[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            filled = min(filled + 1, capacity)
            samplesSinceHop += 1
            if filled == capacity, samplesSinceHop >= hopSize {
                samplesSinceHop = 0
                analyseCurrentWindow()
            }
        }
    }

    private func analyseCurrentWindow() {
        let capacity = ring.count
        let tail = capacity - writeIndex
        let start = writeIndex
        window.withUnsafeMutableBufferPointer { target in
            ring.withUnsafeBufferPointer { source in
                guard let targetBase = target.baseAddress, let sourceBase = source.baseAddress else { return }
                targetBase.update(from: sourceBase + start, count: tail)
                (targetBase + tail).update(from: sourceBase, count: start)
            }
        }
        continuation.yield(analyze(window))
    }

    func finish() {
        continuation.finish()
    }
}
