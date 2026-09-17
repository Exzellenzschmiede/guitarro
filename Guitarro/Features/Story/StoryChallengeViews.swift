import AudioEngine
import DesignSystem
import Fretboard
import MusicTheory
import Songs
import Story
import SwiftUI
import Training

/// Presents one challenge full screen and reports success or a skip.
struct StoryChallengeHost: View {
    let challenge: StoryChallenge
    let palette: GuitarroPalette
    let onFinish: (Bool) -> Void

    @State private var succeeded = false

    var body: some View {
        NavigationStack {
            ZStack {
                content
                if succeeded {
                    successOverlay
                }
            }
            .guitarroScreen(glow: palette)
            .navigationTitle("story.challenge.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("story.challenge.skip") { onFinish(false) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch challenge {
        case .tuneStrings:
            TuneChallengeView(palette: palette) { succeed() }
        case .playNotes(let notes):
            NotesChallengeView(targets: notes.map { Pitch(midiNumber: $0) }, palette: palette) { succeed() }
        case .playChords(let chords):
            ChordsChallengeView(targets: chords, palette: palette) { succeed() }
        case .chordChanges(let from, let to, let minimum):
            ChangesChallengeView(pair: ChordPair(from, to), minimum: minimum, palette: palette) { succeed() }
        case .playSong(let id, let tempo, let accuracy):
            if let song = SongLibrary.song(id: id) {
                SongChallengeView(song: song, tempoPercent: tempo, minimumAccuracy: accuracy, palette: palette) { succeed() }
            }
        }
    }

    private func succeed() {
        guard !succeeded else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { succeeded = true }
    }

    private var successOverlay: some View {
        VStack(spacing: GuitarroSpacing.large) {
            GuitarroIconBadge("checkmark", size: 96, palette: .mint)
                .transition(.scale.combined(with: .opacity))
            Text("story.challenge.success")
                .font(.guitarroLargeTitle)
                .foregroundStyle(Color.guitarroCream)
            Button {
                onFinish(true)
            } label: {
                Label("story.next", systemImage: "arrow.right")
            }
            .buttonStyle(.guitarroPrimary(palette))
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.guitarroInk.opacity(0.85).ignoresSafeArea())
        .sensoryFeedback(.success, trigger: succeeded)
    }
}

// MARK: - Tune all strings

struct TuneChallengeView: View {
    let palette: GuitarroPalette
    let onSuccess: () -> Void

