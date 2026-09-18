import AVFoundation
import Foundation
import MediaPlayer

/// Transport abstraction over a local file player and the system music player.
@MainActor
protocol SongPlayback: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: Double { get set }
    var duration: Double { get }
    /// 1 = normal speed. The system player may ignore rates for streamed tracks.
    var rate: Float { get set }
    var supportsRate: Bool { get }
    /// Starts playback, preparing the player first if needed.
    func play() async throws
    func pause()
    func stop()
}

enum SongPlaybackError: Error, LocalizedError {
    case prepareFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let message): String(format: String(localized: "usersongs.systemPlayer.prepareFailed %@"), message)
        }
    }
}

/// AVAudioPlayer-backed playback for DRM-free files (pitch-preserving rate).
@MainActor
final class FilePlayback: SongPlayback {
    private let player: AVAudioPlayer

    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player.enableRate = true
        player.prepareToPlay()
    }

    var isPlaying: Bool { player.isPlaying }
    var currentTime: Double {
        get { player.currentTime }
        set { player.currentTime = max(0, min(player.duration, newValue)) }
    }
    var duration: Double { player.duration }
    var rate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }
    var supportsRate: Bool { true }

    func play() async throws { player.play() }
    func pause() { player.pause() }
    func stop() {
        player.stop()
        player.currentTime = 0
    }
}

/// System music player: plays library items including Apple Music streams.
@MainActor
final class SystemMusicPlayback: SongPlayback {
    private let player = MPMusicPlayerController.applicationMusicPlayer
    private let itemDuration: Double
    private var prepared = false

    init?(persistentID: String) {
        guard let id = UInt64(persistentID) else { return nil }
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: id), forProperty: MPMediaItemPropertyPersistentID))
        guard let items = query.items, let item = items.first else { return nil }
        itemDuration = item.playbackDuration
        player.setQueue(with: MPMediaItemCollection(items: [item]))
        player.repeatMode = .none
        player.shuffleMode = .off
    }

    /// Prepares the queue once; the system reports subscription and network problems here.
    private func prepareIfNeeded() async throws {
        guard !prepared else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            player.prepareToPlay { error in
                if let error {
                    continuation.resume(throwing: SongPlaybackError.prepareFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
        prepared = true
    }

    var isPlaying: Bool { player.playbackState == .playing }
    var currentTime: Double {
        get { player.currentPlaybackTime }
        set { player.currentPlaybackTime = max(0, min(duration, newValue)) }
    }
    var duration: Double { player.nowPlayingItem?.playbackDuration ?? itemDuration }
    var rate: Float {
        get { player.currentPlaybackRate }
        set { player.currentPlaybackRate = newValue }
    }
    /// Rate changes are applied on a best-effort basis; streamed tracks often ignore them.
    var supportsRate: Bool { false }

    func play() async throws {
        try await prepareIfNeeded()
        player.play()
    }

    func pause() { player.pause() }
    func stop() {
        player.stop()
        player.currentPlaybackTime = 0
    }
}
