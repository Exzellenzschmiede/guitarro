import Testing
import MusicTheory
import Story
@testable import Tutorials

@Suite struct TutorialLibraryTests {
    @Test func libraryIsConsistent() {
        let ids = TutorialLibrary.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for tutorial in TutorialLibrary.all {
            #expect(TutorialLibrary.categories.contains(tutorial.categoryKey), "\(tutorial.id)")
            #expect(!tutorial.steps.isEmpty)
            #expect(tutorial.titleKey.hasPrefix("tutorial.\(tutorial.id)."))
            for step in tutorial.steps {
                switch step.illustration {
                case .chord(let id):
                    #expect(ChordLibrary.voicing(id: id) != nil, "\(tutorial.id): unknown voicing \(id)")
                case .chordChange(let from, let to):
                    #expect(ChordLibrary.voicing(id: from) != nil && ChordLibrary.voicing(id: to) != nil)
                case .strum(let strokes):
                    #expect(strokes.count == 8)
                default:
                    break
                }
            }
        }
    }

    @Test func challengesMapToLessons() {
        #expect(TutorialLibrary.tutorial(for: .tuneStrings)?.id == "tuning")
        #expect(TutorialLibrary.tutorial(for: .playChords(["Em", "Am"]))?.id == "firstChords")
        #expect(TutorialLibrary.tutorial(for: .playChords(["G", "C", "D", "G"]))?.id == "gcd")
        #expect(TutorialLibrary.tutorial(for: .playChords(["F"]))?.id == "barre")
        #expect(TutorialLibrary.tutorial(for: .chordChanges(from: "Em", to: "Am", minimum: 10))?.id == "changes")
        #expect(TutorialLibrary.tutorial(for: .playSong(id: "susanna", tempoPercent: 80, minimumAccuracy: 0.6))?.id == "strumming")
    }
}
