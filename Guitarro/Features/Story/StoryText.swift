import Foundation
import Story
import SwiftUI

enum StoryText {
    static func speakerName(_ speaker: StorySpeaker) -> LocalizedStringKey {
        LocalizedStringKey(String("story.speaker.\(speaker.rawValue)"))
    }

    static func speakerColor(_ speaker: StorySpeaker) -> Color {
        switch speaker {
        case .narrator: .guitarroMuted
        case .you: .guitarroAccent
        case .rosa: Color(red: 0.95, green: 0.75, blue: 0.85)
        case .ferro: Color(red: 0.85, green: 0.70, blue: 0.45)
        case .mila: Color(red: 0.55, green: 0.85, blue: 0.90)
        case .bo: Color(red: 1.0, green: 0.55, blue: 0.45)
        case .nova: Color(red: 1.0, green: 0.85, blue: 0.4)
        case .jules: Color(red: 0.6, green: 0.9, blue: 0.6)
        case .lena: Color(red: 0.8, green: 0.85, blue: 1.0)
        case .hannes: Color(red: 0.8, green: 0.68, blue: 0.55)
        }
    }

    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
