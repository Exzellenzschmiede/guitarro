import Foundation
import MusicTheory
import Testing
@testable import AudioEngine

/// Chord recognition under guitar-like conditions: detuned strings, uneven strum, a phone
/// microphone's high-pass, room noise and low level. Prints per-chord rates; the assertions
/// are the floor we do not want to fall below. Run: swift test --filter RealisticChordBench
@Suite struct RealisticChordBench {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func uniform(_ range: ClosedRange<Double>) -> Double {
            Double(next() >> 11) / Double(1 << 53) * (range.upperBound - range.lowerBound) + range.lowerBound
        }
    }

    /// Second-order biquad, direct form 1.
    struct Biquad {
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        static func highPass(frequency: Double, sampleRate: Double, q: Double = 0.707) -> Biquad {
            let w = 2 * Double.pi * frequency / sampleRate
            let alpha = sin(w) / (2 * q)
            let c = cos(w)
            let a0 = 1 + alpha
            var f = Biquad()
            f.b0 = (1 + c) / 2 / a0; f.b1 = -(1 + c) / a0; f.b2 = (1 + c) / 2 / a0
            f.a1 = -2 * c / a0; f.a2 = (1 - alpha) / a0
            return f
        }

        static func peak(frequency: Double, sampleRate: Double, q: Double, gainDB: Double) -> Biquad {
            let a = pow(10, gainDB / 40)
            let w = 2 * Double.pi * frequency / sampleRate
            let alpha = sin(w) / (2 * q)
            let c = cos(w)
            let a0 = 1 + alpha / a
            var f = Biquad()
            f.b0 = (1 + alpha * a) / a0; f.b1 = -2 * c / a0; f.b2 = (1 - alpha * a) / a0
            f.a1 = -2 * c / a0; f.a2 = (1 - alpha / a) / a0
            return f
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
    }

    enum Variant: String, CaseIterable { case clean, sloppy }

    static let sampleRate = 48_000.0

    /// Renders one strum of `voicing` the way a phone would hear it.
    static func render(_ voicing: ChordVoicing, variant: Variant, seed: UInt64, seconds: Double = 1.6, level: Float = 0.02) -> [Float] {
        var generator = Seeded(state: seed)
        var strings = voicing.strings.enumerated().compactMap { index, action -> (index: Int, pitch: Pitch)? in
            guard let fret = action.fret else { return nil }
            return (index, Tuning.standard.strings[index].transposed(by: fret))
        }
        if variant == .sloppy, strings.count > 3 {
            // A muffled string that barely sounds and a neighbour ringing half a step off.
            strings.remove(at: Int(generator.next() % UInt64(strings.count)))
        }
        var voices: [PluckedStringVoice] = strings.map { string in
            let detune = pow(2, generator.uniform(-18...18) / 1200)
            let velocity = Float(generator.uniform(0.35...0.9))
            let delay = Int(Double(string.index) * generator.uniform(700...1900))
            let sustain = string.pitch.midiNumber < 52 ? 3.2 : 1.6
            return PluckedStringVoice(frequency: string.pitch.frequency() * detune, sampleRate: sampleRate, velocity: velocity, startDelay: delay, sustain: sustain, using: &generator)
        }
        if variant == .sloppy {
            // Fret buzz / an accidentally touched open string, quiet and short.
            let stray = Tuning.standard.strings[Int(generator.next() % 6)]
            voices.append(PluckedStringVoice(frequency: stray.frequency(), sampleRate: sampleRate, velocity: 0.25, startDelay: 400, sustain: 0.5, using: &generator))
        }
        var audio = [Float](repeating: 0, count: Int(seconds * sampleRate))
        audio.withUnsafeMutableBufferPointer { buffer in
            for i in voices.indices { voices[i].render(adding: buffer.baseAddress!, frames: buffer.count) }
        }
        // Acoustic body bump, phone microphone high-pass, room noise, low level.
        var body = Biquad.peak(frequency: 105, sampleRate: sampleRate, q: 1.5, gainDB: 5)
        var highPass = Biquad.highPass(frequency: 110, sampleRate: sampleRate)
        var lowPass = Biquad.peak(frequency: 3000, sampleRate: sampleRate, q: 0.7, gainDB: -4)
        var peak: Float = 0
        for i in audio.indices {
            let y = lowPass.process(highPass.process(body.process(Double(audio[i]))))
            audio[i] = Float(y)
            peak = max(peak, abs(audio[i]))
        }
        let scale = peak > 0 ? level / peak : 1
        let noise = level * 0.02
        for i in audio.indices {
            audio[i] = audio[i] * scale + Float(generator.uniform(-1...1)) * noise
        }
        return audio
    }

    struct Rates { var frames = 0, correct = 0, family = 0, wrong = 0, none = 0, gateClosed = 0, lowSpread = 0, lowConfidence = 0; var confusions: [String: Int] = [:] }

    static func evaluate(analyzer: ChromaAnalyzer, matcher: ChordMatcher, windowSize: Int, hopSize: Int, variant: Variant, seeds: [UInt64]) -> (total: Rates, perChord: [String: Rates]) {
        var total = Rates()
        var perChord: [String: Rates] = [:]
        for voicing in ChordLibrary.openChords {
            var rates = Rates()
            for seed in seeds {
                let audio = render(voicing, variant: variant, seed: seed &+ UInt64(voicing.id.unicodeScalars.reduce(0) { $0 * 31 + Int($1.value) } & 0xffff))
                var gate = NoiseGate()
                // Evaluate the window ending between 0.35 s and 1.2 s after the strum starts.
                var end = Int(0.35 * sampleRate)
                while end <= Int(1.2 * sampleRate), end <= audio.count {
                    let start = max(0, end - windowSize)
                    var window = Array(audio[start..<end])
                    if window.count < windowSize { window = [Float](repeating: 0, count: windowSize - window.count) + window }
                    rates.frames += 1
                    let open = gate.process(rms: InputMeter.rms(window))
                    if open, let frame = analyzer.analyze(window) {
                        let estimate = matcher.match(frame)
                        if let chord = estimate.chord {
                            if chord == voicing.chord || (voicing.chord.quality == .suspendedSecond || voicing.chord.quality == .suspendedFourth) && chord.root == voicing.chord.root && chord.quality == .major {
                                rates.correct += 1
                            } else if chord.isSameFamily(as: voicing.chord) {
                                rates.family += 1
                            } else {
                                rates.wrong += 1
                                rates.confusions[chord.symbol(), default: 0] += 1
                            }
                        } else {
                            rates.none += 1
                            if matcher.fundamentalPitchClasses(in: frame).count < matcher.minimumSpread { rates.lowSpread += 1 } else { rates.lowConfidence += 1 }
                        }
                    } else {
                        rates.none += 1
                        rates.gateClosed += 1
                    }
                    end += hopSize
                }
            }
            perChord[voicing.id] = rates
            total.frames += rates.frames; total.correct += rates.correct; total.family += rates.family; total.wrong += rates.wrong; total.none += rates.none
            total.gateClosed += rates.gateClosed; total.lowSpread += rates.lowSpread; total.lowConfidence += rates.lowConfidence
            for (k, v) in rates.confusions { total.confusions[k, default: 0] += v }
        }
        return (total, perChord)
    }

    static func report(_ label: String, _ result: (total: Rates, perChord: [String: Rates])) {
        let t = result.total
        print("BENCH \(label): frames=\(t.frames) correct=\(t.correct) (\(t.correct * 100 / max(1, t.frames))%) family=\(t.family) (\((t.correct + t.family) * 100 / max(1, t.frames))%) wrong=\(t.wrong) none=\(t.none) [gate \(t.gateClosed) spread \(t.lowSpread) conf \(t.lowConfidence)]")
        let worst = result.perChord.sorted { $0.value.correct < $1.value.correct }.prefix(6)
        for (id, r) in worst {
            let top = r.confusions.sorted { $0.value > $1.value }.prefix(2).map { "\($0.key)×\($0.value)" }.joined(separator: " ")
            print("   \(id): correct \(r.correct)/\(r.frames) family \(r.family) wrong \(r.wrong) none \(r.none) \(top)")
        }
    }

    struct Setup { let label: String; let analyzer: ChromaAnalyzer; let matcher: ChordMatcher }

    static func setups(windowSize: Int) -> [Setup] {
        let rate = sampleRate
        func matcher(bias: Float, confidence: Float = 0.8, spread: Float = 0.2) -> ChordMatcher {
            var m = ChordMatcher(minimumConfidence: confidence, spreadRatio: spread)
            m.triadBias = bias
            return m
        }
        return [
            Setup(label: "bias0.04", analyzer: ChromaAnalyzer(sampleRate: rate, windowSize: windowSize), matcher: matcher(bias: 0.04)),
            Setup(label: "bias0.02", analyzer: ChromaAnalyzer(sampleRate: rate, windowSize: windowSize), matcher: matcher(bias: 0.02)),
            Setup(label: "bias0", analyzer: ChromaAnalyzer(sampleRate: rate, windowSize: windowSize), matcher: matcher(bias: 0)),
        ]
    }

    @Test func realisticStrums() {
        let windowSize = ChordTracker.Configuration().windowSize
        let hopSize = ChordTracker.Configuration().hopSize
        let seeds: [UInt64] = [1, 2, 3]
        var best = 0
        for setup in Self.setups(windowSize: windowSize) {
            let clean = Self.evaluate(analyzer: setup.analyzer, matcher: setup.matcher, windowSize: windowSize, hopSize: hopSize, variant: .clean, seeds: seeds)
            Self.report("\(setup.label) clean", clean)
            let sloppy = Self.evaluate(analyzer: setup.analyzer, matcher: setup.matcher, windowSize: windowSize, hopSize: hopSize, variant: .sloppy, seeds: seeds)
            Self.report("\(setup.label) sloppy", sloppy)
            best = max(best, clean.total.correct * 100 / clean.total.frames)
        }
        #expect(best >= 50)
    }
}
