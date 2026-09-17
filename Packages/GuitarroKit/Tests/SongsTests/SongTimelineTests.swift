import Testing
import MusicTheory
@testable import Songs

@Suite struct SongTimelineTests {
    let susanna = SongLibrary.song(id: "susanna")!

    @Test func flattensSectionsWithBookkeeping() {
        let timeline = SongTimeline(song: susanna)
        #expect(timeline.bars.count == 16)
        #expect(timeline.bars[0].isSectionStart)
        #expect(timeline.bars[8].isSectionStart)
        #expect(timeline.bars[8].sectionName == "Refrain")
        #expect(!timeline.bars[9].isSectionStart)
        #expect(timeline.range(forSection: 1) == 8..<16)
        #expect(timeline.range(forSection: nil) == 0..<16)
        #expect(timeline.range(forSection: 7) == 0..<16)
    }

    @Test func beatsCarryTheSoundingChord() {
        let timeline = SongTimeline(song: SongLibrary.song(id: "bruder-jakob")!)
        let beats = timeline.beats(in: 6..<7)
        #expect(beats.count == 4)
        #expect(beats.map(\.chordID) == ["C", "C", "G7", "G7"])
        #expect(beats[0].isDownbeat)
        #expect(!beats[1].isDownbeat)
    }

    @Test func threeFourSplitsUnevenly() {
        let bar = SongBar("G", "D")
        #expect((0..<3).map { bar.chord(atBeat: $0, beatsPerBar: 3) } == ["G", "G", "D"])
    }

    @Test func nextChordSkipsRepeatsAndWraps() {
        let timeline = SongTimeline(song: susanna)
        #expect(timeline.nextChord(after: 0, in: 0..<8) == "D")
        #expect(timeline.nextChord(after: 7, in: 0..<8) == "D")
        #expect(timeline.nextChord(after: 15, in: 8..<16) == "C")
    }

    @Test func tempoScaling() {
        let timeline = SongTimeline(song: susanna)
        #expect(abs(timeline.secondsPerBeat(tempoPercent: 100) - 60.0 / 104) < 0.0001)
        #expect(abs(timeline.secondsPerBeat(tempoPercent: 50) - 120.0 / 104) < 0.0001)
    }

    @Test func libraryIsConsistent() {
        let ids = SongLibrary.songs.map(\.id)
        #expect(Set(ids).count == ids.count)
        for song in SongLibrary.songs {
            #expect(!song.sections.isEmpty, "\(song.id)")
            for chord in song.chordIDs {
                #expect(ChordLibrary.voicing(id: chord) != nil, "\(song.id) uses unknown chord \(chord)")
            }
        }
        #expect(SongLibrary.song(id: "bruder-jakob")?.difficulty == .beginner)
        #expect(SongLibrary.song(id: "rising-sun")?.difficulty == .intermediate)
        #expect(SongLibrary.song(id: "susanna")?.difficulty == .beginner)
        #expect(SongLibrary.song(id: "saints")?.difficulty == .easy)
    }
}
