#if os(iOS)
import AVFoundation
import CoreGraphics
import Foundation
import os

public enum CameraError: Error, Sendable, LocalizedError {
    case permissionDenied
    case noCamera
    case configurationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera access was not granted."
        case .noCamera: "No camera is available on this device."
        case .configurationFailed(let message): message
        }
    }
}

/// One analysed camera frame.
public struct CoachFrame: Sendable {
    public let hands: [HandLandmarks]
    /// Size of the (upright) image the landmarks refer to.
    public let imageSize: CGSize
    public let timestamp: TimeInterval

    public init(hands: [HandLandmarks], imageSize: CGSize, timestamp: TimeInterval) {
        self.hands = hands
        self.imageSize = imageSize
        self.timestamp = timestamp
    }
}

/// Runs the camera and hand detection, streaming analysed frames.
public final class CameraSession: NSObject, @unchecked Sendable {
    public enum Position: Sendable { case front, back }

    private static let logger = Logger(subsystem: "de.kaniut.guitarro", category: "CameraSession")

    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "de.kaniut.guitarro.camera.session")
    private let videoQueue = DispatchQueue(label: "de.kaniut.guitarro.camera.video", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let detector = HandPoseDetector(maximumHands: 2)
    private let lock = NSLock()
    private var continuation: AsyncStream<CoachFrame>.Continuation?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var currentInput: AVCaptureDeviceInput?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var isBusy = false
    private(set) public var position: Position = .front

    public static var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    public static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Configures and starts the camera. The stream ends when `stop()` is called.
    public func start(position: Position) async throws -> AsyncStream<CoachFrame> {
        guard await Self.requestPermission() else { throw CameraError.permissionDenied }
        let (stream, continuation) = AsyncStream<CoachFrame>.makeStream(bufferingPolicy: .bufferingNewest(1))
        lock.withLock { self.continuation = continuation }

        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    try configure(position: position)
                    captureSession.startRunning()
                    done.resume()
                } catch {
                    done.resume(throwing: error)
                }
            }
        }
        continuation.onTermination = { [weak self] _ in self?.stop() }
        return stream
    }

    public func stop() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish()
        sessionQueue.async { [self] in
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    public func switchCamera() {
        let next: Position = position == .front ? .back : .front
        sessionQueue.async { [self] in
            do {
                try configure(position: next)
            } catch {
                Self.logger.error("Switching camera failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Ties rotation handling to the preview layer. Call once the layer exists.
    public func attach(previewLayer: AVCaptureVideoPreviewLayer) {
        lock.withLock { self.previewLayer = previewLayer }
        sessionQueue.async { [self] in refreshRotationCoordinator() }
    }

    /// The current preview rotation, for views that lay out the preview themselves.
    public var previewRotationAngle: CGFloat {
        lock.withLock { rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 0 }
    }

    /// Session queue. Rebuilds the rotation coordinator for the current device and preview layer.
    private func refreshRotationCoordinator() {
        let (device, layer) = lock.withLock { (currentInput?.device, previewLayer) }
        guard let device, let layer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        lock.withLock { rotationCoordinator = coordinator }
        DispatchQueue.main.async { [self] in applyPreviewRotation() }
    }

    private func applyPreviewRotation() {
        let (layer, angle) = lock.withLock { (previewLayer, rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 0) }
        guard let connection = layer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    // MARK: Configuration (session queue)

    private func configure(position: Position) throws {
        let avPosition: AVCaptureDevice.Position = position == .front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition) else {
            throw CameraError.noCamera
        }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let currentInput {
            captureSession.removeInput(currentInput)
            lock.withLock { self.currentInput = nil }
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.configurationFailed(error.localizedDescription)
        }
        guard captureSession.canAddInput(input) else { throw CameraError.configurationFailed("Cannot add camera input") }
        captureSession.sessionPreset = .hd1280x720
        captureSession.addInput(input)
        lock.withLock { currentInput = input }
        self.position = position

        if !captureSession.outputs.contains(output) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            guard captureSession.canAddOutput(output) else { throw CameraError.configurationFailed("Cannot add video output") }
            captureSession.addOutput(output)
        }
        if let connection = output.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
        refreshRotationCoordinator()
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lock.lock()
        guard !isBusy, let continuation else {
            lock.unlock()
            return
        }
        isBusy = true
        lock.unlock()
        defer {
            lock.lock()
            isBusy = false
            lock.unlock()
        }

        // Keep the analysed frames upright, matching the preview.
        if let coordinator = lock.withLock({ rotationCoordinator }) {
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let hands = (try? detector.detect(in: pixelBuffer)) ?? []
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        continuation.yield(CoachFrame(hands: hands, imageSize: size, timestamp: timestamp))
    }
}
#endif
