import Foundation

/// All campaigns, in the order they are offered. "The Lost Melody" is the free entry story.
public enum StoryCampaign {
    public static let all: [StoryCampaignDefinition] = [lostMelody, roadtrip, hillHouse]

    public static func campaign(id: String) -> StoryCampaignDefinition? {
        all.first { $0.id == id }
    }

    /// "The Lost Melody": six chapters in the harbour town of Sanddorn.
    public static let lostMelody = StoryCampaignDefinition(
        id: "lostMelody",
        titleKey: "story.title",
        taglineKey: "story.tagline",
        symbol: "guitars.fill",
        theme: "gold",
        textPrefix: "story.",
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

    /// "Roadtrip": four chapters in a battered van on the way to a summer festival.
    public static let roadtrip = StoryCampaignDefinition(
        id: "roadtrip",
        titleKey: "story.roadtrip.title",
        taglineKey: "story.roadtrip.tagline",
        symbol: "car.fill",
        theme: "sky",
        textPrefix: "story.roadtrip.",
        chapters: [
            StoryChapter(
                id: "road1", number: 1, titleKey: "story.roadtrip.ch1.title", subtitleKey: "story.roadtrip.ch1.subtitle",
                symbol: "car.fill", theme: "sky",
                scenes: [
                    .dialogue(id: "road1.d1", lines: [
                        StoryLine(.narrator, "story.roadtrip.ch1.d1.1"),
                        StoryLine(.nova, "story.roadtrip.ch1.d1.2"),
                        StoryLine(.jules, "story.roadtrip.ch1.d1.3"),
                    ]),
                    .choice(id: "road1.ch1", prompt: StoryLine(.nova, "story.roadtrip.ch1.ch1.prompt"), options: [
                        StoryChoice(id: "road1.ch1.a", textKey: "story.roadtrip.ch1.ch1.a", response: [StoryLine(.nova, "story.roadtrip.ch1.ch1.a.response")]),
                        StoryChoice(id: "road1.ch1.b", textKey: "story.roadtrip.ch1.ch1.b", response: [StoryLine(.jules, "story.roadtrip.ch1.ch1.b.response")]),
                    ]),
                    .dialogue(id: "road1.d2", lines: [
                        StoryLine(.jules, "story.roadtrip.ch1.d2.1"),
                    ]),
                    .challenge(id: "road1.c1", challenge: .playChords(["G", "D", "Em", "C"]),
                               intro: [StoryLine(.nova, "story.roadtrip.ch1.c1.intro")],
                               success: [StoryLine(.jules, "story.roadtrip.ch1.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "road2", number: 2, titleKey: "story.roadtrip.ch2.title", subtitleKey: "story.roadtrip.ch2.subtitle",
                symbol: "fuelpump.fill", theme: "violet",
                scenes: [
                    .dialogue(id: "road2.d1", lines: [
                        StoryLine(.narrator, "story.roadtrip.ch2.d1.1"),
                        StoryLine(.jules, "story.roadtrip.ch2.d1.2"),
                    ]),
                    .dialogue(id: "road2.d2", lines: [
                        StoryLine(.nova, "story.roadtrip.ch2.d2.1"),
                    ]),
                    .challenge(id: "road2.c1", challenge: .chordChanges(from: "G", to: "D", minimum: 12),
                               intro: [StoryLine(.narrator, "story.roadtrip.ch2.c1.intro")],
                               success: [StoryLine(.nova, "story.roadtrip.ch2.c1.success")]),
                    .dialogue(id: "road2.d3", lines: [
                        StoryLine(.narrator, "story.roadtrip.ch2.d3.1"),
                    ]),
                ]
            ),
            StoryChapter(
                id: "road3", number: 3, titleKey: "story.roadtrip.ch3.title", subtitleKey: "story.roadtrip.ch3.subtitle",
                symbol: "wrench.and.screwdriver.fill", theme: "amber",
                scenes: [
                    .dialogue(id: "road3.d1", lines: [
                        StoryLine(.narrator, "story.roadtrip.ch3.d1.1"),
                        StoryLine(.jules, "story.roadtrip.ch3.d1.2"),
                    ]),
                    .choice(id: "road3.ch1", prompt: StoryLine(.jules, "story.roadtrip.ch3.ch1.prompt"), options: [
                        StoryChoice(id: "road3.ch1.a", textKey: "story.roadtrip.ch3.ch1.a", response: [StoryLine(.jules, "story.roadtrip.ch3.ch1.a.response")]),
                        StoryChoice(id: "road3.ch1.b", textKey: "story.roadtrip.ch3.ch1.b", response: [StoryLine(.nova, "story.roadtrip.ch3.ch1.b.response")]),
                    ]),
                    .challenge(id: "road3.c1", challenge: .playNotes([55, 57, 59, 62, 59, 57, 55]),
                               intro: [StoryLine(.jules, "story.roadtrip.ch3.c1.intro")],
                               success: [StoryLine(.jules, "story.roadtrip.ch3.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "road4", number: 4, titleKey: "story.roadtrip.ch4.title", subtitleKey: "story.roadtrip.ch4.subtitle",
                symbol: "music.mic", theme: "gold",
                scenes: [
                    .dialogue(id: "road4.d1", lines: [
                        StoryLine(.narrator, "story.roadtrip.ch4.d1.1"),
                        StoryLine(.nova, "story.roadtrip.ch4.d1.2"),
                    ]),
                    .challenge(id: "road4.c1", challenge: .playSong(id: "saints", tempoPercent: 85, minimumAccuracy: 0.6),
                               intro: [StoryLine(.nova, "story.roadtrip.ch4.c1.intro")],
                               success: [StoryLine(.narrator, "story.roadtrip.ch4.c1.success")]),
                    .dialogue(id: "road4.d2", lines: [
                        StoryLine(.jules, "story.roadtrip.ch4.d2.1"),
                        StoryLine(.nova, "story.roadtrip.ch4.d2.2"),
                    ]),
                ]
            ),
        ]
    )

    /// "The House on the Hill": four chapters of a gentle ghost story in a minor key.
    public static let hillHouse = StoryCampaignDefinition(
        id: "hillHouse",
        titleKey: "story.hillHouse.title",
        taglineKey: "story.hillHouse.tagline",
        symbol: "house.fill",
        theme: "violet",
        textPrefix: "story.hillHouse.",
        chapters: [
            StoryChapter(
                id: "hill1", number: 1, titleKey: "story.hillHouse.ch1.title", subtitleKey: "story.hillHouse.ch1.subtitle",
                symbol: "house.fill", theme: "violet",
                scenes: [
                    .dialogue(id: "hill1.d1", lines: [
                        StoryLine(.narrator, "story.hillHouse.ch1.d1.1"),
                        StoryLine(.hannes, "story.hillHouse.ch1.d1.2"),
                    ]),
                    .choice(id: "hill1.ch1", prompt: StoryLine(.hannes, "story.hillHouse.ch1.ch1.prompt"), options: [
                        StoryChoice(id: "hill1.ch1.a", textKey: "story.hillHouse.ch1.ch1.a", response: [StoryLine(.hannes, "story.hillHouse.ch1.ch1.a.response")]),
                        StoryChoice(id: "hill1.ch1.b", textKey: "story.hillHouse.ch1.ch1.b", response: [StoryLine(.hannes, "story.hillHouse.ch1.ch1.b.response")]),
                    ]),
                    .dialogue(id: "hill1.d2", lines: [
                        StoryLine(.narrator, "story.hillHouse.ch1.d2.1"),
                    ]),
                    .challenge(id: "hill1.c1", challenge: .playChords(["Am", "E", "Am"]),
                               intro: [StoryLine(.narrator, "story.hillHouse.ch1.c1.intro")],
                               success: [StoryLine(.lena, "story.hillHouse.ch1.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "hill2", number: 2, titleKey: "story.hillHouse.ch2.title", subtitleKey: "story.hillHouse.ch2.subtitle",
                symbol: "wind", theme: "mint",
                scenes: [
                    .dialogue(id: "hill2.d1", lines: [
                        StoryLine(.lena, "story.hillHouse.ch2.d1.1"),
                        StoryLine(.you, "story.hillHouse.ch2.d1.2"),
                        StoryLine(.lena, "story.hillHouse.ch2.d1.3"),
                    ]),
                    .challenge(id: "hill2.c1", challenge: .playNotes([57, 59, 60, 62, 64, 62, 60, 57]),
                               intro: [StoryLine(.lena, "story.hillHouse.ch2.c1.intro")],
                               success: [StoryLine(.lena, "story.hillHouse.ch2.c1.success")]),
                    .dialogue(id: "hill2.d2", lines: [
                        StoryLine(.narrator, "story.hillHouse.ch2.d2.1"),
                    ]),
                ]
            ),
            StoryChapter(
                id: "hill3", number: 3, titleKey: "story.hillHouse.ch3.title", subtitleKey: "story.hillHouse.ch3.subtitle",
                symbol: "moon.haze.fill", theme: "ocean",
                scenes: [
                    .dialogue(id: "hill3.d1", lines: [
                        StoryLine(.narrator, "story.hillHouse.ch3.d1.1"),
                        StoryLine(.lena, "story.hillHouse.ch3.d1.2"),
                    ]),
                    .choice(id: "hill3.ch1", prompt: StoryLine(.lena, "story.hillHouse.ch3.ch1.prompt"), options: [
                        StoryChoice(id: "hill3.ch1.a", textKey: "story.hillHouse.ch3.ch1.a", response: [StoryLine(.lena, "story.hillHouse.ch3.ch1.a.response")]),
                        StoryChoice(id: "hill3.ch1.b", textKey: "story.hillHouse.ch3.ch1.b", response: [StoryLine(.lena, "story.hillHouse.ch3.ch1.b.response")]),
                    ]),
                    .challenge(id: "hill3.c1", challenge: .chordChanges(from: "Am", to: "Dm", minimum: 10),
                               intro: [StoryLine(.lena, "story.hillHouse.ch3.c1.intro")],
                               success: [StoryLine(.hannes, "story.hillHouse.ch3.c1.success")]),
                ]
            ),
            StoryChapter(
                id: "hill4", number: 4, titleKey: "story.hillHouse.ch4.title", subtitleKey: "story.hillHouse.ch4.subtitle",
                symbol: "sparkles", theme: "rose",
                scenes: [
                    .dialogue(id: "hill4.d1", lines: [
                        StoryLine(.narrator, "story.hillHouse.ch4.d1.1"),
                        StoryLine(.hannes, "story.hillHouse.ch4.d1.2"),
                    ]),
                    .challenge(id: "hill4.c1", challenge: .playSong(id: "rising-sun", tempoPercent: 80, minimumAccuracy: 0.6),
                               intro: [StoryLine(.lena, "story.hillHouse.ch4.c1.intro")],
                               success: [StoryLine(.narrator, "story.hillHouse.ch4.c1.success")]),
                    .dialogue(id: "hill4.d2", lines: [
                        StoryLine(.lena, "story.hillHouse.ch4.d2.1"),
                        StoryLine(.hannes, "story.hillHouse.ch4.d2.2"),
                    ]),
                ]
            ),
        ]
    )
}
