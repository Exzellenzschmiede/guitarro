import AudioEngine
import Foundation
import MusicTheory
import Observation
import SongAnalysis

/// Plays an imported song with tempo control, A/B loop, chord feedback, and for system-player
/// songs a "learn run" that transcribes chords through the microphone.
@MainActor
@Observable
final class UserSongPlayer {
    enum Mode: Equatable {
        case idle
        case playing
        /// Speaker playback while the microphone transcribes the chords.
        case learning
    }

    private(set) var analysis: SongAnalysis?
    let source: UserSongSource

    private(set) var mode: Mode = .idle
    private(set) var currentTime: Double = 0
    var ratePercent = 100 { didSet { playback?.rate = Float(ratePercent) / 100 } }
    private(set) var loopStart: Double?
    private(set) var loopEnd: Double?
    var feedbackEnabled = false
    private(set) var isListening = false
    private(set) var segmentResults: [Double: Bool] = [:]
    private(set) var loadError: String?
    private(set) var learnedFrames = 0
    /// Set when a learn run finished and produced a timeline.
    private(set) var learnedAnalysis: SongAnalysis?

    private var playback: (any SongPlayback)?
    private var ticker: Task<Void, Never>?
    private var tracker: ChordTracker?
    private var listenTask: Task<Void, Never>?
    private var transcriber = LiveChordTranscriber(candidates: ChordMatcher.defaultCandidates)

    init(song: UserSong) {
        source = song.source
        analysis = song.analysis
        do {
            switch song.source {
            case .file:
                // The file player needs our session; the system player brings its own.
                try AudioSession.activate()
                playback = try FilePlayback(url: song.fileURL)
            case .appleMusic:
                guard let id = song.mediaPersistentID, let system = SystemMusicPlayback(persistentID: id) else {
                    loadError = String(localized: "usersongs.systemPlayer.missing")
                    return
                }
                playback = system
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private var playbackTask: Task<Void, Never>?

    var isPlaying: Bool { mode != .idle }
    var supportsRate: Bool { playback?.supportsRate ?? true }
    var duration: Double { max(playback?.duration ?? 0, analysis?.duration ?? 0) }
    var currentSegment: ChordSegment? { analysis?.segment(at: currentTime) }
    var nextSegment: ChordSegment? { analysis?.nextChordSegment(after: currentTime) }
    var canListen: Bool { AudioSession.isHeadphoneOutputActive }
    var needsLearnRun: Bool { analysis == nil || analysis?.segments.isEmpty == true }

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
        guard let playback, mode == .idle, playbackTask == nil else { return }
        loadError = nil
        playbackTask = Task {
            defer { playbackTask = nil }
            do {
                playback.rate = Float(ratePercent) / 100
                if let loopStart, let loopEnd, currentTime < loopStart || currentTime >= loopEnd {
                    playback.currentTime = loopStart
                }
                try await playback.play()
                mode = .playing
                startTicker()
                if feedbackEnabled, canListen {
                    listenTask = Task { await listen(transcribing: false) }
                }
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    func pause() {
        playback?.pause()
        let wasLearning = mode == .learning
        mode = .idle
        ticker?.cancel()
        ticker = nil
        stopListening()
        if wasLearning { finishLearnRun() }
    }

    func stop() {
        pause()
        playback?.stop()
        currentTime = 0
    }

    func seek(to time: Double) {
        let clamped = max(0, min(duration, time))
        playback?.currentTime = clamped
        currentTime = clamped
    }

    // MARK: Learn run (system player songs)

    /// Plays from the start through the speaker and transcribes what the microphone hears.
    func startLearnRun() {
        guard let playback, mode == .idle, playbackTask == nil else { return }
        loadError = nil
        playbackTask = Task {
            defer { playbackTask = nil }
            do {
                transcriber.reset()
                learnedFrames = 0
                learnedAnalysis = nil
                clearLoop()
                playback.rate = 1
                playback.currentTime = 0
                currentTime = 0
                try await playback.play()
                mode = .learning
                startTicker()
                listenTask = Task { await listen(transcribing: true) }
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func finishLearnRun() {
        guard !transcriber.isEmpty else { return }
        let result = transcriber.finish(duration: duration)
        learnedAnalysis = result
        analysis = result
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
                guard let self, let playback = self.playback else { return }
                self.currentTime = playback.currentTime
                if self.mode == .playing, let start = self.loopStart, let end = self.loopEnd, playback.currentTime >= end {
                    playback.currentTime = start
                }
                let ended = !playback.isPlaying && playback.currentTime >= playback.duration - 0.25
                if self.mode != .idle, ended {
                    self.pause()
                    return
                }
            }
        }
    }

    // MARK: Microphone

    private func listen(transcribing: Bool) async {
        guard await MicrophonePermission.request() else { return }
        // Activate off the main thread; the tracker's own activation is then a no-op.
        try? await AudioSession.activateAsync()
        let tracker = ChordTracker()
        guard let stream = try? tracker.start() else { return }
        self.tracker = tracker
        isListening = true
        for await estimate in stream {
            if transcribing {
                guard let playback, playback.isPlaying else { continue }
                let scores = estimate.scores.isEmpty ? [Float](repeating: 0, count: ChordMatcher.defaultCandidates.count) : estimate.scores
                transcriber.append(LiveChordTranscriber.Frame(time: playback.currentTime, scores: scores, silence: estimate.scores.isEmpty, chroma: estimate.chroma))
                learnedFrames += 1
            } else {
                guard let heard = estimate.chord, let segment = currentSegment, let expected = segment.chord else { continue }
                if segmentResults[segment.start] == nil { segmentResults[segment.start] = false }
                if heard == expected { segmentResults[segment.start] = true }
            }
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
