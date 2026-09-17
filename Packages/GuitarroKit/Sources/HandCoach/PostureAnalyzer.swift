import CoreGraphics
import Foundation

/// What the coach wants to tell the player about the fretting hand.
public enum PostureHint: Sendable, Hashable {
    case noHand
    case moveCloser
    case flatFingers([Finger])
    case thumbOverNeck
    case lookingGood
}

public struct FingerReport: Sendable, Equatable {
    public let finger: Finger
    /// Interior angle at the middle joint in degrees: 180 is dead straight, ~120 nicely arched.
    public let archAngle: Double
    public let isReliable: Bool
    public var isFlat: Bool { isReliable && archAngle > PostureAnalyzer.flatAngle }
}

public struct PostureAssessment: Sendable, Equatable {
    public let fingers: [FingerReport]
    /// `nil` when the thumb is not visible enough to judge.
    public let thumbOverNeck: Bool?
    /// Larger of the hand's bounding-box sides, normalised to the image.
    public let handSize: Double
    public let hints: [PostureHint]

    public func report(for finger: Finger) -> FingerReport? {
        fingers.first { $0.finger == finger }
    }
}

/// Pure geometry on hand landmarks. No Vision dependency, so it is unit-testable.
public struct PostureAnalyzer: Sendable {
    /// Fingers straighter than this (degrees at the PIP and DIP joints) count as flat.
    public static let flatAngle = 162.0
    public var minimumConfidence: Float = 0.3
    /// Hands whose bounding box is smaller than this fraction of the image are too far away.
    public var minimumHandSize = 0.18
    /// How far above the knuckles (in hand sizes) the thumb tip must be to count as wrapped over the neck.
    public var thumbOverNeckMargin = 0.35

    public init() {}

    public func assess(_ hand: HandLandmarks?) -> PostureAssessment {
        guard let hand, let box = hand.boundingBox(minimumConfidence: minimumConfidence) else {
            return PostureAssessment(fingers: [], thumbOverNeck: nil, handSize: 0, hints: [.noHand])
        }
        let handSize = Double(max(box.width, box.height))
        guard handSize >= minimumHandSize else {
            return PostureAssessment(fingers: [], thumbOverNeck: nil, handSize: handSize, hints: [.moveCloser])
        }

        let reports: [FingerReport] = [Finger.index, .middle, .ring, .little].map { finger in
            guard let mcp = hand.joint(finger, .mcp), let pip = hand.joint(finger, .pip),
                  let dip = hand.joint(finger, .dip), let tip = hand.joint(finger, .tip),
                  [mcp, pip, dip, tip].allSatisfy({ $0.confidence >= minimumConfidence })
            else {
                return FingerReport(finger: finger, archAngle: 180, isReliable: false)
            }
            let pipAngle = Self.interiorAngle(at: pip.location, from: mcp.location, to: dip.location)
            let dipAngle = Self.interiorAngle(at: dip.location, from: pip.location, to: tip.location)
            // A finger is only truly flat if both joints are straight.
            return FingerReport(finger: finger, archAngle: max(pipAngle, dipAngle) == 180 ? 180 : min(max(pipAngle, dipAngle), 180), isReliable: true)
        }

        var thumbOverNeck: Bool?
        if let thumbTip = hand.joint(.thumb, .tip), let indexMCP = hand.joint(.index, .mcp),
           thumbTip.confidence >= minimumConfidence, indexMCP.confidence >= minimumConfidence {
            thumbOverNeck = Double(thumbTip.location.y - indexMCP.location.y) > thumbOverNeckMargin * handSize
        }

        var hints: [PostureHint] = []
        let flat = reports.filter(\.isFlat).map(\.finger)
        // One flat outer finger is often just resting; index/middle or two flat fingers are worth a word.
        if flat.contains(.index) || flat.contains(.middle) || flat.count >= 2 {
            hints.append(.flatFingers(flat))
        }
        if thumbOverNeck == true {
            hints.append(.thumbOverNeck)
        }
        if hints.isEmpty {
            hints.append(.lookingGood)
        }
        return PostureAssessment(fingers: reports, thumbOverNeck: thumbOverNeck, handSize: handSize, hints: hints)
    }

    /// Angle in degrees at `vertex` between the segments to `a` and `b`.
    static func interiorAngle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let dot = Double(v1.dx * v2.dx + v1.dy * v2.dy)
        let norms = Double(hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy))
        guard norms > 0 else { return 180 }
        return acos(max(-1, min(1, dot / norms))) * 180 / .pi
    }
}

/// Keeps hints stable: a hint is shown only when it appeared in most of the recent frames.
public struct HintSmoother: Sendable {
    public var windowSize: Int
    public var requiredCount: Int
    private var history: [[PostureHint]] = []

    public init(windowSize: Int = 10, requiredCount: Int = 6) {
        self.windowSize = windowSize
        self.requiredCount = requiredCount
    }

    /// Feeds one frame's hints and returns the hints that are currently stable.
    public mutating func push(_ hints: [PostureHint]) -> [PostureHint] {
        history.append(hints)
        if history.count > windowSize {
            history.removeFirst(history.count - windowSize)
        }
        var counts: [PostureHint: Int] = [:]
        for frame in history {
            for hint in frame {
                counts[hint, default: 0] += 1
            }
        }
        let stable = counts.filter { $0.value >= requiredCount }.map(\.key)
        // Correction hints outrank the reassurance.
        let corrections = stable.filter { $0 != .lookingGood }
        if !corrections.isEmpty { return corrections.sorted(by: Self.priority) }
        return stable
    }

    public mutating func reset() {
        history.removeAll()
    }

    private static func priority(_ lhs: PostureHint, _ rhs: PostureHint) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private static func rank(_ hint: PostureHint) -> Int {
        switch hint {
        case .noHand: 0
        case .moveCloser: 1
        case .flatFingers: 2
        case .thumbOverNeck: 3
        case .lookingGood: 4
        }
    }
}
