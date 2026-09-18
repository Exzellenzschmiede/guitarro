import Accelerate
import Foundation

/// Decides whether a window carries signal by comparing its RMS with a slowly tracked noise
/// floor instead of a fixed level. A phone microphone in measurement mode delivers a guitar a
/// metre away at −50 dBFS and below, so absolute thresholds either swallow the note or let
/// room noise through; the floor adapts to whatever the room and the microphone do.
public struct NoiseGate: Sendable {
    /// Windows below this RMS are always silent (−70 dBFS): the microphone's own hiss.
    public var absoluteFloor: Float
    /// A window needs at least this much more energy than the floor to count as signal.
    public var ratio: Float
    /// How fast the floor may climb per window when the input stays loud (a held note must
    /// not become "noise" within a few seconds).
    public var riseRate: Float

    public private(set) var floor: Float
    private var opened = false

    public init(absoluteFloor: Float = 0.0003, ratio: Float = 3, riseRate: Float = 1.003) {
        self.absoluteFloor = absoluteFloor
        self.ratio = ratio
        self.riseRate = riseRate
        floor = absoluteFloor
    }

    /// The RMS a window needs right now to pass the gate.
    public var threshold: Float {
        max(absoluteFloor, floor * ratio)
    }

    /// Updates the floor with the window's RMS and reports whether the window is signal.
    /// Slight hysteresis keeps a decaying note open a little longer than it took to open.
    public mutating func process(rms: Float) -> Bool {
        if rms < floor {
            // Quieter than the floor: follow down quickly, the room just got calmer.
            floor = max(absoluteFloor, floor * 0.7 + rms * 0.3)
        } else {
            floor = min(rms, floor * riseRate)
        }
        let needed = opened ? threshold * 0.8 : threshold
        opened = rms >= needed
        return opened
    }
}

/// A `NoiseGate` owned by one analysis pipeline. The pipeline calls it from a single serial
/// queue, so the lock only guards `threshold` reads from other threads.
final class GateBox: @unchecked Sendable {
    private var gate = NoiseGate()
    private let lock = NSLock()

    func process(rms: Float) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return gate.process(rms: rms)
    }

    var threshold: Float {
        lock.lock()
        defer { lock.unlock() }
        return gate.threshold
    }
}

enum InputMeter {
    static func rms(_ samples: [Float]) -> Float {
        var value: Float = 0
        vDSP_rmsqv(samples, 1, &value, vDSP_Length(samples.count))
        return value
    }
}
