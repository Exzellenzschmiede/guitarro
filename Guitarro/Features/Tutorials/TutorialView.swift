import DesignSystem
import Story
import SwiftUI
import Tutorials

/// One lesson: steps with illustration and text, an optional playable check at the end.
struct TutorialView: View {
    let tutorial: Tutorial
    /// When presented from a challenge, the sheet closes after the last step.
    var onFinished: (() -> Void)?

    @State private var stepIndex = 0
    @State private var activeCheck: StoryChallenge?
    @AppStorage(TutorialProgress.key) private var completedRaw = ""
    @Environment(\.dismiss) private var dismiss

    private var palette: GuitarroPalette { GuitarroPaletteName.palette(for: tutorial.theme) }
    private var step: TutorialStep { tutorial.steps[stepIndex] }
    private var isLast: Bool { stepIndex == tutorial.steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: GuitarroSpacing.large) {
                    TutorialIllustrationView(illustration: step.illustration, palette: palette)
                        .id(step.id)
                        .transition(.opacity)
                    VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                        Text(LocalizedStringKey(step.titleKey))
                            .font(.guitarroTitle)
                        Text(LocalizedStringKey(step.bodyKey))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.guitarroCream)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .guitarroCard()
                    controls
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .guitarroScreen(glow: palette)
        .navigationTitle(LocalizedStringKey(tutorial.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeCheck) { challenge in
            StoryChallengeHost(challenge: challenge, palette: palette) { success in
                activeCheck = nil
                if success { markCompleted() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(Array(tutorial.steps.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index <= stepIndex ? palette.gradient : LinearGradient(colors: [Color.white.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 5)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.snappy, value: stepIndex)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            if stepIndex > 0 {
                Button { withAnimation(.snappy) { stepIndex -= 1 } } label: { Label("onboarding.back", systemImage: "arrow.left") }
                    .buttonStyle(.guitarroSecondary)
                    .frame(maxWidth: 140)
            }
            if isLast, let check = step.check {
                Button { activeCheck = check } label: { Label("tutorial.tryIt", systemImage: "mic.fill") }
                    .buttonStyle(.guitarroPrimary(palette))
            } else if isLast {
                Button {
                    markCompleted()
                    if let onFinished { onFinished() } else { dismiss() }
                } label: {
                    Label("tutorial.finish", systemImage: "checkmark")
                }
                .buttonStyle(.guitarroPrimary(palette))
            } else {
                Button { withAnimation(.snappy) { stepIndex += 1 } } label: { Label("story.next", systemImage: "arrow.right") }
                    .buttonStyle(.guitarroPrimary(palette))
            }
        }
        if isLast, step.check != nil, TutorialProgress.completed(from: completedRaw).contains(tutorial.id) {
            Label("tutorial.completed", systemImage: "checkmark.seal.fill")
                .font(.subheadline)
                .foregroundStyle(Color.guitarroInTune)
        }
    }

    private func markCompleted() {
        var set = TutorialProgress.completed(from: completedRaw)
        set.insert(tutorial.id)
        completedRaw = TutorialProgress.raw(from: set)
    }
}
