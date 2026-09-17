import Foundation
import MusicTheory

/// Turns per-frame chord scores into a smooth chord sequence (Viterbi with a switch penalty).
public enum ChordSequenceDecoder {
    /// - Parameters:
    ///   - frameScores: for every frame, one score per candidate (higher is better, ~0…1).
    ///   - silence: for every frame, true when the frame is too quiet to carry a chord.
    ///   - switchPenalty: cost of changing chord between neighbouring frames.
    /// - Returns: for every frame the chosen candidate index, or nil for "no chord".
    public static func decode(frameScores: [[Float]], silence: [Bool], switchPenalty: Float = 0.12) -> [Int?] {
        let frames = frameScores.count
        guard frames > 0, let candidateCount = frameScores.first?.count, candidateCount > 0 else { return [] }
        let states = candidateCount + 1 // last state = no chord
        let noChord = candidateCount

        func emission(_ frame: Int, _ state: Int) -> Float {
            if state == noChord { return silence[frame] ? 0.9 : 0.35 }
            return silence[frame] ? 0 : frameScores[frame][state]
        }

        var cost = [Float](repeating: 0, count: states)
        var back = [[Int]](repeating: [Int](repeating: 0, count: states), count: frames)
        for state in 0..<states { cost[state] = emission(0, state) }

        for frame in 1..<frames {
            var next = [Float](repeating: -Float.greatestFiniteMagnitude, count: states)
            var bestPrev = -Float.greatestFiniteMagnitude
            var bestPrevIndex = 0
            for (index, value) in cost.enumerated() where value > bestPrev {
                bestPrev = value
                bestPrevIndex = index
            }
            for state in 0..<states {
                let stay = cost[state]
                let switchIn = bestPrev - switchPenalty
                if stay >= switchIn {
                    next[state] = stay + emission(frame, state)
                    back[frame][state] = state
                } else {
                    next[state] = switchIn + emission(frame, state)
                    back[frame][state] = bestPrevIndex
                }
            }
            cost = next
        }

        var path = [Int](repeating: 0, count: frames)
        path[frames - 1] = cost.enumerated().max { $0.element < $1.element }!.offset
        if frames > 1 {
            for frame in stride(from: frames - 1, to: 0, by: -1) {
                path[frame - 1] = back[frame][path[frame]]
            }
        }
        return path.map { $0 == noChord ? nil : $0 }
    }

    /// Collapses a per-frame path into segments and absorbs segments shorter than `minimumDuration`.
    public static func segments(from path: [Int?], candidates: [Chord], hopSeconds: Double, minimumDuration: Double) -> [ChordSegment] {
        var segments: [ChordSegment] = []
        for (index, state) in path.enumerated() {
            let chord = state.map { candidates[$0] }
            if let last = segments.last, last.chord == chord {
                segments[segments.count - 1].duration += hopSeconds
            } else {
                segments.append(ChordSegment(start: Double(index) * hopSeconds, duration: hopSeconds, chord: chord))
            }
        }
        // Merge short blips into the previous segment (or the next one at the start).
        var merged: [ChordSegment] = []
        for segment in segments {
            if segment.duration < minimumDuration, !merged.isEmpty {
                merged[merged.count - 1].duration += segment.duration
            } else if segment.duration < minimumDuration, merged.isEmpty {
                merged.append(segment)
            } else if let last = merged.last, last.chord == segment.chord {
                merged[merged.count - 1].duration += segment.duration
            } else {
                merged.append(segment)
            }
        }
        // A leading blip may now equal its successor's chord: fold once more.
        var folded: [ChordSegment] = []
        for segment in merged {
            if let last = folded.last, last.chord == segment.chord {
                folded[folded.count - 1].duration += segment.duration
            } else {
                folded.append(segment)
            }
        }
        return folded
    }
}
