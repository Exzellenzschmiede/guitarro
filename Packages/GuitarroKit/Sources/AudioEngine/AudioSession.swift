import AVFAudio

/// Shared audio session configuration for simultaneous low-latency playback and recording.
public enum AudioSession {
    /// Activates the session for play-and-record. Safe to call repeatedly.
    public static func activate() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord || session.mode != .measurement {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        }
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(1024 / 48_000)
        try session.setActive(true)
        #endif
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
