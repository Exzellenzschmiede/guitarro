import Foundation
import MusicTheory

enum SettingsKeys {
    static let noteNaming = "settings.noteNaming"
}

extension NoteNamingStyle {
    /// German-speaking users expect "H" for B by default.
    static var defaultForCurrentLocale: NoteNamingStyle {
        Locale.current.language.languageCode?.identifier == "de" ? .german : .international
    }
}
