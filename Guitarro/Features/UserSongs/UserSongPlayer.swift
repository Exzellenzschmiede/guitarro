import AudioEngine
import AVFoundation
import Foundation
import MusicTheory
import Observation
import SongAnalysis

/// Plays an imported song with tempo control, A/B loop and chord feedback.
@MainActor
@Observable
final class UserSongPlayer {
    let analysis: SongAnalysis
    let fileURL: URL

    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    var ratePercent = 100 { didSet { player?.rate = Float(ratePercent) / 100 } }
    private(set) var loopStart: Double?
    private(set) var loopEnd: Double?
    var feedbackEnabled = false
    private(set) var isListening = false
    private(set) var segmentResults: [Double: Bool] = [:]
    private(set) var loadError: String?

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?
    private var tracker: ChordTracker?
    private var listenTask: Task<Void, Never>?

    init(fileURL: URL, analysis: SongAnalysis) {
        self.fileURL = fileURL
        self.analysis = analysis
        do {
            try AudioSession.activate()
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.enableRate = true
            player.prepareToPlay()
            self.player = player
        } catch {
            loadError = error.localizedDescription
        }
    }

    var duration: Double { player?.duration ?? analysis.duration }
    var currentSegment: ChordSegment? { analysis.segment(at: currentTime) }
    var nextSegment: ChordSegment? { analysis.nextChordSegment(after: currentTime) }
    var canListen: Bool { AudioSession.isHeadphoneOutputActive }

    var hits: Int { segmentResults.values.filter { $0 }.count }
    var accuracy: Double? {
        guard !segmentResults.isEmpty else { return nil }
        return Double(hits) / Double(segmentResults.count)
    }

    // MARK: Transport

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let player else { return }
        player.rate = Float(ratePercent) / 100
        if let loopStart, let loopEnd, currentTime < loopStart || currentTime >= loopEnd {
            player.currentTime = loopStart
        }
        player.play()
        isPlaying = true
        startTicker()
        if feedbackEnabled, canListen {
            listenTask = Task { await listen() }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        ticker?.cancel()
        ticker = nil
        stopListening()
    }

    func stop() {
        pause()
        player?.currentTime = 0
        currentTime = 0
    }

    func seek(to time: Double) {
        let clamped = max(0, min(duration, time))
        player?.currentTime = clamped
        currentTime = clamped
    }

    // MARK: Loop

    func markLoopStart() {
        loopStart = currentTime
        if let end = loopEnd, end <= currentTime { loopEnd = nil }
    }

    func markLoopEnd() {
        guard let start = loopStart, currentTime > start + 0.5 else { return }
        loopEnd = currentTime
    }

    func clearLoop() {
        loopStart = nil
        loopEnd = nil
    }

    /// Loops the segment that is playing right now.
    func loopCurrentSegment() {
        guard let segment = currentSegment else { return }
        loopStart = segment.start
        loopEnd = segment.end
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if let start = self.loopStart, let end = self.loopEnd, player.currentTime >= end {
                    player.currentTime = start
                }
                if !player.isPlaying, self.isPlaying, player.currentTime >= player.duration - 0.05 {
                    self.isPlaying = false
                    self.stopListening()
                    return
                }
            }
        }
    }

    // MARK: Feedback

    private func listen() async {
        guard await MicrophonePermission.request() else { return }
        let tracker = ChordTracker()
        guard let stream = try? tracker.start() else { return }
        self.tracker = tracker
        isListening = true
        for await estimate in stream {
            guard let heard = estimate.chord, let segment = currentSegment, let expected = segment.chord else { continue }
            if segmentResults[segment.start] == nil { segmentResults[segment.start] = false }
            if heard == expected { segmentResults[segment.start] = true }
        }
        isListening = false
    }

    private func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        tracker?.stop()
        tracker = nil
        isListening = false
    }
}
