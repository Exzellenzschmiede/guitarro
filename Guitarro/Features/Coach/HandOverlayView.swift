import DesignSystem
import HandCoach
import SwiftUI

/// Draws the tracked hand's skeleton over the camera image, colour-coded by posture.
struct HandOverlayView: View {
    let hand: HandLandmarks?
    let assessment: PostureAssessment?
    let imageSize: CGSize

    private static let bones: [(Finger, [FingerJoint])] = Finger.allCases.map { ($0, FingerJoint.allCases) }

    var body: some View {
        Canvas { context, size in
            guard let hand else { return }
            let rect = Self.fittedRect(imageSize: imageSize, in: size)
            func point(_ landmark: Landmark) -> CGPoint {
                CGPoint(x: rect.minX + landmark.location.x * rect.width, y: rect.minY + (1 - landmark.location.y) * rect.height)
            }

            for finger in Finger.allCases {
                guard let joints = hand.fingers[finger], joints.count == 4 else { continue }
                let color = color(for: finger)
                var path = Path()
                path.move(to: point(hand.wrist))
                for joint in joints {
                    path.addLine(to: point(joint))
                }
                context.stroke(path, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                for joint in joints {
                    let center = point(joint)
                    let radius: CGFloat = joint.confidence >= 0.3 ? 6 : 4
                    let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(.white))
                    context.stroke(Path(ellipseIn: dot), with: .color(color), lineWidth: 2)
                }
            }
            let wrist = point(hand.wrist)
            context.fill(Path(ellipseIn: CGRect(x: wrist.x - 7, y: wrist.y - 7, width: 14, height: 14)), with: .color(.white))
        }
        .allowsHitTesting(false)
    }

    private func color(for finger: Finger) -> Color {
        if finger == .thumb {
            return assessment?.thumbOverNeck == true ? .guitarroSharp : .guitarroFlat
        }
        guard let report = assessment?.report(for: finger), report.isReliable else { return Color.white.opacity(0.6) }
        return report.isFlat ? .guitarroAccent : .guitarroInTune
    }

    /// Aspect-fit rectangle of the image inside the view, matching `.resizeAspect`.
    static func fittedRect(imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, size.width > 0, size.height > 0 else { return .zero }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }
}
