import AudioEngine
import AVKit
import DesignSystem
import Fretboard
import MusicTheory
import Story
import SwiftUI
import Tutorials

/// Renders a tutorial step's illustration with light animation.
struct TutorialIllustrationView: View {
    let illustration: TutorialIllustration
    let palette: GuitarroPalette
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @AppStorage(PlayerSettingsKeys.handedness) private var handedness: Handedness = .right

    var body: some View {
        Group {
            switch illustration {
            case .symbol(let name):
                GuitarroIconBadge(name, size: 120, palette: palette)
                    .padding(.vertical, GuitarroSpacing.large)
            case .chord(let id):
                if let voicing = ChordLibrary.voicing(id: id) {
                    AnimatedChordView(voicing: voicing, noteNaming: noteNaming, mirrored: handedness.mirrorsFretboard)
                }
            case .chordChange(let from, let to):
                if let a = ChordLibrary.voicing(id: from), let b = ChordLibrary.voicing(id: to) {
                    ChordChangeIllustration(from: a, to: b, noteNaming: noteNaming)
                }
            case .strum(let strokes):
                StrumPatternView(strokes: strokes, palette: palette)
            case .tuning:
                TuningIllustration()
            case .fretboardNotes(let notes):
                FretboardNotesIllustration(notes: notes.map { Pitch(midiNumber: $0) }, noteNaming: noteNaming, mirrored: handedness.mirrorsFretboard)
            case .video(let urlString):
                if let url = URL(string: urlString) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    GuitarroIconBadge("video.slash", size: 96, palette: palette)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Fingers land on the fretboard one by one, then the whole chord pulses.
struct AnimatedChordView: View {
    let voicing: ChordVoicing
    let noteNaming: NoteNamingStyle
    let mirrored: Bool

    @State private var revealed = 0

    private var fretted: [(position: FretboardPosition, finger: Int)] {
        voicing.strings.enumerated().compactMap { string, action in
            guard let fret = action.fret, fret > 0, let finger = action.finger else { return nil }
            return (FretboardPosition(string: string, fret: fret), finger)
        }
        .sorted { $0.finger < $1.finger }
    }

    var body: some View {
        VStack(spacing: GuitarroSpacing.small) {
            Text(voicing.chord.symbol(style: noteNaming))
                .font(.guitarroTitle)
            FretboardView(
                tuning: .standard,
                fretCount: max(4, voicing.highestFret),
                orientation: .vertical,
                isMirrored: mirrored,
                markers: markers,
                mutedStrings: voicing.mutedStrings,
                barre: revealed >= fretted.count ? voicing.barre.map { FretboardBarre(fret: $0.fret, fromString: $0.fromString, toString: $0.toString) } : nil
            )
            .frame(width: 200, height: 240)
            Text(revealed < fretted.count ? "tutorial.chord.placing \(revealed + 1)" : "tutorial.chord.strum")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            while !Task.isCancelled {
                for step in 0...fretted.count {
                    revealed = step
                    try? await Task.sleep(for: .milliseconds(step == fretted.count ? 1600 : 700))
                    if Task.isCancelled { return }
                }
            }
        }
    }

    private var markers: [FretboardMarker] {
        var result: [FretboardMarker] = []
        for (string, action) in voicing.strings.enumerated() where action.fret == 0 {
            let position = FretboardPosition(string: string, fret: 0)
            result.append(FretboardMarker(position: position, label: "0", style: .chordTone))
        }
        for (index, entry) in fretted.enumerated() where index < revealed {
            let isRoot = Tuning.standard.pitch(at: entry.position).pitchClass == voicing.chord.root
            result.append(FretboardMarker(position: entry.position, label: "\(entry.finger)", style: isRoot ? .root : .chordTone))
        }
        return result
    }
}

/// Alternates between two chords to show which fingers move.
struct ChordChangeIllustration: View {
    let from: ChordVoicing
    let to: ChordVoicing
    let noteNaming: NoteNamingStyle

    @State private var showsSecond = false

    var body: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            ChordDiagramView(voicing: from, noteNaming: noteNaming, isActive: !showsSecond)
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(.secondary)
            ChordDiagramView(voicing: to, noteNaming: noteNaming, isActive: showsSecond)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1400))
                withAnimation(.snappy) { showsSecond.toggle() }
            }
        }
    }
}

