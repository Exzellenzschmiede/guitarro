import AudioEngine
import Foundation
import MusicTheory
import Observation
import os

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
    /// Level of the last analysed window, for the input meter.
    private(set) var inputLevel = PitchTracker.InputLevel()
    /// True after several seconds of listening without the gate ever opening.
    private(set) var isInputTooQuiet = false
    private var listeningSince: ContinuousClock.Instant?
    private var previousRMS: Float = 0
    private var lastOpenAt: ContinuousClock.Instant?
    var mode: TunerMode = .auto
    var tuning: Tuning = .standard {
        didSet { history.removeAll() }
    }
    var referenceA4: Double = Pitch.standardA4Frequency {
        didSet { history.removeAll() }
    }

    private var tracker: PitchTracker?
    private var history: [Double] = []
    /// A frequency that disagreed with the history and how many frames have agreed with it.
    private var pending: (frequency: Double, frames: Int)?
    private let framesToConfirm = 3
    private var lastVoicedAt: ContinuousClock.Instant?
    private let minimumClarity: Float = 0.7
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

        // Guitar tuning never needs more than the 12th fret of the high E string; very short
        // periods are where room noise looks periodic.
        var configuration = PitchTracker.Configuration()
        configuration.minimumFrequency = 60
        configuration.maximumFrequency = 1100
        let tracker = PitchTracker(configuration: configuration)
        do {
            let stream = try tracker.start()
            self.tracker = tracker
            status = .listening
            listeningSince = .now
            lastOpenAt = nil
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
        inputLevel = PitchTracker.InputLevel()
        isInputTooQuiet = false
    }

    // MARK: Analysis

    private static let logger = Logger(subsystem: "de.kaniut.guitarro", category: "TunerModel")

    private func ingest(_ estimate: PitchEstimate?) {
        let now = ContinuousClock.now
        if let tracker {
            let level = tracker.inputLevel
            inputLevel = level
            #if DEBUG
            Self.logger.debug("frame rms=\(level.rms, format: .fixed(precision: 5)) gate=\(level.threshold, format: .fixed(precision: 5)) open=\(level.isOpen) f=\(estimate?.frequency ?? 0, format: .fixed(precision: 1)) clarity=\(estimate?.clarity ?? 0, format: .fixed(precision: 2))")
            #endif
            if level.isOpen { lastOpenAt = now }
            let reference = lastOpenAt ?? listeningSince ?? now
            isInputTooQuiet = now - reference > .seconds(4)
            // The attack of a pluck is not periodic yet: a window whose level jumped sharply
            // against the previous one often reads a subharmonic for a few frames. Wait it out.
            let isOnset = previousRMS > 0 && level.rms > previousRMS * 2.5
            previousRMS = level.rms
            if isOnset { return }
        }
        guard let estimate, estimate.clarity >= minimumClarity else {
            if let lastVoicedAt, now - lastVoicedAt > holdDuration {
                reading = nil
                history.removeAll()
                pending = nil
            }
            return
        }
        lastVoicedAt = now

        // A jump of more than ~3 % is a new note, not jitter, but a single frame can also be a
        // noise glitch: only restart smoothing once a second frame agrees with the newcomer.
        if let current = median(history), abs(estimate.frequency / current - 1) > 0.03 {
            if let pending, abs(estimate.frequency / pending.frequency - 1) <= 0.03 {
                let frames = pending.frames + 1
                guard frames >= framesToConfirm else {
                    self.pending = (pending.frequency, frames)
                    return
                }
                history = [pending.frequency]
                self.pending = nil
            } else {
                pending = (estimate.frequency, 1)
                return
            }
        } else {
            pending = nil
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