    @State private var model = TunerModel()
    @State private var tuned: Set<Int> = []
    @State private var streak: (index: Int, count: Int) = (-1, 0)
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            Text("story.challenge.tune.hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(model.displayedPitch?.name(style: noteNaming, includeOctave: false) ?? "–")
                .font(.guitarroDisplay(96))
                .foregroundStyle(model.isInTune ? Color.guitarroInTune : Color.guitarroCream)
                .shadow(color: (model.isInTune ? Color.guitarroInTune : Color.guitarroAccent).opacity(model.reading == nil ? 0 : 0.5), radius: 24)
            TunerGaugeView(cents: model.displayedCents, isInTune: model.isInTune)
                .frame(maxWidth: 420)
                .frame(height: 170)
            HStack(spacing: 12) {
                ForEach(Array(model.tuning.strings.enumerated()), id: \.offset) { index, pitch in
                    ZStack {
                        Circle()
                            .fill(tuned.contains(index) ? GuitarroPalette.mint.gradient : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 48, height: 48)
                        if tuned.contains(index) {
                            Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(.white)
                        } else {
                            Text(pitch.name(style: noteNaming, includeOctave: false)).font(.guitarroHeadline)
                        }
                    }
                    .overlay(Circle().strokeBorder(model.activeStringIndex == index ? Color.guitarroAccent : .clear, lineWidth: 2))
                }
            }
            if case .permissionDenied = model.status {
                Label("trainer.micDenied", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .task { await model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.reading) { _, _ in evaluate() }
    }

    private func evaluate() {
        guard let index = model.activeStringIndex, let cents = model.displayedCents else { return }
        if abs(cents) <= 8 {
            streak = streak.index == index ? (index, streak.count + 1) : (index, 1)
            if streak.count >= 5, !tuned.contains(index) {
                withAnimation(.snappy) { tuned.insert(index) }
                if tuned.count == model.tuning.stringCount { onSuccess() }
            }
        } else {
            streak = (index, 0)
        }
    }
}

// MARK: - Play notes in order

@MainActor
@Observable
final class NoteChallengeModel {
    let targets: [Pitch]
    private(set) var index = 0
    private(set) var heard: Pitch?
    private(set) var permissionDenied = false
    private var streak = 0
    private var tracker: PitchTracker?
    var onSuccess: (() -> Void)?

    init(targets: [Pitch]) {
        self.targets = targets
    }

    var target: Pitch? { targets.indices.contains(index) ? targets[index] : nil }

    func start() async {
        guard await MicrophonePermission.request() else {
            permissionDenied = true
            return
        }
        let tracker = PitchTracker()
        guard let stream = try? tracker.start() else { return }
        self.tracker = tracker
        for await estimate in stream {
            guard let estimate, estimate.clarity >= 0.8, let target else { continue }
            let pitch = Pitch.nearest(toFrequency: estimate.frequency).pitch
            heard = pitch
            if pitch == target {
                streak += 1
                if streak >= 4 {
                    streak = 0
                    index += 1
                    if index >= targets.count { onSuccess?() }
                }
            } else {
                streak = 0
            }
        }
    }

    func stop() {
        tracker?.stop()
        tracker = nil
    }
}

struct NotesChallengeView: View {
    let targets: [Pitch]
    let palette: GuitarroPalette
    let onSuccess: () -> Void

    @State private var model: NoteChallengeModel
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    init(targets: [Pitch], palette: GuitarroPalette, onSuccess: @escaping () -> Void) {
        self.targets = targets
        self.palette = palette
        self.onSuccess = onSuccess
        _model = State(initialValue: NoteChallengeModel(targets: targets))
    }

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            Text("story.challenge.notes.hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                ForEach(Array(targets.enumerated()), id: \.offset) { index, pitch in
                    Text(pitch.name(style: noteNaming, includeOctave: false))
                        .font(.guitarroHeadline)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(index < model.index ? GuitarroPalette.mint.gradient : (index == model.index ? palette.gradient : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))))
                        .foregroundStyle(.white)
                }
            }
            if let target = model.target {
                Text(target.name(style: noteNaming))
                    .font(.guitarroDisplay(96))
                    .foregroundStyle(Color.guitarroCream)
                    .shadow(color: palette.glow.opacity(0.5), radius: 24)
                let positions = Tuning.standard.positions(of: target, maxFret: 5)
                FretboardView(
                    tuning: .standard,
                    fretCount: 5,
                    orientation: .vertical,
                    markers: positions.map { FretboardMarker(position: $0, label: target.name(style: noteNaming, includeOctave: false), style: .root) }
                )
                .frame(width: 220, height: 240)
            }
            Text(model.heard.map { String(format: String(localized: "trainer.hearing %@"), $0.name(style: noteNaming)) } ?? String(localized: "trainer.listening.none"))
                .font(.subheadline)
                .foregroundStyle(model.heard == model.target ? Color.guitarroInTune : Color.secondary)
            if model.permissionDenied {
                Label("trainer.micDenied", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .task {
            model.onSuccess = onSuccess
            await model.start()
        }
        .onDisappear { model.stop() }
    }
}

// MARK: - Play chords in order

@MainActor
@Observable
final class ChordChallengeModel {
    let targets: [String]
    private(set) var index = 0
    private(set) var heard: Chord?
    private(set) var permissionDenied = false
    private var streak = 0
    private var tracker: ChordTracker?
    var onSuccess: (() -> Void)?

    init(targets: [String]) {
        self.targets = targets
    }

