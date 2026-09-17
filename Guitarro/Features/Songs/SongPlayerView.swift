import DesignSystem
import MusicTheory
import Songs
import SwiftUI

struct SongPlayerView: View {
    let song: Song

    @State private var player: SongPlayer?
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let player {
                content(player)
            } else {
                ProgressView()
            }
        }
        .guitarroScreen(glow: .rose)
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil { player = SongPlayer(song: song) }
        }
        .onDisappear { player?.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player?.stop() }
        }
    }

    private func content(_ player: SongPlayer) -> some View {
        ScrollView {
            VStack(spacing: GuitarroSpacing.large) {
                header
                chordDisplay(player)
                timeline(player)
                transport(player)
                settings(player)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: GuitarroSpacing.medium) {
            Label { Text(song.key) } icon: { Image(systemName: "music.quarternote.3") }
            Label { Text(verbatim: "\(song.beatsPerMinute) BPM") } icon: { Image(systemName: "metronome") }
            Label { Text(verbatim: "\(song.beatsPerBar)/4") } icon: { Image(systemName: "square.split.2x1") }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func chordDisplay(_ player: SongPlayer) -> some View {
        HStack(alignment: .center, spacing: GuitarroSpacing.large) {
            if let voicing = ChordLibrary.voicing(id: player.currentChordID) {
                ChordDiagramView(voicing: voicing, noteNaming: noteNaming, isActive: player.state == .playing)
            }
            VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                switch player.state {
                case .countIn(let count):
                    Text("song.countIn")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(count)")
                        .font(.guitarroDisplay(64))
                        .foregroundStyle(Color.guitarroAccent)
                        .contentTransition(.numericText())
                default:
                    Text("song.now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(symbol(player.currentChordID))
                        .font(.guitarroDisplay(56))
                    if let next = player.nextChordID {
                        Text("song.next \(symbol(next))")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    beatDots(player)
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.snappy, value: player.currentChordID)
    }

    private func beatDots(_ player: SongPlayer) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<player.timeline.beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(player.state == .playing && beat == player.currentBeat ? Color.guitarroAccent : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func timeline(_ player: SongPlayer) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(player.timeline.bars) { bar in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bar.isSectionStart ? bar.sectionName : " ")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            barCell(bar, player: player)
                        }
                        .id(bar.index)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: player.currentBarIndex) { _, index in
                withAnimation(.snappy) { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }

    private func barCell(_ bar: TimelineBar, player: SongPlayer) -> some View {
        let isCurrent = player.isPlaying && bar.index == player.currentBarIndex
        let result = player.barResults[bar.index]
        return Text(bar.bar.chords.map(symbol).joined(separator: " "))
            .font(.subheadline.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCurrent ? Color.guitarroAccent : Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(resultColor(result), lineWidth: 2)
            )
            .foregroundStyle(isCurrent ? Color.white : Color.primary)
    }

    private func resultColor(_ result: Bool?) -> Color {
        switch result {
        case .some(true): .guitarroInTune
        case .some(false): Color.guitarroSharp.opacity(0.7)
        case nil: .clear
        }
    }

    private func transport(_ player: SongPlayer) -> some View {
        VStack(spacing: GuitarroSpacing.small) {
            Button {
                if player.isPlaying { player.stop() } else { player.play() }
            } label: {
                Label(player.isPlaying ? "song.stop" : "song.play", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.guitarroPrimary(.rose))

            if player.accuracy != nil || player.isListening {
                HStack {
                    Label("song.feedback.listening", systemImage: "mic.fill")
                        .foregroundStyle(Color.guitarroInTune)
                    Spacer()
                    if let accuracy = player.accuracy {
                        Text("song.feedback.hits \(player.hits) \(player.barResults.count)")
                        Text(verbatim: "(\(Int((accuracy * 100).rounded())) %)")
                    }
                }
                .font(.subheadline)
            } else if player.microphoneDenied {
                Label("trainer.micDenied", systemImage: "mic.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settings(_ player: SongPlayer) -> some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("song.tempo")
                    Spacer()
                    Text(verbatim: "\(player.tempoPercent) % · \(player.song.beatsPerMinute * player.tempoPercent / 100) BPM")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { Double(player.tempoPercent) }, set: { player.tempoPercent = Int($0) }), in: 50...120, step: 5)
            }

            if player.song.sections.count > 1 {
                Picker("song.loop", selection: Bindable(player).loopSection) {
                    Text("song.loop.all").tag(Int?.none)
                    ForEach(Array(player.song.sections.enumerated()), id: \.offset) { index, section in
                        Text(section.name).tag(Int?.some(index))
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("song.backing", isOn: Bindable(player).backingEnabled)
            Toggle("song.metronome", isOn: Bindable(player).metronomeEnabled)
            Toggle("song.feedback", isOn: Bindable(player).feedbackEnabled)
            if player.feedbackEnabled, !player.canListen {
                Label("song.feedback.needsHeadphones", systemImage: "headphones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(player.isPlaying)
        .guitarroCard()
    }

    private func symbol(_ chordID: String) -> String {
        ChordLibrary.voicing(id: chordID)?.chord.symbol(style: noteNaming) ?? chordID
    }
}
