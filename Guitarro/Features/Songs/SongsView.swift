import DesignSystem
import MediaPlayer
import MusicTheory
import Songs
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SongsView: View {
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSong.createdAt, order: .reverse) private var userSongs: [UserSong]

    @State private var importer = SongImporter()
    @State private var showsPaywall = false
    @State private var showsMediaPicker = false
    @State private var showsFileImporter = false
    @State private var libraryDenied = false

    private var songs: [Song] { SongLibrary.songs.sorted { $0.difficulty < $1.difficulty } }

    var body: some View {
        NavigationStack {
            List {
                userSongsSection
                Section("songs.section.learn") {
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
                }
            }
            .guitarroScreen(glow: .rose)
            .navigationTitle("tab.songs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            addFromLibrary()
                        } label: {
                            Label("usersongs.add.library", systemImage: "music.note.house")
                        }
                        Button {
                            guard store.hasPro else { showsPaywall = true; return }
                            showsFileImporter = true
                        } label: {
                            Label("usersongs.add.file", systemImage: "folder")
                        }
                        #if DEBUG
                        Button {
                            guard store.hasPro else { showsPaywall = true; return }
                            Task { await importer.importDemo(into: modelContext) }
                        } label: {
                            Label("usersongs.add.demo", systemImage: "wand.and.stars")
                        }
                        #endif
                    } label: {
                        Label("usersongs.add", systemImage: "plus")
                    }
                    .disabled(importer.isBusy)
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsMediaPicker) {
                MediaPickerView { item in
                    showsMediaPicker = false
                    if let item {
                        Task { await importer.importMediaItem(item, into: modelContext) }
                    }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result {
                    Task { await importer.importFile(url, into: modelContext) }
                }
            }
            .sheet(isPresented: Binding(get: { importer.phase != .idle }, set: { if !$0 { importer.reset() } })) {
                ImportProgressView(importer: importer)
                    .presentationDetents([.medium])
            }
            .alert("usersongs.libraryDenied", isPresented: $libraryDenied) {
                Button("common.close", role: .cancel) {}
            }
            .navigationDestination(for: Song.self) { song in
                SongPlayerView(song: song)
            }
            .navigationDestination(for: UserSong.self) { song in
                UserSongPlayerView(song: song)
            }
        }
    }

    private var userSongsSection: some View {
        Section {
            if userSongs.isEmpty {
                VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                    Text("usersongs.empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("usersongs.protectedHint")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button {
                        addFromLibrary()
                    } label: {
                        Label("usersongs.add", systemImage: "plus")
                    }
                    .buttonStyle(.guitarroPrimary(.rose))
                }
                .guitarroRow()
            } else {
                ForEach(userSongs) { song in
                    NavigationLink(value: song) {
                        UserSongRow(song: song, noteNaming: noteNaming)
                    }
                    .guitarroRow()
                }
                .onDelete { offsets in
                    for index in offsets {
                        let song = userSongs[index]
                        UserSongStore.delete(song)
                        modelContext.delete(song)
                    }
                    try? modelContext.save()
                }
            }
        } header: {
            HStack {
                Text("usersongs.section")
                if !store.hasPro {
                    GuitarroPill("pro.badge", tint: Color(red: 1.0, green: 0.84, blue: 0.4))
                }
            }
        }
    }

    private func addFromLibrary() {
        guard store.hasPro else {
            showsPaywall = true
            return
        }
        Task {
            if await MPMediaLibrary.requestAccess() {
                showsMediaPicker = true
            } else {
                libraryDenied = true
            }
        }
    }
}

private struct UserSongRow: View {
    let song: UserSong
    let noteNaming: NoteNamingStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.title)
                    .font(.headline)
                if song.source == .appleMusic {
                    Image(systemName: "music.note.house").font(.caption).foregroundStyle(.secondary)
                }
                if !song.hasAnalysis {
                    GuitarroPill("usersongs.needsLearn", tint: .guitarroAccent)
                }
            }
            HStack(spacing: 8) {
                if !song.artist.isEmpty {
                    Text(song.artist)
                    Text(verbatim: "·")
                }
                if let key = song.analysis?.key {
                    Text(key.name(style: noteNaming))
                    Text(verbatim: "·")
                }
                if let bpm = song.analysis?.beatsPerMinute {
                    Text(verbatim: "\(bpm) BPM")
                    Text(verbatim: "·")
                }
                Text(verbatim: timeString(song.durationSeconds))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let chords = song.analysis?.chords {
                HStack(spacing: 6) {
                    ForEach(chords.prefix(6), id: \.self) { chord in
                        Text(chord.symbol(style: noteNaming))
                            .font(.caption.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    if chords.count > 6 {
                        Text(verbatim: "+\(chords.count - 6)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct ImportProgressView: View {
    let importer: SongImporter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: GuitarroSpacing.large) {
            GuitarroIconBadge(symbol, size: 72, palette: .rose)
            Text(importer.currentTitle)
                .font(.guitarroHeadline)
                .multilineTextAlignment(.center)
            switch importer.phase {
            case .preparing:
                ProgressView()
                Text("usersongs.phase.preparing").foregroundStyle(.secondary)
            case .decoding(let progress):
                ProgressView(value: progress).tint(.guitarroAccent).frame(maxWidth: 320)
                Text("usersongs.phase.decoding").foregroundStyle(.secondary)
            case .analysing(let progress):
                ProgressView(value: progress).tint(.guitarroAccent).frame(maxWidth: 320)
                Text("usersongs.phase.analysing").foregroundStyle(.secondary)
            case .done:
                Text("usersongs.phase.done").foregroundStyle(Color.guitarroInTune)
                Button("common.close") { dismiss() }.buttonStyle(.guitarroPrimary(.rose)).frame(maxWidth: 240)
            case .failed(let message):
                Text("usersongs.phase.failed").foregroundStyle(Color.guitarroSharp)
                Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("common.close") { dismiss() }.buttonStyle(.guitarroSecondary).frame(maxWidth: 240)
            case .idle:
                EmptyView()
            }
        }
        .padding(GuitarroSpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .guitarroScreen(glow: .rose)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(importer.isBusy)
    }

    private var symbol: String {
        switch importer.phase {
        case .done: "checkmark"
        case .failed: "exclamationmark.triangle"
        default: "waveform"
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
