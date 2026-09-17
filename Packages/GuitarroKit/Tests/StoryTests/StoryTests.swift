import Testing
@testable import Story

@Suite struct StoryCampaignTests {
    let campaign = StoryCampaign.lostMelody

    @Test func sceneIDsAreUniqueAndChaptersNumbered() {
        let ids = campaign.chapters.flatMap(\.sceneIDs)
        #expect(Set(ids).count == ids.count)
        #expect(campaign.chapters.map(\.number) == Array(1...campaign.chapters.count))
        for chapter in campaign.chapters {
            #expect(chapter.scenes.contains { $0.isChallenge }, "\(chapter.id) needs a challenge")
        }
    }

    @Test func textKeysFollowTheNamingScheme() {
        for chapter in campaign.chapters {
            let prefix = "story.ch\(chapter.number)."
            #expect(chapter.titleKey.hasPrefix(prefix))
            for scene in chapter.scenes {
                switch scene {
                case .dialogue(_, let lines):
                    for line in lines { #expect(line.textKey.hasPrefix(prefix), "\(line.textKey)") }
                case .choice(_, let prompt, let options):
                    #expect(prompt.textKey.hasPrefix(prefix))
                    for option in options {
                        #expect(option.textKey.hasPrefix(prefix))
                        #expect(!option.response.isEmpty)
                    }
                case .challenge(_, _, let intro, let success):
                    #expect(!intro.isEmpty)
                    #expect(!success.isEmpty)
                }
            }
        }
    }

    @Test func progressUnlocksChaptersInOrder() {
        var state = StoryState()
        let first = campaign.chapters[0]
        let second = campaign.chapters[1]
        #expect(state.isChapterUnlocked(first, in: campaign))
        #expect(!state.isChapterUnlocked(second, in: campaign))
        #expect(campaign.currentChapter(for: state).id == first.id)
        #expect(state.nextSceneIndex(in: first) == 0)

        for scene in first.scenes { state.complete(scene) }
        #expect(state.isChapterComplete(first))
        #expect(state.isChapterUnlocked(second, in: campaign))
        #expect(state.nextSceneIndex(in: first) == nil)
        #expect(campaign.currentChapter(for: state).id == second.id)
        #expect(state.xp == first.scenes.reduce(0) { $0 + $1.xp })
        #expect(state.completedChapterCount(in: campaign) == 1)
    }

    @Test func skippingCountsAsDoneWithoutXP() {
        var state = StoryState()
        let challenge = campaign.chapters[0].scenes.first { $0.isChallenge }!
        state.skip(challenge)
        #expect(state.isDone(challenge.id))
        #expect(state.xp == 0)
        state.complete(challenge)
        #expect(state.xp == 50)
        #expect(!state.skippedSceneIDs.contains(challenge.id))
        state.complete(challenge)
        #expect(state.xp == 50)
    }

    @Test func levelsGrowWithXP() {
        var state = StoryState(xp: 0)
        #expect(state.level == 1)
        state.xp = 150
        #expect(state.level == 2)
        #expect(abs(state.levelProgress - 0.5) < 0.0001)
    }

    @Test func everythingCompleteKeepsLastChapterCurrent() {
        var state = StoryState()
        for chapter in campaign.chapters {
            for scene in chapter.scenes { state.complete(scene) }
        }
        #expect(campaign.currentChapter(for: state).id == campaign.chapters.last?.id)
    }
}
