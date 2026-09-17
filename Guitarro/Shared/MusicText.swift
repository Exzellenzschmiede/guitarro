import Foundation
import MusicTheory

/// Localized, human-readable names for music-theory values.
enum MusicText {
    static func qualityName(_ quality: ChordQuality) -> String {
        localized("chord.quality.\(quality.rawValue)")
    }

    static func intervalName(_ interval: Interval) -> String {
        localized("interval.\(interval.name)")
    }

    static func hint(for quality: ChordQuality) -> String {
        localized("chord.hint.\(quality.rawValue)")
    }

    /// "E Major" in English, "E-Dur" in German.
    static func chordTitle(_ chord: Chord, noteNaming: NoteNamingStyle) -> String {
        String(format: String(localized: "chord.title"), chord.root.name(style: noteNaming), qualityName(chord.quality))
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
