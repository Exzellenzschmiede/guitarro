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
    /// Similarity per candidate of the matcher that produced this estimate; empty for silence.
    public let scores: [Float]

    public init(chord: Chord?, confidence: Float, margin: Float, chroma: [Float], rms: Float, scores: [Float] = []) {
        self.chord = chord
        self.confidence = confidence
        self.margin = margin
        self.chroma = chroma
        self.rms = rms
        self.scores = scores
    }

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
    public var triadBias: Float = 0.02

    private let templates: [[Float]]

    /// Major, minor and seventh chords on every root. Suspended chords are left out on purpose:
    /// the third harmonic of a chord's fifth lands on the ninth, which makes a plain major
    /// chord look like a sus2 to a template matcher.
    public static let defaultCandidates: [Chord] = PitchClass.allCases.flatMap { root in
        [Chord(root, .major), Chord(root, .minor), Chord(root, .dominantSeventh), Chord(root, .minorSeventh)]
    }

    /// Model each chord tone's harmonics in the template (octave, fifth, major third …)
    /// so a strummed chord matches without subtracting harmonics from the chroma first.
    public let harmonicTemplates: Bool

    public init(
        candidates: [Chord] = defaultCandidates,
        minimumConfidence: Float = 0.8,
        minimumRMS: Float = 0.0006,
        minimumSpread: Int = 3,
        spreadRatio: Float = 0.2,
        harmonicTemplates: Bool = true
    ) {
        self.candidates = candidates
        self.minimumConfidence = minimumConfidence
        self.minimumRMS = minimumRMS
        self.minimumSpread = minimumSpread
        self.spreadRatio = spreadRatio
        self.harmonicTemplates = harmonicTemplates
        templates = candidates.map { Self.template(for: $0, harmonics: harmonicTemplates) }
    }

    /// Similarity of a chroma vector with every candidate (same order as `candidates`), triad bias included.
    public func scores(for chroma: [Float]) -> [Float] {
        let chromaNorm = sqrt(chroma.reduce(0) { $0 + $1 * $1 })
        guard chromaNorm > 0 else { return [Float](repeating: 0, count: candidates.count) }
        return templates.enumerated().map { index, template in
            var dot: Float = 0
            for i in 0..<12 { dot += chroma[i] * template[i] }
            return dot / chromaNorm + (candidates[index].intervals.count == 3 ? triadBias : 0)
        }
    }

    public func match(_ frame: ChromaFrame) -> ChordEstimate {
        let chroma = frame.chroma
        guard frame.rms >= minimumRMS, let peak = chroma.max(), peak > 0 else {
            return ChordEstimate(chord: nil, confidence: 0, margin: 0, chroma: chroma, rms: frame.rms)
        }
        let spread = fundamentalPitchClasses(in: frame).count

        var bestIndex = -1
        var bestScore: Float = 0
        var secondScore: Float = 0
        let allScores = scores(for: chroma)
        for (index, score) in allScores.enumerated() {
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
            rms: frame.rms,
            scores: allScores
        )
    }

    /// Pitch classes of the notes that sound as fundamentals: notes at least `spreadRatio`
    /// of the loudest note that are not a partial (octave, fifth, double octave, major
    /// third, …) of a louder note below them. A single plucked string has one, a strummed
    /// chord three or more, however rich the harmonics.
    public func fundamentalPitchClasses(in frame: ChromaFrame) -> Set<Int> {
        let magnitudes = frame.noteMagnitudes
        guard let peak = magnitudes.max(), peak > 0 else { return [] }
        let threshold = 0.1 * peak
        // Semitone offsets of the 2nd to 16th partial (12·log2(n), rounded).
        let partialOffsets = [12, 19, 24, 28, 31, 34, 36, 38, 40, 42, 43, 44, 46, 47, 48]
        var fundamentals: [Int] = []
        var classes: Set<Int> = []
        for (index, magnitude) in magnitudes.enumerated() where magnitude >= threshold {
            // Partials often outweigh their fundamental through a phone microphone, so the
            // level does not matter: any note sitting on a partial of a counted fundamental
            // is treated as that fundamental's harmonic.
            let explained = fundamentals.contains { lower in partialOffsets.contains(index - lower) }
            if !explained {
                fundamentals.append(index)
                classes.insert((frame.lowestMidi + index) % 12)
            }
        }
        return classes
    }

    /// Unit-length template. Plain: chord tones weighted 1 (root slightly higher). With
    /// harmonics: every chord tone also spreads onto the pitch classes of its first six
    /// partials with geometrically decaying weights, the way a plucked string does.
    static func template(for chord: Chord, harmonics: Bool) -> [Float] {
        var template = [Float](repeating: 0, count: 12)
        let partialOffsets = [0, 12, 19, 24, 28, 31]
        for (index, pitchClass) in chord.pitchClasses.enumerated() {
            let base: Float = index == 0 ? 1.1 : 1.0
            if harmonics {
                for (partial, offset) in partialOffsets.enumerated() {
                    template[(pitchClass.rawValue + offset) % 12] += base * pow(0.55, Float(partial))
                }
            } else {
                template[pitchClass.rawValue] = base
            }
        }
        let norm = sqrt(template.reduce(0) { $0 + $1 * $1 })
        return template.map { $0 / norm }
    }
}
