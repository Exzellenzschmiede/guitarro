import DesignSystem
import MusicTheory
import Story
import SwiftData
import SwiftUI
import Training
import Tutorials

/// Value-based routes inside the Practice tab. All links are value-based so pushes compose.
enum LearnRoute: Hashable {
    case chordTrainer
    case cameraCoach
    case aiCoach
    case tutorials
}

/// The practice hub: greeting, story progress, tools and quick stats.
struct PracticeHomeView: View {
    @Environment(AppNavigation.self) private var navigation
    @Query private var progress: [ChordChangeProgress]
    @Query private var storyProgress: [StoryProgress]
    @State private var showsProfile = false

    private let columns = [GridItem(.flexible(), spacing: GuitarroSpacing.medium), GridItem(.flexible(), spacing: GuitarroSpacing.medium)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GuitarroSpacing.large) {
                    greeting
                    storyCard
                    statsRow
                    GuitarroSectionTitle("practice.tools")
                    LazyVGrid(columns: columns, spacing: GuitarroSpacing.medium) {
                        NavigationLink(value: LearnRoute.tutorials) {
                            ToolTile(symbol: "play.rectangle.on.rectangle", palette: .gold, title: "tutorials.title", subtitle: "practice.tile.tutorials")
                        }
                        NavigationLink(value: LearnRoute.chordTrainer) {
                            ToolTile(symbol: "arrow.triangle.2.circlepath", palette: .amber, title: "trainer.card.title", subtitle: "practice.tile.trainer")
                        }
                        NavigationLink(value: LearnRoute.cameraCoach) {
                            ToolTile(symbol: "camera.viewfinder", palette: .sky, title: "coach.card.title", subtitle: "practice.tile.camera")
                        }
                        NavigationLink(value: LearnRoute.aiCoach) {
                            ToolTile(symbol: "sparkles", palette: .violet, title: "coach.ai.card.title", subtitle: "practice.tile.ai")
                        }
                        Button {
                            navigation.selectedTab = .fretboard
                        } label: {
                            ToolTile(symbol: "square.grid.3x3", palette: .mint, title: "tab.fretboard", subtitle: "practice.tile.fretboard")
                        }
                        Button {
                            navigation.selectedTab = .songs
                        } label: {
                            ToolTile(symbol: "music.note.list", palette: .rose, title: "tab.songs", subtitle: "practice.tile.songs")
                        }
                        Button {
                            navigation.selectedTab = .tuner
                        } label: {
                            ToolTile(symbol: "tuningfork", palette: .ocean, title: "tab.tuner", subtitle: "practice.tile.tuner")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .guitarroScreen()
            .navigationTitle("tab.practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsProfile = true
                    } label: {
                        Label("tab.profile", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showsProfile) {
                NavigationStack {
                    ProfileView()
                }
            }
            .navigationDestination(for: LearnRoute.self) { route in
                switch route {
                case .chordTrainer: ChordTrainerView()
                case .cameraCoach: ProGate(feature: "coach.title") { CoachView() }
                case .aiCoach: ProGate(feature: "coach.ai.title") { CoachChatView() }
                case .tutorials: TutorialsView()
                }
            }
            .navigationDestination(for: Tutorial.self) { tutorial in
                TutorialView(tutorial: tutorial)
            }
            .navigationDestination(for: ChordPair.self) { pair in
                ChordChangeSessionView(pair: pair)
            }
        }
    }

    // MARK: Pieces

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingKey)
                .font(.guitarroLargeTitle)
            Text("practice.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var greetingKey: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "practice.greeting.morning"
        case 11..<17: "practice.greeting.day"
        default: "practice.greeting.evening"
        }
    }

    private var storyCard: some View {
        let campaign = storyProgress.currentCampaign
        let state = storyProgress.state(for: campaign)
        let chapter = campaign.currentChapter(for: state)
        return Button {
            navigation.selectedTab = .story
        } label: {
            HStack(spacing: GuitarroSpacing.medium) {
                GuitarroIconBadge(chapter.symbol, size: 56, palette: .violet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(campaign.titleKey))
                        .font(.caption.bold())
                        .foregroundStyle(Color.guitarroInk.opacity(0.7))
                    Text(LocalizedStringKey(chapter.titleKey))
                        .font(.guitarroHeadline)
                        .foregroundStyle(Color.guitarroInk)
                    Text("story.progress \(state.completedChapterCount(in: campaign)) \(campaign.chapters.count) \(state.xp)")
                        .font(.caption)
                        .foregroundStyle(Color.guitarroInk.opacity(0.75))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.guitarroInk.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .guitarroHeroCard()
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        let states = progress.skillStates
        let due = ChordChangeScheduler.dueChanges(from: states).count
        let best = states.values.map(\.best).max() ?? 0
        let level = storyProgress.overallState.level
        return HStack(spacing: GuitarroSpacing.medium) {
            StatTile(value: "\(due)", label: "practice.stat.due", symbol: "clock.badge.exclamationmark", palette: .amber)
            StatTile(value: "\(best)", label: "practice.stat.best", symbol: "bolt.fill", palette: .mint)
            StatTile(value: "\(level)", label: "practice.stat.level", symbol: "star.fill", palette: .gold)
        }
    }
}

private struct ToolTile: View {
    let symbol: String
    let palette: GuitarroPalette
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            GuitarroIconBadge(symbol, size: 44, palette: palette)
            Text(title)
                .font(.guitarroHeadline)
                .foregroundStyle(Color.guitarroCream)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .guitarroCard()
    }
}

private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    let symbol: String
    let palette: GuitarroPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(palette.gradient)
            Text(value)
                .font(.guitarroDisplay(28))
                .foregroundStyle(Color.guitarroCream)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard(cornerRadius: 18)
    }
}
