import DesignSystem
import HandCoach
import SwiftUI
import UIKit

struct CoachView: View {
    @State private var model = CoachModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: GuitarroSpacing.medium) {
                cameraArea
                hintCard
                setupTips
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .guitarroScreen(glow: .sky)
        .navigationTitle("coach.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.switchCamera()
                } label: {
                    Label("coach.flip", systemImage: "arrow.triangle.2.circlepath.camera")
                }
                .disabled(model.status != .running)
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                model.start()
            } else {
                model.stop()
            }
        }
        .onDisappear { model.stop() }
    }

    // MARK: Camera

    private var cameraArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
            switch model.status {
            case .running:
                CameraPreview(session: model.camera)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                overlay
            case .demo:
                LinearGradient(colors: [Color(white: 0.25), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                overlay
                VStack {
                    Text("coach.demo")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(10)
                    Spacer()
                }
            case .starting, .idle:
                ProgressView()
                    .tint(.white)
            case .permissionDenied:
                statusMessage("coach.permission.title", "coach.permission.body", systemImage: "camera.fill.badge.ellipsis") {
                    Button("tuner.permission.openSettings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .noCamera:
                statusMessage("coach.noCamera.title", "coach.noCamera.body", systemImage: "camera.slash") { EmptyView() }
            case .failed(let message):
                statusMessage("coach.failed", LocalizedStringKey(message), systemImage: "exclamationmark.triangle") { EmptyView() }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }

    private var overlay: some View {
        HandOverlayView(
            hand: model.trackedHand,
            assessment: model.assessment,
            imageSize: model.frame?.imageSize ?? CGSize(width: 3, height: 4)
        )
    }

    private func statusMessage<Actions: View>(_ title: LocalizedStringKey, _ body: LocalizedStringKey, systemImage: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: GuitarroSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            actions()
        }
        .foregroundStyle(.white)
        .padding(GuitarroSpacing.large)
    }

    // MARK: Hints

    private var hintCard: some View {
        let hint = model.hints.first ?? .noHand
        return HStack(alignment: .top, spacing: GuitarroSpacing.medium) {
            Image(systemName: symbol(for: hint))
                .font(.title)
                .foregroundStyle(color(for: hint))
                .frame(width: 40)
            Text(CoachText.text(for: hint))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .guitarroCard()
        .animation(.snappy, value: model.hints)
    }

    private func symbol(for hint: PostureHint) -> String {
        switch hint {
        case .noHand: "hand.raised.slash"
        case .moveCloser: "arrow.up.left.and.arrow.down.right"
        case .flatFingers: "hand.point.up.left"
        case .thumbOverNeck: "hand.thumbsup"
        case .lookingGood: "checkmark.seal.fill"
        }
    }

    private func color(for hint: PostureHint) -> Color {
        switch hint {
        case .lookingGood: .guitarroInTune
        case .noHand, .moveCloser: .secondary
        case .flatFingers, .thumbOverNeck: .guitarroAccent
        }
    }

    private var setupTips: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            Text("coach.setup.title")
                .font(.headline)
            Label("coach.setup.1", systemImage: "iphone.gen3")
            Label("coach.setup.2", systemImage: "sun.max")
            Label("coach.setup.3", systemImage: "tortoise")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }
}

enum CoachText {
    static func text(for hint: PostureHint) -> String {
        switch hint {
        case .noHand: String(localized: "coach.hint.noHand")
        case .moveCloser: String(localized: "coach.hint.moveCloser")
        case .thumbOverNeck: String(localized: "coach.hint.thumbOverNeck")
        case .lookingGood: String(localized: "coach.hint.lookingGood")
        case .flatFingers(let fingers):
            if fingers.count == 1, let finger = fingers.first {
                String(format: String(localized: "coach.hint.flatFinger %@"), fingerName(finger))
            } else {
                String(format: String(localized: "coach.hint.flatFingers %@"), ListFormatter.localizedString(byJoining: fingers.map(fingerName)))
            }
        }
    }

    static func fingerName(_ finger: Finger) -> String {
        let key: String = "finger.\(finger.rawValue)"
        return String(localized: String.LocalizationValue(key))
    }
}

#Preview {
    NavigationStack {
        CoachView()
    }
}
