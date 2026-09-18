import DesignSystem
import Story
import SwiftData
import SwiftUI
import Tutorials

/// Plays a chapter scene by scene: dialogue with a typewriter effect, choices and challenges.
struct StorySceneView: View {
    let chapter: StoryChapter

    @Query private var progressRows: [StoryProgress]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sceneIndex = 0
    @State private var lineIndex = 0
    @State private var extraLines: [StoryLine] = []
    @State private var extraLineIndex = 0
    @State private var revealed = ""
    @State private var typing: Task<Void, Never>?
    @State private var activeChallenge: StoryChallenge?
    @State private var activeTutorial: Tutorial?
    @State private var challengeSucceeded = false
    @State private var showsSuccess = false
    @State private var earnedXP = 0
    @State private var chapterFinished = false

    private var campaign: StoryCampaignDefinition { StoryCampaign.lostMelody }
    private var palette: GuitarroPalette { GuitarroPaletteName.palette(for: chapter.theme) }
    private var scene: StoryScene? { chapter.scenes.indices.contains(sceneIndex) ? chapter.scenes[sceneIndex] : nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: GuitarroSpacing.large) {
                    if chapterFinished {
                        finished
                    } else if let scene {
                        sceneContent(scene)
                    }
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .guitarroScreen(glow: palette)
        .navigationTitle(LocalizedStringKey(chapter.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: resume)
        .onDisappear { typing?.cancel() }
        .sheet(item: $activeTutorial) { tutorial in
            NavigationStack {
                TutorialView(tutorial: tutorial) { activeTutorial = nil }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("story.challenge.skip") { activeTutorial = nil }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $activeChallenge) { challenge in
            StoryChallengeHost(challenge: challenge, palette: palette) { success in
                activeChallenge = nil
                if success {
                    challengeSucceeded = true
                    if let scene { award(scene) }
                    showsSuccess = true
                    if case .challenge(_, _, _, let success) = scene {
                        start(lines: success)
                    }
                } else if let scene {
                    skip(scene)
                    advance()
                }
            }
        }
    }

    // MARK: Header art

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: palette.colors + [Color.guitarroInk.opacity(0)], startPoint: .topTrailing, endPoint: .bottomLeading)
            Image(systemName: chapter.symbol)
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: 40, y: -10)
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 6) {
                Text("story.chapter \(chapter.number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                Text(LocalizedStringKey(chapter.titleKey))
                    .font(.guitarroTitle)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    ForEach(Array(chapter.scenes.enumerated()), id: \.offset) { index, item in
                        Capsule()
                            .fill(index < sceneIndex || chapterFinished ? Color.white : (index == sceneIndex ? Color.white.opacity(0.9) : Color.white.opacity(0.3)))
                            .frame(width: item.isChallenge ? 22 : 12, height: 5)
                    }
                }
            }
            .padding()
        }
        .frame(height: 170)
        .clipped()
    }

    // MARK: Scene rendering

    @ViewBuilder
    private func sceneContent(_ scene: StoryScene) -> some View {
        switch scene {
        case .dialogue(_, let lines):
            if let line = currentLine(from: lines) {
                bubble(line)
            }
            continueButton
        case .choice(_, let prompt, let options):
            if extraLines.isEmpty {
                bubble(prompt)
                if isFullyRevealed(prompt) {
                    VStack(spacing: GuitarroSpacing.small) {
                        ForEach(options) { option in
                            Button {
                                start(lines: option.response)
                            } label: {
                                Text(LocalizedStringKey(option.textKey))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.guitarroSecondary)
                        }
                    }
                }
            } else if let line = currentExtraLine {
                bubble(line)
                continueButton
            }
        case .challenge(_, let challenge, let intro, _):
            if showsSuccess, let line = currentExtraLine {
                bubble(line)
                xpBadge
                continueButton
            } else if let line = currentLine(from: intro) {
                bubble(line)
                if lineIndex == intro.count - 1, isFullyRevealed(line) {
                    challengeCard(challenge)
                } else {
                    continueButton
                }
            }
        }
    }

    private func bubble(_ line: StoryLine) -> some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            HStack(spacing: 8) {
                Circle()
                    .fill(StoryText.speakerColor(line.speaker))
                    .frame(width: 10, height: 10)
                Text(StoryText.speakerName(line.speaker))
                    .font(.caption.bold())
                    .foregroundStyle(StoryText.speakerColor(line.speaker))
            }
            Text(revealed)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.guitarroCream)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { revealAll() }
        }
        .guitarroCard()
        .id(line.textKey)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var continueButton: some View {
        Button {
            next()
        } label: {
            Label("story.next", systemImage: "arrow.right")
        }
        .buttonStyle(.guitarroPrimary(palette))
    }

    private func challengeCard(_ challenge: StoryChallenge) -> some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            HStack(spacing: GuitarroSpacing.medium) {
                GuitarroIconBadge(challenge.symbol, size: 52, palette: palette)
                VStack(alignment: .leading, spacing: 4) {
                    Text("story.challenge.title")
                        .font(.guitarroHeadline)
                    Text(StoryChallengeText.summary(challenge))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                activeChallenge = challenge
            } label: {
                Label("story.challenge.start", systemImage: "play.fill")
            }
            .buttonStyle(.guitarroPrimary(palette))
            if let tutorial = TutorialLibrary.tutorial(for: challenge) {
                Button {
                    activeTutorial = tutorial
                } label: {
                    Label("story.challenge.lesson", systemImage: "play.rectangle.on.rectangle")
                }
                .buttonStyle(.guitarroSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .guitarroCard()
    }

    private var xpBadge: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(GuitarroPalette.gold.gradient)
            Text("story.xp \(earnedXP)")
                .font(.guitarroHeadline)
                .foregroundStyle(Color.guitarroCream)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .transition(.scale.combined(with: .opacity))
    }

    private var finished: some View {
        VStack(spacing: GuitarroSpacing.medium) {
            GuitarroIconBadge("checkmark.seal.fill", size: 72, palette: palette)
            Text("story.chapter.complete")
                .font(.guitarroTitle)
            Text(LocalizedStringKey(chapter.titleKey))
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Label("story.backToMap", systemImage: "map")
            }
            .buttonStyle(.guitarroPrimary(palette))
        }
        .frame(maxWidth: .infinity)
        .guitarroCard()
    }

    // MARK: Flow

    private var currentState: StoryState { progressRows.first?.state ?? StoryState() }

    private func resume() {
        let state = currentState
        sceneIndex = state.nextSceneIndex(in: chapter) ?? chapter.scenes.count
        chapterFinished = sceneIndex >= chapter.scenes.count
        lineIndex = 0
        extraLines = []
        extraLineIndex = 0
        showsSuccess = false
        if let scene {
            switch scene {
            case .dialogue(_, let lines): type(lines.first)
            case .choice(_, let prompt, _): type(prompt)
            case .challenge(_, _, let intro, _): type(intro.first)
            }
        }
    }

    private func currentLine(from lines: [StoryLine]) -> StoryLine? {
        lines.indices.contains(lineIndex) ? lines[lineIndex] : nil
    }

    private var currentExtraLine: StoryLine? {
        extraLines.indices.contains(extraLineIndex) ? extraLines[extraLineIndex] : nil
    }

    private func isFullyRevealed(_ line: StoryLine) -> Bool {
        revealed == StoryText.text(line.textKey)
    }

    private func start(lines: [StoryLine]) {
        withAnimation(.snappy) {
            extraLines = lines
            extraLineIndex = 0
        }
        type(lines.first)
    }

    /// Advances one line; when the scene's lines are exhausted, completes the scene.
    private func next() {
        guard let scene else { return }
        if let line = currentLine(from: linesOf(scene)), !isFullyRevealed(line), extraLines.isEmpty {
            revealAll()
            return
        }
        if !extraLines.isEmpty {
            if let line = currentExtraLine, !isFullyRevealed(line) {
                revealAll()
                return
            }
            if extraLineIndex + 1 < extraLines.count {
                extraLineIndex += 1
                type(currentExtraLine)
                return
            }
            if !scene.isChallenge || challengeSucceeded {
                if !scene.isChallenge { award(scene) }
                advance()
            }
            return
        }
        let lines = linesOf(scene)
        if lineIndex + 1 < lines.count {
            lineIndex += 1
            type(lines[lineIndex])
        } else if case .dialogue = scene {
            award(scene)
            advance()
        }
    }

    private func linesOf(_ scene: StoryScene) -> [StoryLine] {
        switch scene {
        case .dialogue(_, let lines): lines
        case .choice(_, let prompt, _): [prompt]
        case .challenge(_, _, let intro, _): intro
        }
    }

    private func advance() {
        withAnimation(.snappy) {
            sceneIndex += 1
            lineIndex = 0
            extraLines = []
            extraLineIndex = 0
            showsSuccess = false
            challengeSucceeded = false
            chapterFinished = sceneIndex >= chapter.scenes.count
        }
        if let scene {
            switch scene {
            case .dialogue(_, let lines): type(lines.first)
            case .choice(_, let prompt, _): type(prompt)
            case .challenge(_, _, let intro, _): type(intro.first)
            }
        }
    }

    private func award(_ scene: StoryScene) {
        var state = currentState
        guard !state.completedSceneIDs.contains(scene.id) else { return }
        state.complete(scene)
        earnedXP = scene.xp
        save(state)
    }

    private func skip(_ scene: StoryScene) {
        var state = currentState
        state.skip(scene)
        save(state)
    }

    private func save(_ state: StoryState) {
        if let row = progressRows.first {
            row.state = state
        } else {
            modelContext.insert(StoryProgress(state: state))
        }
        try? modelContext.save()
    }

    // MARK: Typewriter

    private func type(_ line: StoryLine?) {
        typing?.cancel()
        revealed = ""
        guard let line else { return }
        let full = StoryText.text(line.textKey)
        typing = Task {
            var index = full.startIndex
            while index < full.endIndex, !Task.isCancelled {
                index = full.index(after: index)
                revealed = String(full[..<index])
                try? await Task.sleep(for: .milliseconds(18))
            }
            if !Task.isCancelled { revealed = full }
        }
    }

    private func revealAll() {
        typing?.cancel()
        guard let scene else { return }
        let line = extraLines.isEmpty ? currentLine(from: linesOf(scene)) : currentExtraLine
        if let line { revealed = StoryText.text(line.textKey) }
    }
}

extension StoryChallenge: @retroactive Identifiable {
    public var id: String {
        switch self {
        case .tuneStrings: "tune"
        case .playNotes(let notes): "notes-" + notes.map(String.init).joined(separator: "-")
        case .playChords(let chords): "chords-" + chords.joined(separator: "-")
        case .chordChanges(let from, let to, let minimum): "changes-\(from)-\(to)-\(minimum)"
        case .playSong(let id, let tempo, let accuracy): "song-\(id)-\(tempo)-\(accuracy)"
        }
    }
}

enum StoryChallengeText {
    static func summary(_ challenge: StoryChallenge) -> String {
        switch challenge {
        case .tuneStrings:
            String(localized: "story.challenge.tune")
        case .playNotes(let notes):
            String(format: String(localized: "story.challenge.notes %lld"), notes.count)
        case .playChords(let chords):
            String(format: String(localized: "story.challenge.chords %@"), chords.joined(separator: " · "))
        case .chordChanges(let from, let to, let minimum):
            String(format: String(localized: "story.challenge.changes %@ %@ %lld"), from, to, minimum)
        case .playSong(_, let tempo, let accuracy):
            String(format: String(localized: "story.challenge.song %lld %lld"), tempo, Int(accuracy * 100))
        }
    }
}
