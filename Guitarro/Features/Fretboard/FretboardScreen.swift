import DesignSystem
import Fretboard
import MusicTheory
import SwiftUI
import UIKit

struct FretboardScreen: View {
    @State private var model = FretboardModel()
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PlayerSettingsKeys.handedness) private var handedness: Handedness = .right

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isWide = geometry.size.width >= 700 || geometry.size.width > geometry.size.height
                ScrollView {
                    VStack(spacing: GuitarroSpacing.medium) {
                        controls
                        FretboardView(
                            tuning: model.tuning,
                            fretCount: model.fretCount,
                            orientation: isWide ? .horizontal : .vertical,
                            isMirrored: handedness.mirrorsFretboard,
                            markers: model.markers(noteNaming: noteNaming),
                            mutedStrings: model.mutedStrings,
                            barre: model.barre
                        ) { position in
                            model.tap(position)
                        }
                        .frame(height: isWide ? min(340, geometry.size.height * 0.45) : max(440, geometry.size.height * 0.52))
                        listeningBanner
                        chordChips
                        infoCard
                    }
                    .padding()
                }
                .onChange(of: isWide, initial: true) { _, wide in
                    model.fretCount = wide ? 15 : 12
                }
            }
            .guitarroScreen(glow: .mint)
            .navigationTitle("fretboard.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    listenButton
                    TuningMenu(tuning: $model.tuning)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.stopAll() }
        }
        .onDisappear { model.stopAll() }
    }

    // MARK: Pieces

    private var controls: some View {
        VStack(spacing: GuitarroSpacing.small) {
            Picker("fretboard.labels", selection: $model.labelMode) {
                Text("fretboard.labels.notes").tag(FretboardModel.LabelMode.notes)
                Text("fretboard.labels.intervals").tag(FretboardModel.LabelMode.intervals)
                Text("fretboard.labels.fingers").tag(FretboardModel.LabelMode.fingers)
            }
            .pickerStyle(.segmented)

            HStack {
                Toggle("fretboard.allNotes", isOn: $model.showAllNotes)
                    .toggleStyle(.button)
                    .buttonBorderShape(.capsule)
                if model.labelMode == .intervals {
                    Spacer()
                    rootPicker
                }
                Spacer()
                if let tapped = model.lastTapped {
                    tappedLabel(for: tapped)
                }
            }
        }
    }

    private var rootPicker: some View {
        Menu {
            Picker("fretboard.root", selection: $model.root) {
                ForEach(PitchClass.allCases, id: \.self) { pitchClass in
                    Text(pitchClass.name(style: noteNaming)).tag(pitchClass)
                }
            }
        } label: {
            Label {
                Text("fretboard.root.value \(model.root.name(style: noteNaming))")
            } icon: {
                Image(systemName: "r.circle")
            }
            .font(.subheadline)
        }
    }

    private func tappedLabel(for position: FretboardPosition) -> some View {
        let pitch = model.tuning.pitch(at: position)
        let interval = Interval.between(model.root, pitch.pitchClass)
        return VStack(alignment: .trailing, spacing: 2) {
            Text(pitch.name(style: noteNaming))
                .font(.headline.monospacedDigit())
            Text(MusicText.intervalName(interval))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: position)
    }

    private var listenButton: some View {
        Button {
            model.toggleListening()
        } label: {
            Label("fretboard.listen", systemImage: model.isListening ? "mic.fill" : "mic")
                .symbolEffect(.variableColor.iterative, isActive: model.isListening)
        }
        .tint(model.isListening ? .guitarroInTune : nil)
    }

    @ViewBuilder
    private var listeningBanner: some View {
        switch model.listeningStatus {
        case .permissionDenied:
            HStack {
                Label("tuner.permission.title", systemImage: "mic.slash")
                Spacer()
                Button("tuner.permission.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            .font(.subheadline)
            .guitarroCard(cornerRadius: 14)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .guitarroCard(cornerRadius: 14)
        case .off, .listening:
            EmptyView()
        }
    }

    private var chordChips: some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            Text("fretboard.chords")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GuitarroSpacing.small) {
                    ForEach(model.voicings) { voicing in
                        let isSelected = model.selectedVoicing?.id == voicing.id
                        Button {
                            model.select(voicing)
                        } label: {
                            Text(voicing.chord.symbol(style: noteNaming))
                                .font(.headline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(isSelected ? Color.guitarroAccent : Color.secondary.opacity(0.15)))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var infoCard: some View {
        if let voicing = model.selectedVoicing {
            ChordInfoView(voicing: voicing, noteNaming: noteNaming) {
                model.playSelectedChord()
            }
        } else {
            Label("fretboard.noChord", systemImage: "hand.tap")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .guitarroCard()
        }
    }
}

#Preview {
    FretboardScreen()
}
