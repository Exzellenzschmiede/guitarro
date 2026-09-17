import Foundation
import MusicTheory

/// Answers from onboarding, stored in UserDefaults via @AppStorage.
enum PlayerSettingsKeys {
    static let onboardingCompleted = "onboarding.completed"
    static let level = "player.level"
    static let instrument = "player.instrument"
    static let handedness = "player.handedness"
}

enum PlayerLevel: String, CaseIterable, Identifiable {
    case beginner, someExperience, advanced
    var id: String { rawValue }

    /// Where the app opens for this player.
    var startTab: AppTab {
        switch self {
        case .beginner, .someExperience: .story
        case .advanced: .practice
        }
    }
}

enum Instrument: String, CaseIterable, Identifiable {
    case acoustic, electric, both
    var id: String { rawValue }
}

enum Handedness: String, CaseIterable, Identifiable {
    case right, left
    var id: String { rawValue }

    /// Left-handed players hold a mirrored guitar: string order flips on diagrams.
    var mirrorsFretboard: Bool { self == .left }
}
