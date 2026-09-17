import CoreGraphics
import Foundation
import Vision

/// Wraps Vision's hand pose request and converts its output to `HandLandmarks`.
public final class HandPoseDetector: @unchecked Sendable {
    private let request: VNDetectHumanHandPoseRequest

    public init(maximumHands: Int = 2) {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHands
    }

    public func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) throws -> [HandLandmarks] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return try perform(handler)
    }

    public func detect(in image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> [HandLandmarks] {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        return try perform(handler)
    }

    private func perform(_ handler: VNImageRequestHandler) throws -> [HandLandmarks] {
        try handler.perform([request])
        return (request.results ?? []).compactMap(Self.landmarks(from:))
    }

    static func landmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks? {
        guard let points = try? observation.recognizedPoints(.all), let wrist = points[.wrist] else { return nil }
        let joints: [(Finger, [VNHumanHandPoseObservation.JointName])] = [
            (.thumb, [.thumbCMC, .thumbMP, .thumbIP, .thumbTip]),
            (.index, [.indexMCP, .indexPIP, .indexDIP, .indexTip]),
            (.middle, [.middleMCP, .middlePIP, .middleDIP, .middleTip]),
            (.ring, [.ringMCP, .ringPIP, .ringDIP, .ringTip]),
            (.little, [.littleMCP, .littlePIP, .littleDIP, .littleTip]),
        ]
        var fingers: [Finger: [Landmark]] = [:]
        for (finger, names) in joints {
            fingers[finger] = names.map { name in
                guard let point = points[name] else { return Landmark(x: 0, y: 0, confidence: 0) }
                return Landmark(point.location, confidence: point.confidence)
            }
        }
        let chirality: Chirality = switch observation.chirality {
        case .left: .left
        case .right: .right
        default: .unknown
        }
        return HandLandmarks(wrist: Landmark(wrist.location, confidence: wrist.confidence), fingers: fingers, chirality: chirality)
    }
}
