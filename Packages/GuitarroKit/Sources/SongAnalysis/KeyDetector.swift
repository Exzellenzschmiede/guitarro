import Foundation
import MusicTheory

/// Krumhansl-Kessler key finding on a summed chroma vector.
public enum KeyDetector {
    static let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    public static func detect(chroma: [Float]) -> MusicalKey? {
        guard chroma.count == 12, chroma.contains(where: { $0 > 0 }) else { return nil }
        var best: (key: MusicalKey, score: Float)?
        for tonic in PitchClass.allCases {
            for (mode, profile) in [(MusicalKey.Mode.major, majorProfile), (.minor, minorProfile)] {
                let rotated = (0..<12).map { profile[(($0 - tonic.rawValue) % 12 + 12) % 12] }
                let score = correlation(chroma, rotated)
                if best == nil || score > best!.score {
                    best = (MusicalKey(tonic: tonic, mode: mode), score)
                }
            }
        }
        return best?.key
    }

    static func correlation(_ a: [Float], _ b: [Float]) -> Float {
        let meanA = a.reduce(0, +) / Float(a.count)
        let meanB = b.reduce(0, +) / Float(b.count)
        var num: Float = 0, denA: Float = 0, denB: Float = 0
        for i in 0..<a.count {
            let da = a[i] - meanA, db = b[i] - meanB
            num += da * db
            denA += da * da
            denB += db * db
        }
        let den = sqrt(denA * denB)
        return den > 0 ? num / den : 0
    }
}
