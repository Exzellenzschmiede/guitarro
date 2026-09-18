import DesignSystem
import Foundation
import Story
import SwiftData

/// Persisted campaign progress (one row per campaign).
@Model
final class StoryProgress {
    /// Rows written before there were several campaigns belong to "The Lost Melody".
    var campaignID: String = "lostMelody"
    var completedSceneIDs: [String]
    var skippedSceneIDs: [String]
    var xp: Int

    init(campaignID: String = "lostMelody", state: StoryState = StoryState()) {
        self.campaignID = campaignID
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

extension Array where Element == StoryProgress {
    func state(for campaign: StoryCampaignDefinition) -> StoryState {
        first { $0.campaignID == campaign.id }?.state ?? StoryState()
    }

    /// XP from every campaign; the player's level grows across stories.
    var totalXP: Int { reduce(0) { $0 + $1.xp } }

    var overallState: StoryState { StoryState(xp: totalXP) }

    /// The story the player is in the middle of, else the first unfinished one.
    var currentCampaign: StoryCampaignDefinition {
        let started = StoryCampaign.all.first { campaign in
            let state = state(for: campaign)
            return !state.completedSceneIDs.isEmpty && !campaign.isComplete(for: state)
        }
        return started ?? StoryCampaign.all.first { !$0.isComplete(for: state(for: $0)) } ?? StoryCampaign.lostMelody
    }
}

/// Route to a chapter inside its campaign.
struct StoryChapterRoute: Hashable {
    let campaign: StoryCampaignDefinition
    let chapter: StoryChapter
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
