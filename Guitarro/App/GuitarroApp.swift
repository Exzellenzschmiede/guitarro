import SwiftData
import SwiftUI

@main
struct GuitarroApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ChordChangeProgress.self, StoryProgress.self, UserSong.self])
    }
}
