import CoreGraphics
import Testing
@testable import HandCoach

/// Builds a synthetic upright hand: wrist at the bottom, fingers pointing up,
/// each finger bent by `bend` degrees at the PIP and DIP joints (0 = straight).
private func makeHand(bend: Double, scale: CGFloat = 1, thumbTipY: CGFloat? = nil, confidence: Float = 0.9) -> HandLandmarks {
    let wrist = CGPoint(x: 0.5, y: 0.2)
    let segment = 0.08 * scale
    var fingers: [Finger: [Landmark]] = [:]
    for (index, finger) in [Finger.index, .middle, .ring, .little].enumerated() {
        let mcp = CGPoint(x: 0.42 + CGFloat(index) * 0.055 * scale, y: 0.2 + 0.28 * scale)
        var points = [mcp]
        var direction = 90.0
        var current = mcp
        for _ in 0..<3 {
            let radians = direction * .pi / 180
            current = CGPoint(x: current.x + segment * CGFloat(cos(radians)), y: current.y + segment * CGFloat(sin(radians)))
            points.append(current)
            direction -= bend
        }
        fingers[finger] = points.map { Landmark($0, confidence: confidence) }
    }
    let thumbBase = CGPoint(x: 0.36, y: 0.2 + 0.12 * scale)
    let tipY = thumbTipY ?? (0.2 + 0.3 * scale)
    fingers[.thumb] = [
        Landmark(thumbBase, confidence: confidence),
        Landmark(x: 0.34, y: thumbBase.y + 0.06 * scale, confidence: confidence),
        Landmark(x: 0.33, y: thumbBase.y + 0.12 * scale, confidence: confidence),
        Landmark(x: 0.33, y: tipY, confidence: confidence),
    ]
    return HandLandmarks(wrist: Landmark(wrist, confidence: confidence), fingers: fingers, chirality: .left)
}

@Suite struct PostureAnalyzerTests {
    let analyzer = PostureAnalyzer()

    @Test func interiorAngle() {
        let straight = PostureAnalyzer.interiorAngle(at: CGPoint(x: 0, y: 0), from: CGPoint(x: -1, y: 0), to: CGPoint(x: 1, y: 0))
        #expect(abs(straight - 180) < 0.001)
        let right = PostureAnalyzer.interiorAngle(at: CGPoint(x: 0, y: 0), from: CGPoint(x: 1, y: 0), to: CGPoint(x: 0, y: 1))
        #expect(abs(right - 90) < 0.001)
    }

    @Test func archedHandLooksGood() {
        let assessment = analyzer.assess(makeHand(bend: 50))
        #expect(assessment.hints == [.lookingGood])
        for report in assessment.fingers {
            #expect(report.isReliable)
            #expect(!report.isFlat)
            #expect(abs(report.archAngle - 130) < 1, "\(report.finger): \(report.archAngle)")
        }
        #expect(assessment.thumbOverNeck == false)
    }

    @Test func flatHandGetsArchHint() {
        let assessment = analyzer.assess(makeHand(bend: 5))
        #expect(assessment.hints.contains(.flatFingers([.index, .middle, .ring, .little])))
        #expect(!assessment.hints.contains(.lookingGood))
    }

    @Test func thumbOverTheNeckIsNoticed() {
        let assessment = analyzer.assess(makeHand(bend: 50, thumbTipY: 0.85))
        #expect(assessment.thumbOverNeck == true)
        #expect(assessment.hints == [.thumbOverNeck])
    }

    @Test func tinyHandAsksToMoveCloser() {
        let assessment = analyzer.assess(makeHand(bend: 50, scale: 0.15))
        #expect(assessment.hints == [.moveCloser])
        #expect(assessment.fingers.isEmpty)
    }

    @Test func missingHandAndLowConfidence() {
        #expect(analyzer.assess(nil).hints == [.noHand])
        let unsure = analyzer.assess(makeHand(bend: 5, confidence: 0.1))
        #expect(unsure.hints == [.noHand])
    }

    @Test func singleRestingLittleFingerIsTolerated() {
        var hand = makeHand(bend: 50)
        // Straighten only the little finger.
        let straight = makeHand(bend: 0).fingers[.little]!
        hand.fingers[.little] = straight
        let assessment = analyzer.assess(hand)
        #expect(assessment.report(for: .little)?.isFlat == true)
        #expect(assessment.hints == [.lookingGood])
    }
}

@Suite struct HintSmootherTests {
    @Test func hintsNeedAMajorityOfRecentFrames() {
        var smoother = HintSmoother(windowSize: 10, requiredCount: 6)
        for _ in 0..<5 {
            #expect(smoother.push([.thumbOverNeck]).isEmpty)
        }
        #expect(smoother.push([.thumbOverNeck]) == [.thumbOverNeck])
    }

    @Test func correctionsOutrankReassurance() {
        var smoother = HintSmoother(windowSize: 4, requiredCount: 2)
        _ = smoother.push([.lookingGood])
        _ = smoother.push([.lookingGood])
        _ = smoother.push([.flatFingers([.index])])
        #expect(smoother.push([.flatFingers([.index])]) == [.flatFingers([.index])])
    }

    @Test func oldFramesExpire() {
        var smoother = HintSmoother(windowSize: 3, requiredCount: 2)
        _ = smoother.push([.moveCloser])
        _ = smoother.push([.moveCloser])
        _ = smoother.push([.lookingGood])
        _ = smoother.push([.lookingGood])
        #expect(smoother.push([.lookingGood]) == [.lookingGood])
    }
}
