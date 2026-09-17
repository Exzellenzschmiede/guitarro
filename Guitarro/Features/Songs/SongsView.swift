import DesignSystem
import MusicTheory
import Songs
import SwiftUI

struct SongsView: View {
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(StoreManager.self) private var store
    @State private var showsPaywall = false

    private var songs: [Song] { SongLibrary.songs.sorted { $0.difficulty < $1.difficulty } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        let needsPro = index >= FreeTier.songs && !store.hasPro
                        if needsPro {
                            Button {
                                showsPaywall = true
                            } label: {
                                SongRow(song: song, noteNaming: noteNaming, needsPro: true)
                            }
                            .guitarroRow()
                        } else {
                            NavigationLink(value: song) {
                                SongRow(song: song, noteNaming: noteNaming, needsPro: false)
                            }
                            .guitarroRow()
                        }
                    }
                } footer: {
                    Text("songs.footer")
                }
            }
            .guitarroScreen(glow: .rose)
            .navigationTitle("tab.songs")
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .navigationDestination(for: Song.self) { song in
                SongPlayerView(song: song)
            }
        }
    }
}

private struct SongRow: View {
    let song: Song
    let noteNaming: NoteNamingStyle
    var needsPro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.title)
                    .font(.headline)
                if needsPro {
                    GuitarroPill("pro.badge", tint: Color(red: 1.0, green: 0.84, blue: 0.4))
                }
            }
            HStack(spacing: 8) {
                Text(song.artist)
                Text(verbatim: "·")
                Text(song.key)
                Text(verbatim: "·")
                Text(verbatim: "\(song.beatsPerMinute) BPM")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                DifficultyBadge(difficulty: song.difficulty)
                ForEach(song.chordIDs, id: \.self) { id in
                    Text(ChordLibrary.voicing(id: id)?.chord.symbol(style: noteNaming) ?? id)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DifficultyBadge: View {
    let difficulty: Song.Difficulty

    var body: some View {
        Text(key)
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundStyle(color)
    }

    private var key: LocalizedStringKey {
        switch difficulty {
        case .beginner: "songs.difficulty.beginner"
        case .easy: "songs.difficulty.easy"
        case .intermediate: "songs.difficulty.intermediate"
        }
    }

    private var color: Color {
        switch difficulty {
        case .beginner: .guitarroInTune
        case .easy: .guitarroAccent
        case .intermediate: .guitarroSharp
        }
    }
}
