import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case story, practice, fretboard, songs, tuner
}

/// Shared tab selection so screens can send the player to another tab.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .story
}
