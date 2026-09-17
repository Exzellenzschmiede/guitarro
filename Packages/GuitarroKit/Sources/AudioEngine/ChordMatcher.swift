import Foundation
import MusicTheory

/// The chord heard in one window, if any.
public struct ChordEstimate: Sendable, Equatable {
    /// `nil` when the window is silent, too sparse to be a chord, or matches nothing well.
    public let chord: Chord?
    /// Cosine similarity of the chroma with the best template, 0…1.
    public let confidence: Float
    /// How much better the best chord matched than the runner-up, 0…1.
    public let margin: Float
    public let chroma: [Float]
    public let rms: Float

    public static let silence = ChordEstimate(chord: nil, confidence: 0, margin: 0, chroma: [Float](repeating: 0, count: 12), rms: 0)
}

/// Matches a chroma vector against chord templates.
public struct ChordMatcher: Sendable {
    public let candidates: [Chord]
    /// Minimum similarity for a chord to count as recognised.
    public var minimumConfidence: Float
    /// Windows quieter than this (RMS, linear) are treated as silence.
    public var minimumRMS: Float
    /// A chord needs at least this many pitch classes above `spreadRatio` × peak.
    public var minimumSpread: Int
    public var spreadRatio: Float

    /// Added to the score of three-note chords so a triad wins over its seventh
    /// version unless the seventh is clearly there.
    public var triadBias: Float = 0.04

    private let templates: [[Float]]

    /// Major, minor and seventh chords on every root. Suspended chords are left out on purpose:
    /// the third harmonic of a chord's fifth lands on the ninth, which makes a plain major
    /// chord look like a sus2 to a template matcher.
    public static let defaultCandidates: [Chord] = PitchClass.allCases.flatMap { root in
        [Chord(root, .major), Chord(root, .minor), Chord(root, .dominantSeventh), Chord(root, .minorSeventh)]
    }

    public init(
        candidates: [Chord] = defaultCandidates,
        minimumConfidence: Float = 0.8,
        minimumRMS: Float = 0.008,
        minimumSpread: Int = 3,
        spreadRatio: Float = 0.2
    ) {
        self.candidates = candidates
        self.minimumConfidence = minimumConfidence
        self.minimumRMS = minimumRMS
        self.minimumSpread = minimumSpread
        self.spreadRatio = spreadRatio
        templates = candidates.map(Self.template(for:))
    }

    public func match(_ frame: ChromaFrame) -> ChordEstimate {
        let chroma = frame.chroma
        guard frame.rms >= minimumRMS, let peak = chroma.max(), peak > 0 else {
            return ChordEstimate(chord: nil, confidence: 0, margin: 0, chroma: chroma, rms: frame.rms)
        }
        let spread = chroma.filter { $0 >= spreadRatio * peak }.count

        var bestIndex = -1
        var bestScore: Float = 0
        var secondScore: Float = 0
        let chromaNorm = sqrt(chroma.reduce(0) { $0 + $1 * $1 })
        for (index, template) in templates.enumerated() {
            var dot: Float = 0
            for i in 0..<12 { dot += chroma[i] * template[i] }
            var score = chromaNorm > 0 ? dot / chromaNorm : 0
            if candidates[index].intervals.count == 3 { score += triadBias }
            if score > bestScore {
                secondScore = bestScore
                bestScore = score
                bestIndex = index
            } else if score > secondScore {
                secondScore = score
            }
        }

        let recognised = bestIndex >= 0 && bestScore >= minimumConfidence && spread >= minimumSpread
        return ChordEstimate(
            chord: recognised ? candidates[bestIndex] : nil,
            confidence: bestScore,
            margin: max(0, bestScore - secondScore),
            chroma: chroma,
            rms: frame.rms
        )
    }

    /// Unit-length template: chord tones weighted 1 (root slightly higher), everything else 0.
    static func template(for chord: Chord) -> [Float] {
        var template = [Float](repeating: 0, count: 12)
        for (index, pitchClass) in chord.pitchClasses.enumerated() {
            template[pitchClass.rawValue] = index == 0 ? 1.1 : 1.0
        }
        let norm = sqrt(template.reduce(0) { $0 + $1 * $1 })
        return template.map { $0 / norm }
    }
}
