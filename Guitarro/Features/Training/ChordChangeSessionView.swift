import DesignSystem
import MusicTheory
import SwiftData
import SwiftUI
import Training
import Tutorials

struct ChordChangeSessionView: View {
    let pair: ChordPair

    @State private var session: ChordChangeSession?
    @State private var result: SkillState?
    @State private var previousBest = 0
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                ContentUnavailableView("trainer.unknownPair", systemImage: "questionmark.circle")
            }
        }
        .guitarroScreen()
        .navigationTitle("trainer.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if session == nil { session = ChordChangeSession(pair: pair) }
        }
        .onDisappear { session?.stopAll() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session?.cancel() }
        }
    }

    private func content(_ session: ChordChangeSession) -> some View {
        ScrollView {
            VStack(spacing: GuitarroSpacing.large) {
                HStack(spacing: GuitarroSpacing.medium) {
                    ChordDiagramView(voicing: session.from, noteNaming: noteNaming, isActive: session.phase == .running && session.expected.id == session.from.id)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    ChordDiagramView(voicing: session.to, noteNaming: noteNaming, isActive: session.phase == .running && session.expected.id == session.to.id)
                }

                counter(session)
                statusLine(session)
                controls(session)
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { save(session) }
        }
        .sheet(item: $result) { state in
            ResultView(pair: pair, state: state, previousBest: previousBest, noteNaming: noteNaming) {
                result = nil
                session.start()
            } done: {
                result = nil
                dismiss()
            }
        }
    }

    private func counter(_ session: ChordChangeSession) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(Color.guitarroAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: session.progress)
            VStack(spacing: 2) {
                switch session.phase {
                case .countdown(let seconds):
                    Text(verbatim: "\(seconds)")
                        .font(.guitarroDisplay(72))
                        .contentTransition(.numericText())
                    Text("trainer.countdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                default:
                    Text(verbatim: "\(session.changes)")
                        .font(.guitarroDisplay(72))
                        .contentTransition(.numericText())
                    Text("trainer.changes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(Int(session.remaining.rounded(.up))) s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .animation(.snappy, value: session.changes)
        }
        .frame(width: 220, height: 220)
    }

    @ViewBuilder
    private func statusLine(_ session: ChordChangeSession) -> some View {
        switch session.phase {
        case .running where session.inputMode == .microphone:
            VStack(spacing: 4) {
                Text("trainer.playNow \(session.expected.chord.symbol(style: noteNaming))")
                    .font(.headline)
                if let heard = session.heardChord {
                    Text("trainer.hearing \(heard.symbol(style: noteNaming))")
                        .font(.subheadline)
                        .foregroundStyle(heard.isSameFamily(as: session.expected.chord) ? Color.guitarroInTune : Color.secondary)
                } else {
                    Text("trainer.listening.none")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        case .running:
            Text("trainer.playNow \(session.expected.chord.symbol(style: noteNaming))")
                .font(.headline)
        case .ready, .finished:
            VStack(spacing: GuitarroSpacing.small) {
                Text("trainer.instructions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let tutorial = TutorialLibrary.tutorial(for: .chordChanges(from: session.from.id, to: session.to.id, minimum: 0)) {
                    NavigationLink(value: tutorial) {
                        Label("trainer.lesson", systemImage: "play.rectangle.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.guitarroAccent)
                    }
                }
                if session.microphoneStatus == .permissionDenied {
                    Label("trainer.micDenied", systemImage: "mic.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .countdown:
            EmptyView()
        }
    }

    @ViewBuilder
    private func controls(_ session: ChordChangeSession) -> some View {
        switch session.phase {
        case .ready, .finished:
            VStack(spacing: GuitarroSpacing.medium) {
                Picker("trainer.mode", selection: Bindable(session).inputMode) {
                    Label("trainer.mode.microphone", systemImage: "mic").tag(ChordChangeSession.InputMode.microphone)
                    Label("trainer.mode.manual", systemImage: "hand.tap").tag(ChordChangeSession.InputMode.manual)
                }
                .pickerStyle(.segmented)
                Button {
                    session.start()
                } label: {
                    Label("trainer.start", systemImage: "play.fill")
                }
                .buttonStyle(.guitarroPrimary)
            }
        case .countdown:
            Button("trainer.stop") { session.cancel() }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        case .running:
            VStack(spacing: GuitarroSpacing.medium) {
                if session.inputMode == .manual {
                    Button {
                        session.registerChange()
                    } label: {
                        Text("trainer.tapChange")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .sensoryFeedback(.impact, trigger: session.changes)
                }
                Button("trainer.stop") { session.cancel() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
        }
    }

    private func save(_ session: ChordChangeSession) {
        let descriptor = FetchDescriptor<ChordChangeProgress>(predicate: #Predicate { $0.pairID == pair.id })
        let existing = try? modelContext.fetch(descriptor).first
        let current = existing?.state ?? SkillState(due: .now)
        previousBest = current.best
        let updated = ChordChangeScheduler.review(current, changesPerMinute: session.changesPerMinute)
        if let existing {
            existing.state = updated
        } else {
            modelContext.insert(ChordChangeProgress(pairID: pair.id, state: updated))
        }
        try? modelContext.save()
        result = updated
    }
}

extension SkillState: @retroactive Identifiable {
    public var id: Date { due }
}

private struct ResultView: View {
    let pair: ChordPair
    let state: SkillState
    let previousBest: Int
    let noteNaming: NoteNamingStyle
    let again: () -> Void
    let done: () -> Void

    private var rating: Int { ChordChangeScheduler.rating(changesPerMinute: state.last) }

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            Text("trainer.result.title")
                .font(.title.bold())
            PairTitle(pair: pair, noteNaming: noteNaming)
                .font(.title2)
            Text(verbatim: "\(state.last)")
                .font(.guitarroDisplay(96))
                .foregroundStyle(Color.guitarroAccent)
            Text("trainer.result.perMinute")
                .foregroundStyle(.secondary)
            RatingStars(rating: rating)
                .scaleEffect(1.6)
                .padding(.vertical, 6)
            Text(ratingKey)
                .font(.headline)
            if state.last > previousBest, previousBest > 0 {
                Label("trainer.result.newBest", systemImage: "trophy.fill")
                    .foregroundStyle(Color.guitarroInTune)
            }
            HStack(spacing: 4) {
                Text("trainer.result.nextDue")
                Text(state.due, format: .relative(presentation: .named))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: GuitarroSpacing.medium) {
                Button(action: again) {
                    Label("trainer.again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(action: done) {
                    Label("trainer.done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .buttonBorderShape(.capsule)
        }
        .padding(GuitarroSpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .guitarroScreen(glow: .gold)
        .presentationDetents([.large])
    }

    private var ratingKey: LocalizedStringKey {
        let key: String = "trainer.result.rating.\(rating)"
        return LocalizedStringKey(key)
    }
}
