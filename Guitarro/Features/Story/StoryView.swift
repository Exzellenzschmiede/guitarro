import DesignSystem
import Story
import SwiftData
import SwiftUI

/// The story hub: overall level and one card per campaign.
struct StoryView: View {
    @Query private var progress: [StoryProgress]
    @Environment(StoreManager.self) private var store
    @State private var showsProfile = false
    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GuitarroSpacing.large) {
                    levelCard
                    GuitarroSectionTitle("story.select")
                    ForEach(StoryCampaign.all) { campaign in
                        let locked = campaign.id != StoryCampaign.lostMelody.id && !store.hasPro
                        CampaignCard(campaign: campaign, state: progress.state(for: campaign), needsPro: locked)
                            .overlay {
                                if locked {
                                    Button { showsPaywall = true } label: { Color.clear }
                                } else {
                                    NavigationLink(value: campaign) { Color.clear }
                                }
                            }
                    }
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
            .navigationDestination(for: StoryCampaignDefinition.self) { campaign in
                StoryCampaignView(campaign: campaign)
            }
            .navigationDestination(for: StoryChapterRoute.self) { route in
                StorySceneView(campaign: route.campaign, chapter: route.chapter)
            }
        }
    }

    private var levelCard: some View {
        let overall = progress.overallState
        let finished = StoryCampaign.all.filter { $0.isComplete(for: progress.state(for: $0)) }.count
        return HStack(spacing: GuitarroSpacing.medium) {
            LevelRing(state: overall)
            VStack(alignment: .leading, spacing: 4) {
                Text("story.level \(overall.level)")
                    .font(.guitarroHeadline)
                    .foregroundStyle(Color.guitarroInk)
                Text("story.overall \(finished) \(StoryCampaign.all.count) \(overall.xp)")
                    .font(.caption)
                    .foregroundStyle(Color.guitarroInk.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "book.pages.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.guitarroInk.opacity(0.35))
        }
        .guitarroHeroCard(palette: .gold)
    }
}

private struct CampaignCard: View {
    let campaign: StoryCampaignDefinition
    let state: StoryState
    let needsPro: Bool

    private var palette: GuitarroPalette { GuitarroPaletteName.palette(for: campaign.theme) }
    private var done: Int { state.completedChapterCount(in: campaign) }

    var body: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            HStack(alignment: .top, spacing: GuitarroSpacing.medium) {
                GuitarroIconBadge(campaign.symbol, size: 56, palette: palette)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(campaign.titleKey))
                        .font(.guitarroTitle)
                        .foregroundStyle(Color.guitarroCream)
                    Text(LocalizedStringKey(campaign.taglineKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: GuitarroSpacing.small) {
                ProgressView(value: Double(done), total: Double(campaign.chapters.count))
                    .tint(palette.colors.first ?? .guitarroAccent)
                Text("story.campaign.progress \(done) \(campaign.chapters.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            HStack {
                if needsPro {
                    GuitarroPill("pro.badge", tint: Color(red: 1.0, green: 0.84, blue: 0.4))
                } else if campaign.isComplete(for: state) {
                    GuitarroPill("story.chapter.done", tint: .guitarroInTune)
                } else if done > 0 || !state.completedSceneIDs.isEmpty {
                    GuitarroPill("story.continue", tint: palette.colors.first ?? .guitarroAccent)
                } else {
                    GuitarroPill("story.start")
                }
                Spacer()
                Image(systemName: needsPro ? "lock.fill" : "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }
}

/// One campaign: title art, level and the chapter map.
struct StoryCampaignView: View {
    let campaign: StoryCampaignDefinition

    @Query private var progress: [StoryProgress]
    @Environment(StoreManager.self) private var store
    @State private var showsPaywall = false

    private var state: StoryState { progress.state(for: campaign) }
    private var palette: GuitarroPalette { GuitarroPaletteName.palette(for: campaign.theme) }

    var body: some View {
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
        .guitarroScreen(glow: palette)
        .navigationTitle(LocalizedStringKey(campaign.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }

    private var hero: some View {
        let current = campaign.currentChapter(for: state)
        return VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("story.kicker")
                        .font(.caption.bold())
                        .foregroundStyle(Color.guitarroInk.opacity(0.7))
                    Text(LocalizedStringKey(campaign.titleKey))
                        .font(.guitarroLargeTitle)
                        .foregroundStyle(Color.guitarroInk)
                    Text(LocalizedStringKey(campaign.taglineKey))
                        .font(.subheadline)
                        .foregroundStyle(Color.guitarroInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: campaign.symbol)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color.guitarroInk.opacity(0.35))
            }
            HStack(spacing: GuitarroSpacing.medium) {
                LevelRing(state: progress.overallState)
                VStack(alignment: .leading, spacing: 4) {
                    Text("story.level \(progress.overallState.level)")
                        .font(.guitarroHeadline)
                        .foregroundStyle(Color.guitarroInk)
                    Text("story.progress \(state.completedChapterCount(in: campaign)) \(campaign.chapters.count) \(state.xp)")
                        .font(.caption)
                        .foregroundStyle(Color.guitarroInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                NavigationLink(value: StoryChapterRoute(campaign: campaign, chapter: current)) {
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
        .guitarroHeroCard(palette: palette)
    }

    private var chapterMap: some View {
        VStack(spacing: 0) {
            ForEach(campaign.chapters) { chapter in
                let unlocked = state.isChapterUnlocked(chapter, in: campaign)
                let complete = state.isChapterComplete(chapter)
                let freeChapter = campaign.id == StoryCampaign.lostMelody.id && chapter.number <= FreeTier.storyChapters
                let needsPro = !freeChapter && !store.hasPro
                ChapterRow(chapter: chapter, isUnlocked: unlocked, isComplete: complete, needsPro: needsPro, isLast: chapter.id == campaign.chapters.last?.id)
                    .overlay {
                        if unlocked, needsPro {
                            Button { showsPaywall = true } label: { Color.clear }
                        } else if unlocked {
                            NavigationLink(value: StoryChapterRoute(campaign: campaign, chapter: chapter)) { Color.clear }
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
