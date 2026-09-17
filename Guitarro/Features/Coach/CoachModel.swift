import Foundation
import HandCoach
import Observation

@MainActor
@Observable
final class CoachModel {
    enum Status: Equatable {
        case idle
        case starting
        case running
        /// Simulator only: no camera, so a synthetic hand demonstrates the overlay.
        case demo
        case permissionDenied
        case noCamera
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var frame: CoachFrame?
    private(set) var trackedHand: HandLandmarks?
    private(set) var assessment: PostureAssessment?
    private(set) var hints: [PostureHint] = [.noHand]

    let camera = CameraSession()
    private var task: Task<Void, Never>?
    private var smoother = HintSmoother()
    private let analyzer = PostureAnalyzer()

    var position: CameraSession.Position { camera.position }

    func start() {
        guard status == .idle else { return }
        guard CameraSession.hasCamera else {
            #if targetEnvironment(simulator)
            showDemo()
            #else
            status = .noCamera
            #endif
            return
        }
        status = .starting
        task = Task {
            do {
                let stream = try await camera.start(position: .front)
                status = .running
                for await frame in stream {
                    ingest(frame)
                }
            } catch let error as CameraError {
                status = error == .permissionDenied ? .permissionDenied : .failed(error.localizedDescription)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        camera.stop()
        if status == .running || status == .starting || status == .demo {
            status = .idle
        }
        smoother.reset()
    }

    func switchCamera() {
        guard status == .running else { return }
        camera.switchCamera()
        smoother.reset()
    }

    private func ingest(_ frame: CoachFrame) {
        self.frame = frame
        // The closest hand (largest on screen) is almost always the fretting hand.
        let hand = frame.hands.max { lhs, rhs in
            (lhs.boundingBox()?.width ?? 0) < (rhs.boundingBox()?.width ?? 0)
        }
        trackedHand = hand
        let assessment = analyzer.assess(hand)
        self.assessment = assessment
        hints = smoother.push(assessment.hints)
    }

    private func showDemo() {
        status = .demo
        let hand = DemoHand.sample
        frame = CoachFrame(hands: [hand], imageSize: CGSize(width: 720, height: 1280), timestamp: 0)
        trackedHand = hand
        let assessment = analyzer.assess(hand)
        self.assessment = assessment
        hints = assessment.hints
    }
}

extension CameraError: @retroactive Equatable {
    public static func == (lhs: CameraError, rhs: CameraError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}

/// A synthetic fretting hand used by the simulator demo and previews:
/// index, ring and little finger nicely arched, middle finger flat.
enum DemoHand {
    static let sample: HandLandmarks = {
        func finger(x: CGFloat, bend: Double) -> [Landmark] {
            var points = [CGPoint(x: x, y: 0.5)]
            var direction = 80.0
            var current = points[0]
            for _ in 0..<3 {
                let radians = direction * .pi / 180
                current = CGPoint(x: current.x + 0.075 * CGFloat(cos(radians)), y: current.y + 0.075 * CGFloat(sin(radians)))
                points.append(current)
                direction -= bend
            }
            return points.map { Landmark($0, confidence: 0.95) }
        }
        var fingers: [Finger: [Landmark]] = [
            .index: finger(x: 0.40, bend: 45),
            .middle: finger(x: 0.47, bend: 4),
            .ring: finger(x: 0.54, bend: 45),
            .little: finger(x: 0.60, bend: 40),
        ]
        fingers[.thumb] = [
            Landmark(x: 0.30, y: 0.32, confidence: 0.9),
            Landmark(x: 0.27, y: 0.38, confidence: 0.9),
            Landmark(x: 0.26, y: 0.45, confidence: 0.8),
            Landmark(x: 0.27, y: 0.52, confidence: 0.7),
        ]
        return HandLandmarks(wrist: Landmark(x: 0.5, y: 0.24, confidence: 0.98), fingers: fingers, chirality: .left)
    }()
}
