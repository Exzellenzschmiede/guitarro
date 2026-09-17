import Foundation
import SongAnalysis
import SwiftData

/// A song the player imported from their library or a file, with its cached analysis.
@Model
final class UserSong {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    /// File name inside `UserSongStore.directory`.
    var fileName: String
    var durationSeconds: Double
    var analysisData: Data
    var createdAt: Date

    init(id: UUID = UUID(), title: String, artist: String, fileName: String, analysis: SongAnalysis, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        durationSeconds = analysis.duration
        analysisData = (try? JSONEncoder().encode(analysis)) ?? Data()
        self.createdAt = createdAt
    }

    var analysis: SongAnalysis? {
        try? JSONDecoder().decode(SongAnalysis.self, from: analysisData)
    }

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
        try? FileManager.default.removeItem(at: song.fileURL)
    }
}
