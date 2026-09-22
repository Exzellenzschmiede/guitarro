import AudioEngine
import Foundation
import MusicTheory
import Observation
import Training

/// Runs one "one-minute changes" exercise: count how often the player switches between two chords.
@MainActor
@Observable
final class ChordChangeSession {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case finished
    }

    enum InputMode: String, CaseIterable, Identifiable {
        case microphone, manual
        var id: String { rawValue }
    }

    enum MicrophoneStatus: Equatable {
        case unknown, listening, permissionDenied, failed(String)
    }

    static let duration: Double = 60

    let pair: ChordPair
    let from: ChordVoicing
    let to: ChordVoicing

    private(set) var phase: Phase = .ready
    var inputMode: InputMode = .microphone
    private(set) var changes = 0
    private(set) var remaining = ChordChangeSession.duration
    private(set) var expected: ChordVoicing
    private(set) var heardChord: Chord?
    private(set) var heardConfidence: Float = 0
    private(set) var microphoneStatus: MicrophoneStatus = .unknown

    private var tracker: ChordTracker?
    private var listeningTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var stableFrames = 0
    private var hasHeardFirstChord = false

    init?(pair: ChordPair) {
        guard let from = pair.fromVoicing, let to = pair.toVoicing else { return nil }
        self.pair = pair
        self.from = from
        self.to = to
        expected = from
    }

    var changesPerMinute: Int { changes }
    var progress: Double { 1 - remaining / Self.duration }

    // MARK: Control

    func start() {
        guard phase == .ready || phase == .finished else { return }
        changes = 0
        remaining = Self.duration
        expected = from
        hasHeardFirstChord = false
        stableFrames = 0
        heardChord = nil
        heardConfidence = 0

        if inputMode == .microphone {
            listeningTask = Task { await listen() }
        }
        timerTask = Task {
            for second in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(second)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            await run()
        }
    }

    func cancel() {
        timerTask?.cancel()
        timerTask = nil
        stopListening()
        phase = .ready
        remaining = Self.duration
    }

    /// Manual counting: the player taps after every change.
    func registerChange() {
        guard phase == .running else { return }
        changes += 1
        expected = expected.id == from.id ? to : from
    }

    func stopAll() {
        timerTask?.cancel()
        timerTask = nil
        stopListening()
    }

    // MARK: Timer

    private func run() async {
        phase = .running
        let clock = ContinuousClock()
        let start = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let elapsed = clock.now - start
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            remaining = max(0, Self.duration - seconds)
            if remaining <= 0 { break }
        }
        guard !Task.isCancelled else { return }
        stopListening()
        phase = .finished
    }

    // MARK: Listening

    private func listen() async {
        guard await MicrophonePermission.request() else {
            microphoneStatus = .permissionDenied
            inputMode = .manual
            return
        }
        let tracker = ChordTracker()
        do {
            let stream = try tracker.start()
            self.tracker = tracker
            microphoneStatus = .listening
            for await estimate in stream {
                ingest(estimate)
            }
        } catch {
            microphoneStatus = .failed(error.localizedDescription)
            inputMode = .manual
        }
        tracker.stop()
        if self.tracker === tracker { self.tracker = nil }
    }

    private func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        tracker?.stop()
        tracker = nil
        if microphoneStatus == .listening { microphoneStatus = .unknown }
    }

    private func ingest(_ estimate: ChordEstimate) {
        heardChord = estimate.chord
        heardConfidence = estimate.confidence
        guard phase == .running else { return }

        // A silent or undecided window keeps the count; a different chord resets it. The
        // seventh variant of the expected chord counts, that is what beginners strum anyway.
        guard let chord = estimate.chord else { return }
        guard chord.isSameFamily(as: expected.chord) else {
            stableFrames = 0
            return
        }
        stableFrames += 1
        // Two windows (~170 ms) of the expected chord count as a change.
        guard stableFrames >= 2 else { return }
        stableFrames = 0
        if hasHeardFirstChord {
            changes += 1
        }
        hasHeardFirstChord = true
        expected = expected.id == from.id ? to : from
    }
}
