import Foundation
import Story

public enum TutorialLibrary {
    public static let categories = ["tutorial.category.basics", "tutorial.category.chords", "tutorial.category.rhythm", "tutorial.category.technique"]

    public static let all: [Tutorial] = [
        Tutorial(
            id: "posture", categoryKey: "tutorial.category.basics", titleKey: "tutorial.posture.title", summaryKey: "tutorial.posture.summary",
            symbol: "figure.seated.side", theme: "amber", minutes: 3,
            steps: [
                TutorialStep(id: "posture.1", titleKey: "tutorial.posture.step1.title", bodyKey: "tutorial.posture.step1.body", illustration: .symbol("figure.seated.side")),
                TutorialStep(id: "posture.2", titleKey: "tutorial.posture.step2.title", bodyKey: "tutorial.posture.step2.body", illustration: .symbol("hand.raised.fingers.spread")),
                TutorialStep(id: "posture.3", titleKey: "tutorial.posture.step3.title", bodyKey: "tutorial.posture.step3.body", illustration: .symbol("hand.wave")),
            ]
        ),
        Tutorial(
            id: "tuning", categoryKey: "tutorial.category.basics", titleKey: "tutorial.tuning.title", summaryKey: "tutorial.tuning.summary",
            symbol: "tuningfork", theme: "mint", minutes: 4,
            steps: [
                TutorialStep(id: "tuning.1", titleKey: "tutorial.tuning.step1.title", bodyKey: "tutorial.tuning.step1.body", illustration: .fretboardNotes([40, 45, 50, 55, 59, 64])),
                TutorialStep(id: "tuning.2", titleKey: "tutorial.tuning.step2.title", bodyKey: "tutorial.tuning.step2.body", illustration: .tuning),
                TutorialStep(id: "tuning.3", titleKey: "tutorial.tuning.step3.title", bodyKey: "tutorial.tuning.step3.body", illustration: .symbol("arrow.triangle.2.circlepath"), check: .tuneStrings),
            ]
        ),
        Tutorial(
            id: "firstChords", categoryKey: "tutorial.category.chords", titleKey: "tutorial.firstChords.title", summaryKey: "tutorial.firstChords.summary",
            symbol: "hand.point.up.left.fill", theme: "ocean", minutes: 6,
            steps: [
                TutorialStep(id: "firstChords.1", titleKey: "tutorial.firstChords.step1.title", bodyKey: "tutorial.firstChords.step1.body", illustration: .chord("Em")),
                TutorialStep(id: "firstChords.2", titleKey: "tutorial.firstChords.step2.title", bodyKey: "tutorial.firstChords.step2.body", illustration: .chord("Am")),
                TutorialStep(id: "firstChords.3", titleKey: "tutorial.firstChords.step3.title", bodyKey: "tutorial.firstChords.step3.body", illustration: .symbol("ear"), check: .playChords(["Em", "Am"])),
            ]
        ),
        Tutorial(
            id: "changes", categoryKey: "tutorial.category.chords", titleKey: "tutorial.changes.title", summaryKey: "tutorial.changes.summary",
            symbol: "arrow.triangle.2.circlepath", theme: "sky", minutes: 5,
            steps: [
                TutorialStep(id: "changes.1", titleKey: "tutorial.changes.step1.title", bodyKey: "tutorial.changes.step1.body", illustration: .chordChange(from: "Em", to: "Am")),
                TutorialStep(id: "changes.2", titleKey: "tutorial.changes.step2.title", bodyKey: "tutorial.changes.step2.body", illustration: .symbol("metronome")),
                TutorialStep(id: "changes.3", titleKey: "tutorial.changes.step3.title", bodyKey: "tutorial.changes.step3.body", illustration: .symbol("timer"), check: .chordChanges(from: "Em", to: "Am", minimum: 8)),
            ]
        ),
        Tutorial(
            id: "gcd", categoryKey: "tutorial.category.chords", titleKey: "tutorial.gcd.title", summaryKey: "tutorial.gcd.summary",
            symbol: "music.mic", theme: "rose", minutes: 8,
            steps: [
                TutorialStep(id: "gcd.1", titleKey: "tutorial.gcd.step1.title", bodyKey: "tutorial.gcd.step1.body", illustration: .chord("G")),
                TutorialStep(id: "gcd.2", titleKey: "tutorial.gcd.step2.title", bodyKey: "tutorial.gcd.step2.body", illustration: .chord("C")),
                TutorialStep(id: "gcd.3", titleKey: "tutorial.gcd.step3.title", bodyKey: "tutorial.gcd.step3.body", illustration: .chord("D")),
                TutorialStep(id: "gcd.4", titleKey: "tutorial.gcd.step4.title", bodyKey: "tutorial.gcd.step4.body", illustration: .chordChange(from: "G", to: "C"), check: .playChords(["G", "C", "D"])),
            ]
        ),
        Tutorial(
            id: "strumming", categoryKey: "tutorial.category.rhythm", titleKey: "tutorial.strumming.title", summaryKey: "tutorial.strumming.summary",
            symbol: "waveform.path", theme: "gold", minutes: 6,
            steps: [
                TutorialStep(id: "strumming.1", titleKey: "tutorial.strumming.step1.title", bodyKey: "tutorial.strumming.step1.body", illustration: .strum([.down, .rest, .down, .rest, .down, .rest, .down, .rest])),
                TutorialStep(id: "strumming.2", titleKey: "tutorial.strumming.step2.title", bodyKey: "tutorial.strumming.step2.body", illustration: .strum([.down, .rest, .down, .up, .rest, .up, .down, .up])),
                TutorialStep(id: "strumming.3", titleKey: "tutorial.strumming.step3.title", bodyKey: "tutorial.strumming.step3.body", illustration: .symbol("hand.wave"), check: .playSong(id: "bruder-jakob", tempoPercent: 80, minimumAccuracy: 0.5)),
            ]
        ),
        Tutorial(
            id: "barre", categoryKey: "tutorial.category.technique", titleKey: "tutorial.barre.title", summaryKey: "tutorial.barre.summary",
            symbol: "rectangle.compress.vertical", theme: "violet", minutes: 7,
            steps: [
                TutorialStep(id: "barre.1", titleKey: "tutorial.barre.step1.title", bodyKey: "tutorial.barre.step1.body", illustration: .chord("F")),
                TutorialStep(id: "barre.2", titleKey: "tutorial.barre.step2.title", bodyKey: "tutorial.barre.step2.body", illustration: .symbol("hand.thumbsup")),
                TutorialStep(id: "barre.3", titleKey: "tutorial.barre.step3.title", bodyKey: "tutorial.barre.step3.body", illustration: .symbol("bolt.heart"), check: .playChords(["F"])),
            ]
        ),
    ]

    public static func tutorial(id: String) -> Tutorial? {
        all.first { $0.id == id }
    }

    public static func tutorials(in category: String) -> [Tutorial] {
        all.filter { $0.categoryKey == category }
    }

    /// The lesson that prepares a player for a story or practice challenge.
    public static func tutorial(for challenge: StoryChallenge) -> Tutorial? {
        switch challenge {
        case .tuneStrings, .playNotes:
            return tutorial(id: "tuning")
        case .playChords(let chords):
            if chords.contains("F") { return tutorial(id: "barre") }
            if chords.contains(where: { ["G", "C", "D"].contains($0) }) { return tutorial(id: "gcd") }
            return tutorial(id: "firstChords")
        case .chordChanges:
            return tutorial(id: "changes")
        case .playSong:
            return tutorial(id: "strumming")
        }
    }
}
