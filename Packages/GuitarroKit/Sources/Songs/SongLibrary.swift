import Foundation

/// Traditional songs (chords only, no lyrics) arranged with chords from `ChordLibrary`.
public enum SongLibrary {
    public static let songs: [Song] = [
        Song(
            id: "bruder-jakob", title: "Bruder Jakob (Frère Jacques)", artist: "Traditional", key: "C", beatsPerMinute: 96,
            sections: [
                SongSection(id: "round", name: "Kanon", bars: [
                    SongBar("C"), SongBar("C"), SongBar("C"), SongBar("C"),
                    SongBar("C"), SongBar("C"), SongBar("C", "G7"), SongBar("C"),
                ]),
            ]
        ),
        Song(
            id: "saints", title: "When the Saints Go Marching In", artist: "Traditional", key: "G", beatsPerMinute: 110,
            sections: [
                SongSection(id: "verse", name: "Strophe", bars: [
                    SongBar("G"), SongBar("G"), SongBar("G"), SongBar("G"),
                    SongBar("G"), SongBar("G"), SongBar("D"), SongBar("D"),
                    SongBar("G"), SongBar("G7"), SongBar("C"), SongBar("C"),
                    SongBar("G"), SongBar("D"), SongBar("G"), SongBar("G"),
                ]),
            ]
        ),
        Song(
            id: "susanna", title: "Oh! Susanna", artist: "Traditional", key: "G", beatsPerMinute: 104,
            sections: [
                SongSection(id: "verse", name: "Strophe", bars: [
                    SongBar("G"), SongBar("G"), SongBar("G"), SongBar("D"),
                    SongBar("G"), SongBar("G"), SongBar("D"), SongBar("G"),
                ]),
                SongSection(id: "chorus", name: "Refrain", bars: [
                    SongBar("C"), SongBar("C"), SongBar("G"), SongBar("D"),
                    SongBar("G"), SongBar("G"), SongBar("D"), SongBar("G"),
                ]),
            ]
        ),
        Song(
            id: "amazing-grace", title: "Amazing Grace", artist: "Traditional", key: "G", beatsPerMinute: 72, beatsPerBar: 3,
            sections: [
                SongSection(id: "verse", name: "Strophe", bars: [
                    SongBar("G"), SongBar("G7"), SongBar("C"), SongBar("G"),
                    SongBar("G"), SongBar("Em"), SongBar("D"), SongBar("D"),
                    SongBar("G"), SongBar("G7"), SongBar("C"), SongBar("G"),
                    SongBar("Em"), SongBar("D"), SongBar("G"), SongBar("G"),
                ]),
            ]
        ),
        Song(
            id: "rising-sun", title: "House of the Rising Sun", artist: "Traditional", key: "Am", beatsPerMinute: 80,
            sections: [
                SongSection(id: "verse", name: "Strophe", bars: [
                    SongBar("Am"), SongBar("C"), SongBar("D"), SongBar("F"),
                    SongBar("Am"), SongBar("C"), SongBar("E"), SongBar("E"),
                    SongBar("Am"), SongBar("C"), SongBar("D"), SongBar("F"),
                    SongBar("Am"), SongBar("E"), SongBar("Am"), SongBar("Am"),
                ]),
            ]
        ),
        Song(
            id: "greensleeves", title: "Greensleeves", artist: "Traditional", key: "Am", beatsPerMinute: 84, beatsPerBar: 3,
            sections: [
                SongSection(id: "verse", name: "Strophe", bars: [
                    SongBar("Am"), SongBar("C"), SongBar("G"), SongBar("Em"),
                    SongBar("Am"), SongBar("F"), SongBar("E"), SongBar("E"),
                    SongBar("Am"), SongBar("C"), SongBar("G"), SongBar("Em"),
                    SongBar("Am"), SongBar("E"), SongBar("Am"), SongBar("Am"),
                ]),
                SongSection(id: "chorus", name: "Refrain", bars: [
                    SongBar("C"), SongBar("C"), SongBar("G"), SongBar("Em"),
                    SongBar("Am"), SongBar("F"), SongBar("E"), SongBar("E"),
                    SongBar("C"), SongBar("C"), SongBar("G"), SongBar("Em"),
                    SongBar("Am"), SongBar("E"), SongBar("Am"), SongBar("Am"),
                ]),
            ]
        ),
    ]

    public static func song(id: String) -> Song? {
        songs.first { $0.id == id }
    }
}
