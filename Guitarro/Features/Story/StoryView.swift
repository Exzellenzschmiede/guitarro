import DesignSystem
import Story
import SwiftData
import SwiftUI

/// The campaign overview: title art, level and a chapter map.
struct StoryView: View {
    @Query private var progress: [StoryProgress]
    @Environment(StoreManager.self) private var store
    @State private var showsProfile = false
    @State private var showsPaywall = false

    private let campaign = StoryCampaign.lostMelody

    private var state: StoryState { progress.first?.state ?? StoryState() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GuitarroSpacing.large) {
                    hero
                    GuitarroSectionTitle("story.chapters")
                    chapterMap
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .guitarroScreen(glow: .violet)
            .navigationTitle("tab.story")
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
                NavigationStack { ProfileView() }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .navigationDestination(for: StoryChapter.self) { chapter in
                StorySceneView(chapter: chapter)
            }
        }
    }

    private var hero: some View {
        let current = campaign.currentChapter(for: state)
        return VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("story.kicker")
                        .font(.caption.bold())
                        .foregroundStyle(Color.guitarroInk.opacity(0.7))
                    Text("story.title")
                        .font(.guitarroLargeTitle)
                        .foregroundStyle(Color.guitarroInk)
                    Text("story.tagline")
                        .font(.subheadline)
                        .foregroundStyle(Color.guitarroInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "guitars.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color.guitarroInk.opacity(0.35))
            }
            HStack(spacing: GuitarroSpacing.medium) {
                LevelRing(state: state)
                VStack(alignment: .leading, spacing: 4) {
                    Text("story.level \(state.level)")
                        .font(.guitarroHeadline)
                        .foregroundStyle(Color.guitarroInk)
                    Text("story.progress \(state.completedChapterCount(in: campaign)) \(campaign.chapters.count) \(state.xp)")
                        .font(.caption)
                        .foregroundStyle(Color.guitarroInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                NavigationLink(value: current) {
                    Label(state.completedChapterCount(in: campaign) == 0 ? "story.start" : "story.continue", systemImage: "play.fill")
                        .font(.guitarroHeadline)
                        .foregroundStyle(Color.guitarroCream)
                        .fixedSize()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.guitarroInk.opacity(0.85)))
                }
            }
        }
        .guitarroHeroCard(palette: .gold)
    }

    private var chapterMap: some View {
        VStack(spacing: 0) {
            ForEach(campaign.chapters) { chapter in
                let unlocked = state.isChapterUnlocked(chapter, in: campaign)
                let complete = state.isChapterComplete(chapter)
                let needsPro = chapter.number > FreeTier.storyChapters && !store.hasPro
                ChapterRow(chapter: chapter, isUnlocked: unlocked, isComplete: complete, needsPro: needsPro, isLast: chapter.id == campaign.chapters.last?.id)
                    .overlay {
                        if unlocked, needsPro {
                            Button { showsPaywall = true } label: { Color.clear }
                        } else if unlocked {
                            NavigationLink(value: chapter) { Color.clear }
                        }
                    }
            }
        }
    }
}

private struct ChapterRow: View {
    let chapter: StoryChapter
    let isUnlocked: Bool
    let isComplete: Bool
    let needsPro: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: GuitarroSpacing.medium) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? GuitarroPaletteName.palette(for: chapter.theme).gradient : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 44)
                        .shadow(color: isUnlocked ? GuitarroPaletteName.palette(for: chapter.theme).glow.opacity(0.5) : .clear, radius: 10, y: 4)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    } else if isUnlocked {
                        Text(verbatim: "\(chapter.number)")
                            .font(.guitarroHeadline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 2, height: 44)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(LocalizedStringKey(chapter.titleKey))
                        .font(.guitarroHeadline)
                        .foregroundStyle(isUnlocked ? Color.guitarroCream : Color.secondary)
                    Spacer()
                    Image(systemName: chapter.symbol)
                        .foregroundStyle(isUnlocked ? GuitarroPaletteName.palette(for: chapter.theme).gradient : LinearGradient(colors: [.secondary], startPoint: .top, endPoint: .bottom))
                }
                Text(LocalizedStringKey(chapter.subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if isComplete {
                    GuitarroPill("story.chapter.done", tint: .guitarroInTune)
                } else if needsPro {
                    GuitarroPill("pro.badge", tint: Color(red: 1.0, green: 0.84, blue: 0.4))
                } else if isUnlocked {
                    GuitarroPill("story.chapter.open")
                } else {
                    GuitarroPill("story.chapter.locked", tint: .guitarroMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .guitarroCard()
            .opacity(isUnlocked ? 1 : 0.6)
            .padding(.bottom, isLast ? 0 : GuitarroSpacing.small)
        }
    }
}

struct LevelRing: View {
    let state: StoryState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.guitarroInk.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: state.levelProgress)
                .stroke(Color.guitarroInk, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(state.level)")
                .font(.guitarroDisplay(20))
                .foregroundStyle(Color.guitarroInk)
        }
        .frame(width: 52, height: 52)
    }
}