    var target: ChordVoicing? { targets.indices.contains(index) ? ChordLibrary.voicing(id: targets[index]) : nil }

    func start() async {
        guard await MicrophonePermission.request() else {
            permissionDenied = true
            return
        }
        let tracker = ChordTracker()
        guard let stream = try? tracker.start() else { return }
        self.tracker = tracker
        for await estimate in stream {
            heard = estimate.chord
            guard let chord = estimate.chord, let target else { streak = 0; continue }
            if chord == target.chord {
                streak += 1
                if streak >= 3 {
                    streak = 0
                    index += 1
                    if index >= targets.count { onSuccess?() }
                }
            } else {
                streak = 0
            }
        }
    }

    func stop() {
        tracker?.stop()
        tracker = nil
    }
}

struct ChordsChallengeView: View {
    let targets: [String]
    let palette: GuitarroPalette
    let onSuccess: () -> Void

    @State private var model: ChordChallengeModel
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    init(targets: [String], palette: GuitarroPalette, onSuccess: @escaping () -> Void) {
        self.targets = targets
        self.palette = palette
        self.onSuccess = onSuccess
        _model = State(initialValue: ChordChallengeModel(targets: targets))
    }

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            Text("story.challenge.chords.hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                ForEach(Array(targets.enumerated()), id: \.offset) { index, id in
                    Text(ChordLibrary.voicing(id: id)?.chord.symbol(style: noteNaming) ?? id)
                        .font(.guitarroHeadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(index < model.index ? GuitarroPalette.mint.gradient : (index == model.index ? palette.gradient : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))))
                        .foregroundStyle(.white)
                }
            }
            if let target = model.target {
                ChordDiagramView(voicing: target, noteNaming: noteNaming, isActive: true)
                    .scaleEffect(1.15)
                    .padding(.vertical, GuitarroSpacing.medium)
            }
            Text(model.heard.map { String(format: String(localized: "trainer.hearing %@"), $0.symbol(style: noteNaming)) } ?? String(localized: "trainer.listening.none"))
                .font(.subheadline)
                .foregroundStyle(model.heard == model.target?.chord ? Color.guitarroInTune : Color.secondary)
            if model.permissionDenied {
                Label("trainer.micDenied", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .task {
            model.onSuccess = onSuccess
            await model.start()
        }
        .onDisappear { model.stop() }
    }
}

// MARK: - One-minute changes with a target

struct ChangesChallengeView: View {
    let pair: ChordPair
    let minimum: Int
    let palette: GuitarroPalette
    let onSuccess: () -> Void