/// Eight eighth-note slots with down/up arrows, a moving beat cursor and an audible demo.
struct StrumPatternView: View {
    let strokes: [Stroke]
    let palette: GuitarroPalette

    @State private var beat = -1
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?
    @State private var player = TonePlayer()

    private let slotDuration = 0.3

    var body: some View {
        VStack(spacing: GuitarroSpacing.medium) {
            HStack(spacing: 6) {
                ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                    VStack(spacing: 6) {
                        Text(index.isMultiple(of: 2) ? "\(index / 2 + 1)" : "+")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(beat == index ? palette.gradient : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            Image(systemName: symbol(for: stroke))
                                .font(.title3.bold())
                                .foregroundStyle(stroke == .rest ? Color.secondary.opacity(0.5) : (beat == index ? Color.guitarroInk : Color.guitarroCream))
                        }
                        .frame(height: 52)
                    }
                }
            }
            Button {
                isPlaying ? stopDemo() : startDemo()
            } label: {
                Label(isPlaying ? "song.stop" : "tutorial.strum.listen", systemImage: isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.guitarroSecondary)
            .frame(maxWidth: 240)
        }
        .onDisappear { stopDemo() }
    }

    private func symbol(for stroke: Stroke) -> String {
        switch stroke {
        case .down: "arrow.down"
        case .up: "arrow.up"
        case .rest: "minus"
        }
    }

    private func startDemo() {
        isPlaying = true
        let frequencies = ChordLibrary.voicing(id: "Em")!.pitches(in: .standard).map { $0.frequency() }
        playTask = Task {
            while !Task.isCancelled {
                for (index, stroke) in strokes.enumerated() {
                    beat = index
                    switch stroke {
                    case .down: player.strum(frequencies: frequencies, spacing: 0.02, velocity: index.isMultiple(of: 2) ? 0.7 : 0.5)
                    case .up: player.strum(frequencies: frequencies.reversed(), spacing: 0.02, velocity: 0.4)
                    case .rest: break
                    }
                    try? await Task.sleep(for: .seconds(slotDuration))
                    if Task.isCancelled { return }
                }
            }
        }
    }

    private func stopDemo() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        beat = -1
        player.stop()
    }
}

/// The tuner needle drifting in from flat and settling green.
struct TuningIllustration: View {
    @State private var cents: Double = -32
    @State private var inTune = false

    var body: some View {
        VStack(spacing: 4) {
            Text(inTune ? "tuner.status.inTune" : "tuner.status.flat")
                .font(.guitarroHeadline)
                .foregroundStyle(inTune ? Color.guitarroInTune : Color.guitarroFlat)
            TunerGaugeView(cents: cents, isInTune: inTune)
                .frame(maxWidth: 360)
                .frame(height: 170)
        }
        .task {
            while !Task.isCancelled {
                cents = -32
                inTune = false
                for value in stride(from: -32.0, through: 0, by: 2) {
                    try? await Task.sleep(for: .milliseconds(90))
                    if Task.isCancelled { return }
                    cents = value
                }
                inTune = true
                try? await Task.sleep(for: .seconds(1.8))
            }
        }
    }
}

/// Highlights the given notes on a horizontal fretboard.
struct FretboardNotesIllustration: View {
    let notes: [Pitch]
    let noteNaming: NoteNamingStyle
    let mirrored: Bool

    var body: some View {
        FretboardView(
            tuning: .standard,
            fretCount: 5,
            orientation: .horizontal,
            isMirrored: mirrored,
            markers: notes.flatMap { pitch in
                Tuning.standard.positions(of: pitch, maxFret: 0).map {
                    FretboardMarker(position: $0, label: pitch.name(style: noteNaming, includeOctave: false), style: .root)
                }
            }
        )
        .frame(height: 200)
    }
}
