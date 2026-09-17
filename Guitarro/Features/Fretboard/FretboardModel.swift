import AudioEngine
import Foundation
import Fretboard
import MusicTheory
import Observation

@MainActor
@Observable
final class FretboardModel {
    enum LabelMode: String, CaseIterable, Identifiable {
        case notes, intervals, fingers
        var id: String { rawValue }
    }

    enum ListeningStatus: Equatable {
        case off
        case listening
        case permissionDenied
        case failed(String)
    }

    var tuning: Tuning = .standard {
        didSet {
            livePositions = []
            lastTapped = nil
        }
    }
    var labelMode: LabelMode = .notes
    var showAllNotes = true
    /// Root for interval labels. Follows the selected chord.
    var root: PitchClass = .e
    var fretCount = 12

    private(set) var selectedVoicing: ChordVoicing?
    private(set) var livePositions: Set<FretboardPosition> = []
    private(set) var lastTapped: FretboardPosition?
    private(set) var listeningStatus: ListeningStatus = .off

    let voicings = ChordLibrary.openChords

    private let player = TonePlayer()
    private var tracker: PitchTracker?
    private var listeningTask: Task<Void, Never>?
    private var lastHeardAt: ContinuousClock.Instant?
    private var lastHeardPitch: Pitch?
    private let liveHold: Duration = .milliseconds(700)

    // MARK: Chords

    var mutedStrings: Set<Int> { selectedVoicing?.mutedStrings ?? [] }

    var barre: FretboardBarre? {
        selectedVoicing?.barre.map { FretboardBarre(fret: $0.fret, fromString: $0.fromString, toString: $0.toString) }
    }

    /// Selects a chord (or deselects it when tapped again) and strums it.
    func select(_ voicing: ChordVoicing) {
        if selectedVoicing?.id == voicing.id {
            clearSelection()
            return
        }
        selectedVoicing = voicing
        root = voicing.chord.root
        showAllNotes = false
        lastTapped = nil
        playSelectedChord()
    }

    func clearSelection() {
        selectedVoicing = nil
        showAllNotes = true
        if labelMode == .fingers { labelMode = .notes }
    }

    func playSelectedChord() {
        guard let voicing = selectedVoicing else { return }
        player.strum(frequencies: voicing.pitches(in: tuning).map { $0.frequency() })
    }

    func tap(_ position: FretboardPosition) {
        lastTapped = position
        player.pluck(frequency: tuning.pitch(at: position).frequency())
    }

    // MARK: Markers

    func markers(noteNaming: NoteNamingStyle) -> [FretboardMarker] {
        var result: [FretboardPosition: FretboardMarker] = [:]

        if showAllNotes {
            for string in 0..<tuning.stringCount {
                for fret in 0...fretCount {
                    let position = FretboardPosition(string: string, fret: fret)
                    result[position] = FretboardMarker(position: position, label: label(for: position, finger: nil, noteNaming: noteNaming), style: .faint)
                }
            }
        }

        if let voicing = selectedVoicing {
            for (string, action) in voicing.strings.enumerated() {
                guard let fret = action.fret else { continue }
                let position = FretboardPosition(string: string, fret: fret)
                let isRoot = tuning.pitch(at: position).pitchClass == voicing.chord.root
                result[position] = FretboardMarker(
                    position: position,
                    label: label(for: position, finger: action.finger, noteNaming: noteNaming),
                    style: isRoot ? .root : .chordTone
                )
            }
        }

        if let tapped = lastTapped, result[tapped] == nil || result[tapped]?.style == .faint {
            result[tapped] = FretboardMarker(position: tapped, label: label(for: tapped, finger: nil, noteNaming: noteNaming), style: .tone)
        }

        for position in livePositions {
            result[position] = FretboardMarker(position: position, label: label(for: position, finger: nil, noteNaming: noteNaming), style: .live)
        }

        return result.values.sorted { $0.position < $1.position }
    }

    private func label(for position: FretboardPosition, finger: Int?, noteNaming: NoteNamingStyle) -> String {
        let pitchClass = tuning.pitch(at: position).pitchClass
        switch labelMode {
        case .notes:
            return pitchClass.name(style: noteNaming)
        case .intervals:
            return Interval.between(root, pitchClass).shortLabel
        case .fingers:
            if let finger, finger > 0 { return "\(finger)" }
            return position.fret == 0 ? "0" : pitchClass.name(style: noteNaming)
        }
    }

    // MARK: Listening

    var isListening: Bool { listeningStatus == .listening }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            listeningTask = Task { await startListening() }
        }
    }

    private func startListening() async {
        guard !isListening else { return }
        guard await MicrophonePermission.request() else {
            listeningStatus = .permissionDenied
            return
        }
        let tracker = PitchTracker()
        do {
            let stream = try tracker.start()
            self.tracker = tracker
            listeningStatus = .listening
            for await estimate in stream {
                ingest(estimate)
            }
        } catch {
            listeningStatus = .failed(error.localizedDescription)
        }
        tracker.stop()
        if self.tracker === tracker { self.tracker = nil }
        if listeningStatus == .listening { listeningStatus = .off }
        livePositions = []
    }

    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        tracker?.stop()
        tracker = nil
        if listeningStatus == .listening { listeningStatus = .off }
        livePositions = []
        lastHeardPitch = nil
    }

    func stopAll() {
        stopListening()
        player.stop()
    }

    private func ingest(_ estimate: PitchEstimate?) {
        let now = ContinuousClock.now
        guard let estimate, estimate.clarity >= 0.85 else {
            if let lastHeardAt, now - lastHeardAt > liveHold {
                livePositions = []
                lastHeardPitch = nil
            }
            return
        }
        lastHeardAt = now
        let pitch = Pitch.nearest(toFrequency: estimate.frequency).pitch
        guard pitch != lastHeardPitch else { return }
        lastHeardPitch = pitch
        livePositions = Set(tuning.positions(of: pitch, maxFret: fretCount))
    }
}
