import AudioEngine
import DesignSystem
import MusicTheory
import SwiftUI

/// First-launch flow: who is playing, how they hold the guitar, and why we need the microphone.
struct OnboardingView: View {
    @AppStorage(PlayerSettingsKeys.onboardingCompleted) private var completed = false
    @AppStorage(PlayerSettingsKeys.level) private var level: PlayerLevel = .beginner
    @AppStorage(PlayerSettingsKeys.instrument) private var instrument: Instrument = .acoustic
    @AppStorage(PlayerSettingsKeys.handedness) private var handedness: Handedness = .right
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(AppNavigation.self) private var navigation

    @State private var page = 0
    @State private var microphoneGranted: Bool?

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                playerPage.tag(1)
                handsPage.tag(2)
                microphonePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .guitarroScreen(glow: page == 0 ? .amber : [GuitarroPalette.amber, .violet, .ocean, .mint][page])
        .preferredColorScheme(.dark)
    }

    // MARK: Pages

    private var welcome: some View {
        OnboardingPage(symbol: "guitars.fill", palette: .amber, title: "onboarding.welcome.title", body: "onboarding.welcome.body") {
            VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                OnboardingFeature(symbol: "ear", text: "onboarding.welcome.feature.listen")
                OnboardingFeature(symbol: "camera.viewfinder", text: "onboarding.welcome.feature.watch")
                OnboardingFeature(symbol: "book.pages", text: "onboarding.welcome.feature.story")
            }
        }
    }

    private var playerPage: some View {
        OnboardingPage(symbol: "person.fill.questionmark", palette: .violet, title: "onboarding.player.title", body: "onboarding.player.body") {
            VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
                Text("onboarding.player.level").font(.guitarroHeadline)
                ChoiceRow(options: PlayerLevel.allCases, selection: $level) { option in
                    LocalizedStringKey(String("onboarding.level.\(option.rawValue)"))
                }
                Text("onboarding.player.instrument").font(.guitarroHeadline)
                ChoiceRow(options: Instrument.allCases, selection: $instrument) { option in
                    LocalizedStringKey(String("onboarding.instrument.\(option.rawValue)"))
                }
            }
        }
    }

    private var handsPage: some View {
        OnboardingPage(symbol: "hand.raised.fingers.spread", palette: .ocean, title: "onboarding.hands.title", body: "onboarding.hands.body") {
            VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
                Text("onboarding.hands.handedness").font(.guitarroHeadline)
                ChoiceRow(options: Handedness.allCases, selection: $handedness) { option in
                    LocalizedStringKey(String("onboarding.handedness.\(option.rawValue)"))
                }
                Text("settings.noteNaming").font(.guitarroHeadline)
                ChoiceRow(options: NoteNamingStyle.allCases, selection: $noteNaming) { option in
                    option == .german ? "settings.noteNaming.german" : "settings.noteNaming.international"
                }
            }
        }
    }

    private var microphonePage: some View {
        OnboardingPage(symbol: "mic.fill", palette: .mint, title: "onboarding.mic.title", body: "onboarding.mic.body") {
            VStack(spacing: GuitarroSpacing.medium) {
                switch microphoneGranted {
                case .some(true):
                    Label("onboarding.mic.granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.guitarroInTune)
                case .some(false):
                    Label("onboarding.mic.denied", systemImage: "mic.slash")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case nil:
                    Button {
                        Task { microphoneGranted = await MicrophonePermission.request() }
                    } label: {
                        Label("onboarding.mic.allow", systemImage: "mic.fill")
                    }
                    .buttonStyle(.guitarroPrimary(.mint))
                }
                Text("onboarding.mic.privacy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: GuitarroSpacing.medium) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.guitarroAccent : Color.white.opacity(0.2))
                        .frame(width: index == page ? 22 : 8, height: 6)
                }
            }
            .animation(.snappy, value: page)
            HStack(spacing: GuitarroSpacing.medium) {
                if page > 0 {
                    Button("onboarding.back") { withAnimation { page -= 1 } }
                        .buttonStyle(.guitarroSecondary)
                        .frame(maxWidth: 120)
                }
                Button {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Label(page < pageCount - 1 ? "story.next" : "onboarding.finish", systemImage: page < pageCount - 1 ? "arrow.right" : "play.fill")
                }
                .buttonStyle(.guitarroPrimary)
            }
        }
        .padding()
        .frame(maxWidth: 560)
    }

    private func finish() {
        navigation.selectedTab = level.startTab
        completed = true
    }
}

private struct OnboardingPage<Extra: View>: View {
    let symbol: String
    let palette: GuitarroPalette
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder let extra: () -> Extra

    init(symbol: String, palette: GuitarroPalette, title: LocalizedStringKey, body: LocalizedStringKey, @ViewBuilder extra: @escaping () -> Extra) {
        self.symbol = symbol
        self.palette = palette
        self.title = title
        self.text = body
        self.extra = extra
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GuitarroSpacing.large) {
                GuitarroIconBadge(symbol, size: 96, palette: palette)
                    .padding(.top, GuitarroSpacing.extraLarge)
                Text(title)
                    .font(.guitarroLargeTitle)
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
                    .frame(maxWidth: .infinity)
                    .guitarroCard()
            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct OnboardingFeature: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.guitarroAccentGradient)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Horizontal single-choice chips.
struct ChoiceRow<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> LocalizedStringKey

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.snappy) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(selection == option ? AnyShapeStyle(.guitarroAccentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(selection == option ? 0.3 : 0.12), lineWidth: 1))
                        .foregroundStyle(selection == option ? Color.guitarroInk : Color.guitarroCream)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wraps its children onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
