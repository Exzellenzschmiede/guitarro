import DesignSystem
import MusicTheory
import SongAnalysis
import SwiftUI

struct UserSongPlayerView: View {
    let song: UserSong

    @State private var player: UserSongPlayer?
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let player {
                content(player)
            } else if let analysis = song.analysis {
                Color.clear.onAppear { player = UserSongPlayer(fileURL: song.fileURL, analysis: analysis) }
            } else {
                ContentUnavailableView("usersongs.noAnalysis", systemImage: "waveform.slash")
            }
        }
        .guitarroScreen(glow: .rose)
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player?.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player?.pause() }
        }
    }

    private func content(_ player: UserSongPlayer) -> some View {
        ScrollView {
            VStack(spacing: GuitarroSpacing.large) {
                header(player)
                if let error = player.loadError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Color.guitarroSharp)
                }
                chordDisplay(player)
                timeline(player)
                transport(player)
                loopControls(player)
                feedback(player)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(_ player: UserSongPlayer) -> some View {
        HStack(spacing: GuitarroSpacing.medium) {
            if !song.artist.isEmpty {
                Text(song.artist)
            }
            if let key = player.analysis.key {
                Label { Text(key.name(style: noteNaming)) } icon: { Image(systemName: "music.quarternote.3") }
            }
            if let bpm = player.analysis.beatsPerMinute {
                Label { Text(verbatim: "\(bpm) BPM") } icon: { Image(systemName: "metronome") }
            }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func chordDisplay(_ player: UserSongPlayer) -> some View {
        let segment = player.currentSegment
        let chord = segment?.chord
        return HStack(alignment: .center, spacing: GuitarroSpacing.large) {
            if let chord, let voicing = ChordLibrary.openChords.first(where: { $0.chord == chord }) {
                ChordDiagramView(voicing: voicing, noteNaming: noteNaming, isActive: player.isPlaying)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 150, height: 180)
                    .overlay(Image(systemName: chord == nil ? "pause.circle" : "questionmark").font(.largeTitle).foregroundStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                Text("song.now").font(.subheadline).foregroundStyle(.secondary)
                Text(chord?.symbol(style: noteNaming) ?? "–")
                    .font(.guitarroDisplay(56))
                    .foregroundStyle(Color.guitarroCream)
                if let next = player.nextSegment?.chord {
                    Text("song.next \(next.symbol(style: noteNaming))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: "\(timeString(player.currentTime)) / \(timeString(player.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .animation(.snappy, value: segment?.start)
    }

    private func timeline(_ player: UserSongPlayer) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(player.analysis.segments) { segment in
                        let isCurrent = segment.contains(player.currentTime)
                        let inLoop = isInLoop(segment, player: player)
                        Text(segment.chord?.symbol(style: noteNaming) ?? "·")
                            .font(.caption.bold())
                            .lineLimit(1)
                            .frame(width: max(30, segment.duration * 22), height: 36)
                            .background(RoundedRectangle(cornerRadius: 8).fill(isCurrent ? Color.guitarroAccent : (inLoop ? Color.guitarroFlat.opacity(0.35) : Color.white.opacity(0.08))))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(resultColor(player.segmentResults[segment.start]), lineWidth: 2))
                            .foregroundStyle(isCurrent ? Color.guitarroInk : Color.guitarroCream)
                            .id(segment.start)
                            .onTapGesture { player.seek(to: segment.start) }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: player.currentSegment?.start) { _, start in
                if let start { withAnimation(.snappy) { proxy.scrollTo(start, anchor: .center) } }
            }
        }
    }

    private func transport(_ player: UserSongPlayer) -> some View {
        VStack(spacing: GuitarroSpacing.small) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }), in: 0...max(1, player.duration))
                .tint(.guitarroAccent)
            HStack(spacing: GuitarroSpacing.medium) {
                Button { player.stop() } label: { Image(systemName: "backward.end.fill").font(.title2) }
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.guitarroAccentGradient)
                }
                Button { player.loopCurrentSegment() } label: { Image(systemName: "repeat.1").font(.title2) }
            }
            HStack {
                Text("song.tempo")
                Spacer()
                Text(verbatim: "\(player.ratePercent) %").monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: Binding(get: { Double(player.ratePercent) }, set: { player.ratePercent = Int($0) }), in: 50...100, step: 5)
        }
        .guitarroCard()
    }

    private func loopControls(_ player: UserSongPlayer) -> some View {
        HStack(spacing: GuitarroSpacing.small) {
            Button { player.markLoopStart() } label: {
                Label(player.loopStart.map { "A \(timeString($0))" } ?? "A", systemImage: "a.circle")
            }
            .buttonStyle(.guitarroSecondary)
            Button { player.markLoopEnd() } label: {
                Label(player.loopEnd.map { "B \(timeString($0))" } ?? "B", systemImage: "b.circle")
            }
            .buttonStyle(.guitarroSecondary)
            .disabled(player.loopStart == nil)
            Button { player.clearLoop() } label: { Image(systemName: "xmark.circle") }
                .buttonStyle(.guitarroSecondary)
                .frame(maxWidth: 60)
                .disabled(player.loopStart == nil)
        }
    }

    private func feedback(_ player: UserSongPlayer) -> some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            Toggle("song.feedback", isOn: Bindable(player).feedbackEnabled)
                .disabled(player.isPlaying)
            if player.feedbackEnabled, !player.canListen {
                Label("usersongs.feedback.needsHeadphones", systemImage: "headphones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let accuracy = player.accuracy {
                Text("song.feedback.hits \(player.hits) \(player.segmentResults.count)") + Text(verbatim: " (\(Int((accuracy * 100).rounded())) %)")
            }
        }
        .font(.subheadline)
        .guitarroCard()
    }

    private func isInLoop(_ segment: ChordSegment, player: UserSongPlayer) -> Bool {
        guard let start = player.loopStart else { return false }
        let end = player.loopEnd ?? player.duration
        return segment.end > start && segment.start < end
    }

    private func resultColor(_ result: Bool?) -> Color {
        switch result {
        case .some(true): .guitarroInTune
        case .some(false): Color.guitarroSharp.opacity(0.7)
        case nil: .clear
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
