import Foundation
import SongAnalysis
import SwiftData

/// Where a user song's audio lives.
enum UserSongSource: String {
    /// A DRM-free copy in the app container, analysed offline.
    case file
    /// A library item (possibly an Apple Music stream) played by the system music player;
    /// chords are transcribed through the microphone on a learn run.
    case appleMusic
}

/// A song the player imported from their library or a file, with its cached analysis.
@Model
final class UserSong {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    /// File name inside `UserSongStore.directory` (empty for system-player songs).
    var fileName: String
    var durationSeconds: Double
    var analysisData: Data
    var createdAt: Date
    var sourceKindRaw: String = UserSongSource.file.rawValue
    /// `MPMediaItem.persistentID`, stored as text.
    var mediaPersistentID: String?

    init(id: UUID = UUID(), title: String, artist: String, fileName: String, analysis: SongAnalysis?, createdAt: Date = .now, source: UserSongSource = .file, mediaPersistentID: String? = nil, duration: Double = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        durationSeconds = analysis?.duration ?? duration
        analysisData = analysis.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        self.createdAt = createdAt
        sourceKindRaw = source.rawValue
        self.mediaPersistentID = mediaPersistentID
    }

    var source: UserSongSource { UserSongSource(rawValue: sourceKindRaw) ?? .file }

    var analysis: SongAnalysis? {
        get { analysisData.isEmpty ? nil : try? JSONDecoder().decode(SongAnalysis.self, from: analysisData) }
        set {
            analysisData = newValue.flatMap { try? JSONEncoder().encode($0) } ?? Data()
            if let newValue { durationSeconds = newValue.duration }
        }
    }

    var hasAnalysis: Bool { !analysisData.isEmpty }

    var fileURL: URL { UserSongStore.directory.appendingPathComponent(fileName) }
}

enum UserSongStore {
    /// Application Support/UserSongs, created on demand.
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("UserSongs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func newFileURL(extension ext: String) -> URL {
        directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    static func delete(_ song: UserSong) {
        guard song.source == .file else { return }
        try? FileManager.default.removeItem(at: song.fileURL)
    }
}
