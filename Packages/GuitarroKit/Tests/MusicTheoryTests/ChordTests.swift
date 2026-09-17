import Testing
@testable import MusicTheory

@Suite struct ChordTests {
    @Test func majorChordTones() {
        let e = Chord(.e)
        #expect(e.pitchClasses == [.e, .gSharp, .b])
        #expect(e.interval(of: .gSharp) == .majorThird)
        #expect(e.interval(of: .g) == nil)
        #expect(e.contains(.b))
    }

    @Test func seventhChordHasFourTones() {
        #expect(Chord(.a, .dominantSeventh).pitchClasses == [.a, .cSharp, .e, .g])
    }

    @Test func symbols() {
        #expect(Chord(.e, .minor).symbol() == "Em")
        #expect(Chord(.b, .minor).symbol(style: .german) == "Hm")
        #expect(Chord(.fSharp, .minor).symbol() == "F♯m")
        #expect(Chord(.c, .majorSeventh).symbol() == "Cmaj7")
    }

    @Test func intervalsBetweenPitchClasses() {
        #expect(Interval.between(.e, .gSharp) == .majorThird)
        #expect(Interval.between(.b, .e) == .perfectFourth)
        #expect(Interval.between(.a, .g) == .minorSeventh)
        #expect(Interval.between(.d, .d) == .unison)
        #expect(Interval.majorThird.shortLabel == "3")
        #expect(Interval.minorSeventh.shortLabel == "♭7")
        #expect(Interval(semitones: 14).name == "majorSecond")
    }
}

@Suite struct ChordVoicingTests {
    @Test func parsesChartShorthand() {
        let c = ChordVoicing(id: "C", chord: Chord(.c), frets: "x32010", fingers: "x32010")
        #expect(c.strings[0] == .muted)
        #expect(c.strings[1] == .fretted(fret: 3, finger: 3))
        #expect(c.strings[2] == .fretted(fret: 2, finger: 2))
        #expect(c.strings[3] == .open)
        #expect(c.mutedStrings == [0])
        #expect(c.positions.count == 5)
        #expect(c.lowestFrettedFret == 1)
        #expect(c.highestFret == 3)
    }

    @Test func voicingPitchesInStandardTuning() {
        let e = ChordLibrary.voicing(id: "E")!
        let names = e.pitches(in: .standard).map { $0.name() }
        #expect(names == ["E2", "B2", "E3", "G♯3", "B3", "E4"])

        let c = ChordLibrary.voicing(id: "C")!
        #expect(c.pitches(in: .standard).map { $0.name() } == ["C3", "E3", "G3", "C4", "E4"])
    }

    @Test func libraryIsConsistent() {
        let ids = ChordLibrary.openChords.map(\.id)
        #expect(Set(ids).count == ids.count)
        for voicing in ChordLibrary.openChords {
            #expect(voicing.strings.count == 6, "\(voicing.id) must cover six strings")
            for pitch in voicing.pitches(in: .standard) {
                #expect(voicing.chord.contains(pitch.pitchClass), "\(voicing.id): \(pitch) is not a chord tone")
            }
            // Every chord tone should sound, except that open voicings may omit the fifth (e.g. C7).
            let sounding = Set(voicing.pitches(in: .standard).map(\.pitchClass))
            let fifth = PitchClass(semitone: voicing.chord.root.rawValue + Interval.perfectFifth.semitones)
            let required = Set(voicing.chord.pitchClasses).subtracting([fifth])
            #expect(required.isSubset(of: sounding), "\(voicing.id) misses a chord tone")
        }
    }

    @Test func barreChordsDeclareBarre() {
        #expect(ChordLibrary.voicing(id: "F")?.barre?.fret == 1)
        #expect(ChordLibrary.voicing(id: "Bm")?.barre?.fromString == 1)
        #expect(ChordLibrary.voicing(id: "Am")?.barre == nil)
    }
}
