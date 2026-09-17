import Foundation
import Story
import SwiftData

/// Persisted campaign progress (one row).
@Model
final class StoryProgress {
    var completedSceneIDs: [String]
    var skippedSceneIDs: [String]
    var xp: Int

    init(state: StoryState = StoryState()) {
        completedSceneIDs = Array(state.completedSceneIDs)
        skippedSceneIDs = Array(state.skippedSceneIDs)
        xp = state.xp
    }

    var state: StoryState {
        get { StoryState(completedSceneIDs: Set(completedSceneIDs), skippedSceneIDs: Set(skippedSceneIDs), xp: xp) }
        set {
            completedSceneIDs = Array(newValue.completedSceneIDs)
            skippedSceneIDs = Array(newValue.skippedSceneIDs)
            xp = newValue.xp
        }
    }
}

extension GuitarroPaletteName {
    static func palette(for theme: String) -> DesignSystem.GuitarroPalette {
        switch theme {
        case "violet": .violet
        case "sky": .sky
        case "mint": .mint
        case "rose": .rose
        case "gold": .gold
        case "ocean": .ocean
        default: .amber
        }
    }
}

enum GuitarroPaletteName {}

import DesignSystem
