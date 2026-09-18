import Foundation
import Story

public enum Stroke: String, Hashable, Sendable, Codable {
    case down, up, rest
}

/// What a tutorial step shows above its text.
public enum TutorialIllustration: Hashable, Sendable {
    case symbol(String)
    /// A chord voicing whose fingers appear one after another.
    case chord(String)
    /// Two voicings alternating, to show what moves.
    case chordChange(from: String, to: String)
    /// Eight eighth-note slots with strokes, animated in time.
    case strum([Stroke])
    /// The tuner gauge settling into tune.
    case tuning
    /// Notes on the fretboard (MIDI numbers).
    case fretboardNotes([Int])
    /// A video, when the tutorial ships one.
    case video(String)
}

public struct TutorialStep: Hashable, Sendable, Identifiable {
    public let id: String
    public let titleKey: String
    public let bodyKey: String
    public let illustration: TutorialIllustration
    /// A playable check at the end of the step, run with the story challenge engine.
    public let check: StoryChallenge?

    public init(id: String, titleKey: String, bodyKey: String, illustration: TutorialIllustration, check: StoryChallenge? = nil) {
        self.id = id
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.illustration = illustration
        self.check = check
    }
}

public struct Tutorial: Identifiable, Hashable, Sendable {
    public let id: String
    public let categoryKey: String
    public let titleKey: String
    public let summaryKey: String
    public let symbol: String
    public let theme: String
    public let minutes: Int
    public let steps: [TutorialStep]

    public init(id: String, categoryKey: String, titleKey: String, summaryKey: String, symbol: String, theme: String, minutes: Int, steps: [TutorialStep]) {
        self.id = id
        self.categoryKey = categoryKey
        self.titleKey = titleKey
        self.summaryKey = summaryKey
        self.symbol = symbol
        self.theme = theme
        self.minutes = minutes
        self.steps = steps
    }

    public var check: StoryChallenge? { steps.last?.check }
}
