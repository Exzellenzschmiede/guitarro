import AVFAudio
import Foundation
import os

/// Shared audio session configuration for simultaneous low-latency playback and recording.
public enum AudioSession {
    private static let configured = OSAllocatedUnfairLock(initialState: false)

    /// Activates the session for play-and-record, mixing with other audio so the system music
    /// player keeps running while we listen. Safe to call repeatedly; only the first call after
    /// launch (or after `reset()`) touches the session. Prefer `activateAsync()` from the main thread.
    public static func activate() throws {
        #if os(iOS)
        try configured.withLock { configured in
            guard !configured else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(1024 / 48_000)
            try session.setActive(true)
            configured = true
        }
        #endif
    }

    /// Same as `activate()`, but runs off the main thread (activation can block for a while).
    public static func activateAsync() async throws {
        try await Task.detached(priority: .userInitiated) {
            try activate()
        }.value
    }

    /// Forgets the configured state, e.g. after a media services reset.
    public static func reset() {
        configured.withLock { $0 = false }
    }

    /// True when audio goes to headphones or a Bluetooth device, so the microphone will not hear the speaker.
    public static var isHeadphoneOutputActive: Bool {
        #if os(iOS)
        let ports: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio, .airPlay]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { ports.contains($0.portType) }
        #else
        return false
        #endif
    }
}
