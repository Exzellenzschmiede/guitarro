import AudioEngine
import Foundation
import MusicTheory
import Observation
import Songs

/// Plays a song's chord progression with backing strums and a metronome, and listens for the chords.
@MainActor
@Observable
final class SongPlayer {
    enum State: Equatable {
        case stopped
        case countIn(Int)
        case playing
    }

    let timeline: SongTimeline

    var tempoPercent = 100
    var backingEnabled = true
    var metronomeEnabled = true
    var feedbackEnabled = true
    var loopSection: Int?
    /// Challenges play one pass and stop.
    var stopsAfterOnePass = false

    private(set) var state: State = .stopped
    private(set) var currentBarIndex = 0
    private(set) var currentBeat = 0
    private(set) var barResults: [Int: Bool] = [:]
    private(set) var isListening = false
    private(set) var microphoneDenied = false
    private(set) var passes = 0
    private(set) var didFinishPass = false

    private let player = TonePlayer()
    private var tracker: ChordTracker?
    private var playTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?

    init(song: Song) {
        timeline = SongTimeline(song: song)
    }

    var song: Song { timeline.song }
    var isPlaying: Bool { state != .stopped }

    var currentChordID: String {
        timeline.bars[currentBarIndex].bar.chord(atBeat: currentBeat, beatsPerBar: timeline.beatsPerBar)
    }

    var nextChordID: String? {
        timeline.nextChord(after: currentBarIndex, in: timeline.range(forSection: loopSection))
    }

    /// Listening only makes sense when the microphone will not hear our own backing.
    var canListen: Bool { !backingEnabled || AudioSession.isHeadphoneOutputActive }

    var accuracy: Double? {
        guard !barResults.isEmpty else { return nil }
        return Double(barResults.values.filter { $0 }.count) / Double(barResults.count)
    }

    var hits: Int { barResults.values.filter { $0 }.count }

    // MARK: Transport

    func play() {
        guard state == .stopped else { return }
        barResults.removeAll()
        passes = 0
        didFinishPass = false
        let range = timeline.range(forSection: loopSection)
        currentBarIndex = range.lowerBound
        currentBeat = 0
        state = .countIn(timeline.beatsPerBar)
        if feedbackEnabled, canListen {
            listenTask = Task { await listen() }
        }
        playTask = Task { await run() }
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        stopListening()
        state = .stopped
        player.stop()
    }

    private func run() async {
        let clock = ContinuousClock()
        var next = clock.now
        let beats = timeline.beatsPerBar

        for beat in 0..<beats {
            state = .countIn(beats - beat)
            player.click(accent: beat == 0)
            next += .seconds(timeline.secondsPerBeat(tempoPercent: tempoPercent))
            try? await clock.sleep(until: next, tolerance: .milliseconds(2))
            if Task.isCancelled { return }
        }

        state = .playing
        while !Task.isCancelled {
            let range = timeline.range(forSection: loopSection)
            for beat in timeline.beats(in: range) {
                if Task.isCancelled { return }
                currentBarIndex = beat.barIndex
                currentBeat = beat.beat
                if beat.isDownbeat, isListening {
                    barResults[beat.barIndex] = false
                }
                if metronomeEnabled {
                    player.click(accent: beat.isDownbeat)
                }
                if backingEnabled {
                    strum(beat)
                }
                next += .seconds(timeline.secondsPerBeat(tempoPercent: tempoPercent))
                try? await clock.sleep(until: next, tolerance: .milliseconds(2))
            }
            passes += 1
            if stopsAfterOnePass {
                stopListening()
                state = .stopped
                didFinishPass = true
                return
            }
        }
    }

    private func strum(_ beat: PlaybackBeat) {
        guard let voicing = ChordLibrary.voicing(id: beat.chordID) else { return }
        let frequencies = voicing.pitches(in: .standard).map { $0.frequency() }
        player.strum(frequencies: frequencies, spacing: 0.025, velocity: beat.isDownbeat ? 0.7 : 0.45)
        // A light upstroke on the off-beat keeps the groove going.
        if timeline.beatsPerBar == 4, beat.beat == 1 || beat.beat == 3 {
            let half = timeline.secondsPerBeat(tempoPercent: tempoPercent) / 2
            player.strum(frequencies: frequencies.reversed(), spacing: 0.02, velocity: 0.3, delay: half)
        }
    }

    // MARK: Listening

    private func listen() async {
        guard await MicrophonePermission.request() else {
            microphoneDenied = true
            return
        }
        let tracker = ChordTracker()
        do {
            let stream = try tracker.start()
            self.tracker = tracker
            isListening = true
            for await estimate in stream {
                ingest(estimate)
            }
        } catch {
            isListening = false
        }
        tracker.stop()
        if self.tracker === tracker { self.tracker = nil }
        isListening = false
    }

    private func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        tracker?.stop()
        tracker = nil
        isListening = false
    }

    private func ingest(_ estimate: ChordEstimate) {
        guard state == .playing, let heard = estimate.chord else { return }
        guard let expected = ChordLibrary.voicing(id: currentChordID)?.chord, heard.isSameFamily(as: expected) else { return }
        barResults[currentBarIndex] = true
    }
}
