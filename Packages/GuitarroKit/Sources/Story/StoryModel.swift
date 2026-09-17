import Foundation

public enum StorySpeaker: String, Sendable, Hashable, Codable {
    case narrator, you, rosa, ferro, mila, bo
}

public struct StoryLine: Hashable, Sendable {
    public let speaker: StorySpeaker
    /// Localization key of the text.
    public let textKey: String

    public init(_ speaker: StorySpeaker, _ textKey: String) {
        self.speaker = speaker
        self.textKey = textKey
    }
}

public struct StoryChoice: Hashable, Sendable, Identifiable {
    public let id: String
    public let textKey: String
    public let response: [StoryLine]

    public init(id: String, textKey: String, response: [StoryLine]) {
        self.id = id
        self.textKey = textKey
        self.response = response
    }
}

/// A playable task that gates story progress.
public enum StoryChallenge: Hashable, Sendable {
    /// Bring every open string in tune.
    case tuneStrings
    /// Play these pitches (MIDI numbers) in order.
    case playNotes([Int])
    /// Play these chord voicings in order, holding each briefly.
    case playChords([String])
    /// Change between two voicings at least `minimum` times in one minute.
    case chordChanges(from: String, to: String, minimum: Int)
    /// Play along to a song at the given tempo and hit at least the given share of bars.
    case playSong(id: String, tempoPercent: Int, minimumAccuracy: Double)

    public var symbol: String {
        switch self {
        case .tuneStrings: "tuningfork"
        case .playNotes: "music.note"
        case .playChords: "hand.raised.fingers.spread"
        case .chordChanges: "arrow.triangle.2.circlepath"
        case .playSong: "music.mic"
        }
    }
}

public enum StoryScene: Hashable, Sendable, Identifiable {
    case dialogue(id: String, lines: [StoryLine])
    case choice(id: String, prompt: StoryLine, options: [StoryChoice])
    case challenge(id: String, challenge: StoryChallenge, intro: [StoryLine], success: [StoryLine])

    public var id: String {
        switch self {
        case .dialogue(let id, _), .choice(let id, _, _), .challenge(let id, _, _, _): id
        }
    }

    /// XP awarded for completing the scene.
    public var xp: Int {
        switch self {
        case .dialogue: 5
        case .choice: 10
        case .challenge: 50
        }
    }

    public var isChallenge: Bool {
        if case .challenge = self { return true }
        return false
    }
}

public struct StoryChapter: Identifiable, Hashable, Sendable {
    public let id: String
    public let number: Int
    public let titleKey: String
    public let subtitleKey: String
    public let symbol: String
    /// Name of a `GuitarroPalette` the app maps to colours.
    public let theme: String
    public let scenes: [StoryScene]

    public init(id: String, number: Int, titleKey: String, subtitleKey: String, symbol: String, theme: String, scenes: [StoryScene]) {
        self.id = id
        self.number = number
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.symbol = symbol
        self.theme = theme
        self.scenes = scenes
    }

    public var sceneIDs: [String] { scenes.map(\.id) }
}

public struct StoryCampaignDefinition: Sendable, Hashable {
    public let id: String
    public let titleKey: String
    public let chapters: [StoryChapter]

    public init(id: String, titleKey: String, chapters: [StoryChapter]) {
        self.id = id
        self.titleKey = titleKey
        self.chapters = chapters
    }

    public func chapter(id: String) -> StoryChapter? {
        chapters.first { $0.id == id }
    }

    /// The chapter the player should open next: the first not yet completed one, else the last.
    public func currentChapter(for state: StoryState) -> StoryChapter {
        chapters.first { !state.isChapterComplete($0) } ?? chapters[chapters.count - 1]
    }
}

/// Player progress through a campaign. Scenes are completed or skipped; XP drives the level.
public struct StoryState: Sendable, Hashable, Codable {
    public var completedSceneIDs: Set<String>
    public var skippedSceneIDs: Set<String>
    public var xp: Int

    public static let xpPerLevel = 100

    public init(completedSceneIDs: Set<String> = [], skippedSceneIDs: Set<String> = [], xp: Int = 0) {
        self.completedSceneIDs = completedSceneIDs
        self.skippedSceneIDs = skippedSceneIDs
        self.xp = xp
    }

    public var level: Int { xp / Self.xpPerLevel + 1 }

    /// Progress towards the next level, 0…1.
    public var levelProgress: Double { Double(xp % Self.xpPerLevel) / Double(Self.xpPerLevel) }

    public func isDone(_ sceneID: String) -> Bool {
        completedSceneIDs.contains(sceneID) || skippedSceneIDs.contains(sceneID)
    }

    public func isChapterComplete(_ chapter: StoryChapter) -> Bool {
        chapter.scenes.allSatisfy { isDone($0.id) }
    }

    /// A chapter opens once every earlier chapter is complete.
    public func isChapterUnlocked(_ chapter: StoryChapter, in campaign: StoryCampaignDefinition) -> Bool {
        campaign.chapters.filter { $0.number < chapter.number }.allSatisfy(isChapterComplete)
    }

    public func completedChapterCount(in campaign: StoryCampaignDefinition) -> Int {
        campaign.chapters.filter(isChapterComplete).count
    }

    /// Index of the first scene not yet done, or nil when the chapter is complete.
    public func nextSceneIndex(in chapter: StoryChapter) -> Int? {
        chapter.scenes.firstIndex { !isDone($0.id) }
    }

    public mutating func complete(_ scene: StoryScene) {
        guard !completedSceneIDs.contains(scene.id) else { return }
        skippedSceneIDs.remove(scene.id)
        completedSceneIDs.insert(scene.id)
        xp += scene.xp
    }

    public mutating func skip(_ scene: StoryScene) {
        guard !completedSceneIDs.contains(scene.id) else { return }
        skippedSceneIDs.insert(scene.id)
    }
}