    @State private var session: ChordChangeSession?
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            if let session {
                Text("story.challenge.changes.hint \(minimum)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: GuitarroSpacing.medium) {
                    ChordDiagramView(voicing: session.from, noteNaming: noteNaming, isActive: session.phase == .running && session.expected.id == session.from.id)
                    Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                    ChordDiagramView(voicing: session.to, noteNaming: noteNaming, isActive: session.phase == .running && session.expected.id == session.to.id)
                }
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 12)
                    Circle().trim(from: 0, to: session.progress).stroke(palette.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack {
                        if case .countdown(let n) = session.phase {
                            Text(verbatim: "\(n)").font(.guitarroDisplay(64))
                        } else {
                            Text(verbatim: "\(session.changes)").font(.guitarroDisplay(64))
                            Text(verbatim: "/ \(minimum)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 180, height: 180)
                switch session.phase {
                case .ready:
                    Button { session.start() } label: { Label("trainer.start", systemImage: "play.fill") }
                        .buttonStyle(.guitarroPrimary(palette))
                case .finished:
                    if session.changes >= minimum {
                        Text("story.challenge.changes.reached").foregroundStyle(Color.guitarroInTune)
                    } else {
                        Text("story.challenge.changes.short \(session.changes) \(minimum)").foregroundStyle(.secondary)
                        Button { session.start() } label: { Label("trainer.again", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(.guitarroPrimary(palette))
                    }
                case .running:
                    Text("trainer.playNow \(session.expected.chord.symbol(style: noteNaming))").font(.headline)
                    if let heard = session.heardChord {
                        Text("trainer.hearing \(heard.symbol(style: noteNaming))")
                            .font(.subheadline)
                            .foregroundStyle(heard == session.expected.chord ? Color.guitarroInTune : Color.secondary)
                    }
                case .countdown:
                    Text("trainer.countdown").foregroundStyle(.secondary)
                }
                if session.microphoneStatus == .permissionDenied {
                    Label("trainer.micDenied", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            if session == nil {
                let created = ChordChangeSession(pair: pair)
                created?.inputMode = .microphone
                session = created
            }
        }
        .onDisappear { session?.stopAll() }
        .onChange(of: session?.phase) { _, phase in
            if phase == .finished, let session, session.changes >= minimum { onSuccess() }
        }
    }
}

// MARK: - Play a song with feedback

struct SongChallengeView: View {
    let song: Song
    let tempoPercent: Int
    let minimumAccuracy: Double
    let palette: GuitarroPalette
    let onSuccess: () -> Void

    @State private var player: SongPlayer?
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            if let player {
                Text("story.challenge.song.hint \(Int(minimumAccuracy * 100))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let voicing = ChordLibrary.voicing(id: player.currentChordID) {
                    HStack(spacing: GuitarroSpacing.large) {
                        ChordDiagramView(voicing: voicing, noteNaming: noteNaming, isActive: player.state == .playing)
                        VStack(alignment: .leading) {
                            if case .countIn(let n) = player.state {
                                Text(verbatim: "\(n)").font(.guitarroDisplay(64)).foregroundStyle(palette.gradient)
                            } else {
                                Text(voicing.chord.symbol(style: noteNaming)).font(.guitarroDisplay(56))
                                if let next = player.nextChordID {
                                    Text("song.next \(ChordLibrary.voicing(id: next)?.chord.symbol(style: noteNaming) ?? next)").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    ForEach(player.timeline.bars) { bar in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: player.barResults[bar.index], isCurrent: player.isPlaying && bar.index == player.currentBarIndex))
                            .frame(height: 10)
                    }
                }
                if let accuracy = player.accuracy {
                    Text("song.feedback.hits \(player.hits) \(player.barResults.count)")
                        .font(.subheadline)
                        .foregroundStyle(accuracy >= minimumAccuracy ? Color.guitarroInTune : Color.secondary)
                }
                if player.didFinishPass {
                    if (player.accuracy ?? 0) >= minimumAccuracy {
                        Text("story.challenge.song.reached").foregroundStyle(Color.guitarroInTune)
                    } else {
                        Text("story.challenge.song.short").foregroundStyle(.secondary)
                        Button { player.play() } label: { Label("trainer.again", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(.guitarroPrimary(palette))
                    }
                } else if player.isPlaying {
                    Button { player.stop() } label: { Label("song.stop", systemImage: "stop.fill") }
                        .buttonStyle(.guitarroSecondary)
                } else {
                    Button { player.play() } label: { Label("song.play", systemImage: "play.fill") }
                        .buttonStyle(.guitarroPrimary(palette))
                }
                if player.microphoneDenied {
                    Label("trainer.micDenied", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            if player == nil {
                let created = SongPlayer(song: song)
                created.tempoPercent = tempoPercent
                created.backingEnabled = false
                created.metronomeEnabled = true
                created.feedbackEnabled = true
                created.stopsAfterOnePass = true
                player = created
            }
        }
        .onDisappear { player?.stop() }
        .onChange(of: player?.didFinishPass) { _, finished in
            if finished == true, let player, (player.accuracy ?? 0) >= minimumAccuracy { onSuccess() }
        }
    }

    private func color(for result: Bool?, isCurrent: Bool) -> Color {
        if isCurrent { return .guitarroAccent }
        switch result {
        case .some(true): return .guitarroInTune
        case .some(false): return Color.guitarroSharp.opacity(0.6)
        case nil: return Color.white.opacity(0.12)
        }
    }
}
