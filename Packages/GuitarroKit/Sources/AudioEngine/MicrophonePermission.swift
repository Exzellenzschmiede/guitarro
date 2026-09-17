import AVFAudio

public enum MicrophonePermission {
    /// Asks the user for microphone access if not decided yet. Returns whether access is granted.
    public static func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public static var isGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    public static var isDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }
}
