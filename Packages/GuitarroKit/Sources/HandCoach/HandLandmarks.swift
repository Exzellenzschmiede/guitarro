import CoreGraphics
import Foundation

public enum Finger: String, CaseIterable, Sendable, Codable, Hashable {
    case thumb, index, middle, ring, little
}

/// Joints of one finger from the knuckle outwards. The thumb's "pip" is its IP joint.
public enum FingerJoint: Int, CaseIterable, Sendable, Codable {
    case mcp = 0, pip, dip, tip
}

public enum Chirality: String, Sendable, Codable {
    case left, right, unknown
}

/// A 2D landmark in normalised image coordinates (0…1, origin bottom-left, like Vision).
public struct Landmark: Sendable, Equatable, Codable {
    public var location: CGPoint
    public var confidence: Float

    public init(_ location: CGPoint, confidence: Float = 1) {
        self.location = location
        self.confidence = confidence
    }

    public init(x: CGFloat, y: CGFloat, confidence: Float = 1) {
        self.init(CGPoint(x: x, y: y), confidence: confidence)
    }
}

/// The 21 landmarks of one detected hand.
public struct HandLandmarks: Sendable, Equatable, Codable {
    public var wrist: Landmark
    /// Four joints per finger, knuckle first. The thumb uses CMC, MP, IP, TIP.
    public var fingers: [Finger: [Landmark]]
    public var chirality: Chirality

    public init(wrist: Landmark, fingers: [Finger: [Landmark]], chirality: Chirality = .unknown) {
        self.wrist = wrist
        self.fingers = fingers
        self.chirality = chirality
    }

    public func joint(_ finger: Finger, _ joint: FingerJoint) -> Landmark? {
        guard let joints = fingers[finger], joints.count == 4 else { return nil }
        return joints[joint.rawValue]
    }

    public var allLandmarks: [Landmark] {
        [wrist] + Finger.allCases.flatMap { fingers[$0] ?? [] }
    }

    /// Landmarks Vision is reasonably sure about.
    public func reliableLandmarks(minimumConfidence: Float) -> [Landmark] {
        allLandmarks.filter { $0.confidence >= minimumConfidence }
    }

    /// Bounding box of the reliable landmarks, in normalised coordinates.
    public func boundingBox(minimumConfidence: Float = 0.3) -> CGRect? {
        let points = reliableLandmarks(minimumConfidence: minimumConfidence).map(\.location)
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
