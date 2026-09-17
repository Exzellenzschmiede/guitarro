import Foundation

/// "The Lost Melody": six chapters in the harbour town of Sanddorn.
public enum StoryCampaign {
    public static let lostMelody = StoryCampaignDefinition(
        id: "lostMelody",
        titleKey: "story.title",
        chapters: [
            StoryChapter(
                id: "attic", number: 1, titleKey: "story.ch1.title", subtitleKey: "story.ch1.subtitle",
                symbol: "moon.stars.fill", theme: "violet",
                scenes: [
                    .dialogue(id: "attic.d1", lines: [
                        StoryLine(.narrator, "story.ch1.d1.1"),
                        StoryLine(.rosa, "story.ch1.d1.2"),
                        StoryLine(.you, "story.ch1.d1.3"),
                    ]),
                    .dialogue(id: "attic.d2", lines: [
                        StoryLine(.narrator, "story.ch1.d2.1"),
                    ]),
                    .challenge(id: "attic.c1", challenge: .tuneStrings,
                               intro: [StoryLine(.narrator, "story.ch1.c1.intro")],
                               success: [StoryLine(.narrator, "story.ch1.c1.success.1"), StoryLine(.you, "story.ch1.c1.success.2")]),
                    .dialogue(id: "attic.d3", lines: [
                        StoryLine(.narrator, "story.ch1.d3.1"),
                    ]),
                ]
            ),
            StoryChapter(
                id: "workshop", number: 2, titleKey: "story.ch2.title", subtitleKey: "story.ch2.subtitle",
                symbol: "hammer.fill", theme: "amber",
                scenes: [
                    .dialogue(id: "workshop.d1", lines: [
                        StoryLine(.narrator, "story.ch2.d1.1"),
                        StoryLine(.ferro, "story.ch2.d1.2"),
                    ]),
                    .choice(id: "workshop.ch1", prompt: StoryLine(.ferro, "story.ch2.ch1.prompt"), options: [
                        StoryChoice(id: "workshop.ch1.a", textKey: "story.ch2.ch1.a", response: [StoryLine(.ferro, "story.ch2.ch1.a.response")]),
                        StoryChoice(id: "workshop.ch1.b", textKey: "story.ch2.ch1.b", response: [StoryLine(.ferro, "story.ch2.ch1.b.response")]),
                    ]),
                    .dialogue(id: "workshop.d2", lines: [
                        StoryLine(.ferro, "story.ch2.d2.1"),
                    ]),
                    .challenge(id: "workshop.c1", challenge: .playNotes([40, 45, 50, 55, 59, 64]),
                               intro: [StoryLine(.ferro, "story.ch2.c1.intro")],
                               success: [StoryLine(.ferro, "story.ch2.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "pier", number: 3, titleKey: "story.ch3.title", subtitleKey: "story.ch3.subtitle",
                symbol: "water.waves", theme: "ocean",
                scenes: [
                    .dialogue(id: "pier.d1", lines: [
                        StoryLine(.narrator, "story.ch3.d1.1"),
                        StoryLine(.mila, "story.ch3.d1.2"),
                    ]),
                    .dialogue(id: "pier.d2", lines: [
                        StoryLine(.mila, "story.ch3.d2.1"),
                    ]),
                    .challenge(id: "pier.c1", challenge: .playChords(["Em", "Am"]),
                               intro: [StoryLine(.mila, "story.ch3.c1.intro")],
                               success: [StoryLine(.mila, "story.ch3.c1.success")]),
                    .dialogue(id: "pier.d3", lines: [
                        StoryLine(.mila, "story.ch3.d3.1"),
                    ]),
                ]
            ),
            StoryChapter(
                id: "waves", number: 4, titleKey: "story.ch4.title", subtitleKey: "story.ch4.subtitle",
                symbol: "metronome.fill", theme: "sky",
                scenes: [
                    .dialogue(id: "waves.d1", lines: [
                        StoryLine(.mila, "story.ch4.d1.1"),
                        StoryLine(.mila, "story.ch4.d1.2"),
                    ]),
                    .challenge(id: "waves.c1", challenge: .chordChanges(from: "Em", to: "Am", minimum: 10),
                               intro: [StoryLine(.narrator, "story.ch4.c1.intro")],
                               success: [StoryLine(.mila, "story.ch4.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "band", number: 5, titleKey: "story.ch5.title", subtitleKey: "story.ch5.subtitle",
                symbol: "music.mic", theme: "rose",
                scenes: [
                    .dialogue(id: "band.d1", lines: [
                        StoryLine(.narrator, "story.ch5.d1.1"),
                        StoryLine(.bo, "story.ch5.d1.2"),
                    ]),
                    .choice(id: "band.ch1", prompt: StoryLine(.bo, "story.ch5.ch1.prompt"), options: [
                        StoryChoice(id: "band.ch1.a", textKey: "story.ch5.ch1.a", response: [StoryLine(.bo, "story.ch5.ch1.a.response")]),
                        StoryChoice(id: "band.ch1.b", textKey: "story.ch5.ch1.b", response: [StoryLine(.bo, "story.ch5.ch1.b.response")]),
                    ]),
                    .challenge(id: "band.c1", challenge: .playChords(["G", "C", "D", "G"]),
                               intro: [StoryLine(.bo, "story.ch5.c1.intro")],
                               success: [StoryLine(.bo, "story.ch5.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "festival", number: 6, titleKey: "story.ch6.title", subtitleKey: "story.ch6.subtitle",
                symbol: "sparkles", theme: "gold",
                scenes: [
                    .dialogue(id: "festival.d1", lines: [
                        StoryLine(.narrator, "story.ch6.d1.1"),
                        StoryLine(.bo, "story.ch6.d1.2"),
                    ]),
                    .challenge(id: "festival.c1", challenge: .playSong(id: "susanna", tempoPercent: 80, minimumAccuracy: 0.6),
                               intro: [StoryLine(.narrator, "story.ch6.c1.intro")],
                               success: [StoryLine(.narrator, "story.ch6.c1.success")]),
                    .dialogue(id: "festival.d2", lines: [
                        StoryLine(.ferro, "story.ch6.d2.1"),
                        StoryLine(.rosa, "story.ch6.d2.2"),
                    ]),
                ]
            ),
        ]
    )
}
