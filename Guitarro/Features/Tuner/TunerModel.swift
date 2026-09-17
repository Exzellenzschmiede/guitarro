import AudioEngine
import Foundation
import MusicTheory
import Observation

struct TunerReading: Equatable {
    var frequency: Double
    /// Nearest chromatic pitch.
    var pitch: Pitch
    /// Deviation from `pitch` in cents.
    var cents: Double
    /// Nearest open string of the selected tuning.
    var stringMatch: Tuning.StringMatch
    var clarity: Float
}

enum TunerMode: String, CaseIterable, Identifiable {
    /// Compare against the nearest open string of the selected tuning.
    case auto
    /// Compare against the nearest chromatic pitch.
    case chromatic

    var id: String { rawValue }
}

@MainActor
@Observable
final class TunerModel {
    enum Status: Equatable {
        case idle
        case listening
        case permissionDenied
        case failed(String)
    }

    static let inTuneTolerance = 5.0

    private(set) var status: Status = .idle
    private(set) var reading: TunerReading?
    var mode: TunerMode = .auto
    var tuning: Tuning = .standard {
        didSet { history.removeAll() }
    }
    var referenceA4: Double = Pitch.standardA4Frequency {
        didSet { history.removeAll() }
    }

    private var tracker: PitchTracker?
    private var history: [Double] = []
    private var lastVoicedAt: ContinuousClock.Instant?
    private let minimumClarity: Float = 0.75
    private let holdDuration: Duration = .milliseconds(800)
    private let historyLength = 5

    // MARK: Derived state for the UI

    var displayedPitch: Pitch? {
        guard let reading else { return nil }
        return usesStringMode(reading) ? reading.stringMatch.pitch : reading.pitch
    }

    var displayedCents: Double? {
        guard let reading else { return nil }
        return usesStringMode(reading) ? reading.stringMatch.cents : reading.cents
    }

    var activeStringIndex: Int? {
        guard let reading, usesStringMode(reading) else { return nil }
        return reading.stringMatch.index
    }

    var isInTune: Bool {
        guard let cents = displayedCents else { return false }
        return abs(cents) <= Self.inTuneTolerance
    }

    private func usesStringMode(_ reading: TunerReading) -> Bool {
        // Fall back to chromatic display when the note is more than a semitone from every open string.
        mode == .auto && abs(reading.stringMatch.cents) <= 100
    }

    // MARK: Lifecycle

    /// Requests microphone access, starts listening, and returns when listening stops.
    func start() async {
        guard status != .listening else { return }
        guard await MicrophonePermission.request() else {
            status = .permissionDenied
            return
        }

        let tracker = PitchTracker()
        do {
            let stream = try tracker.start()
            self.tracker = tracker
            status = .listening
            for await estimate in stream {
                ingest(estimate)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
        stop()
    }

    func stop() {
        tracker?.stop()
        tracker = nil
        if status == .listening {
            status = .idle
        }
        reading = nil
        history.removeAll()
    }

    // MARK: Analysis

    private func ingest(_ estimate: PitchEstimate?) {
        let now = ContinuousClock.now
        guard let estimate, estimate.clarity >= minimumClarity else {
            if let lastVoicedAt, now - lastVoicedAt > holdDuration {
                reading = nil
                history.removeAll()
            }
            return
        }
        lastVoicedAt = now

        // A jump of more than ~3 % is a new note, not jitter: restart smoothing.
        if let current = median(history), abs(estimate.frequency / current - 1) > 0.03 {
            history.removeAll()
        }
        history.append(estimate.frequency)
        if history.count > historyLength {
            history.removeFirst()
        }

        let frequency = median(history) ?? estimate.frequency
        let nearest = Pitch.nearest(toFrequency: frequency, a4: referenceA4)
        let match = tuning.nearestString(toFrequency: frequency, a4: referenceA4)
        reading = TunerReading(
            frequency: frequency,
            pitch: nearest.pitch,
            cents: nearest.cents,
            stringMatch: match,
            clarity: estimate.clarity
        )
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
