import DesignSystem
import SwiftUI

/// Top-level navigation. Renders a tab bar on iPhone and a sidebar on iPad.
struct RootView: View {
    @State private var navigation = AppNavigation()
    @State private var store = StoreManager()
    @AppStorage(PlayerSettingsKeys.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(PlayerSettingsKeys.level) private var level: PlayerLevel = .beginner

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab("tab.story", systemImage: "book.pages", value: .story) {
                StoryView()
            }
            Tab("tab.practice", systemImage: "figure.play", value: .practice) {
                PracticeHomeView()
            }
            Tab("tab.fretboard", systemImage: "square.grid.3x3", value: .fretboard) {
                FretboardScreen()
            }
            Tab("tab.songs", systemImage: "music.note.list", value: .songs) {
                SongsView()
            }
            Tab("tab.tuner", systemImage: "tuningfork", value: .tuner) {
                TunerView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.guitarroAccent)
        .environment(navigation)
        .environment(store)
        .preferredColorScheme(.dark)
        .task {
            navigation.selectedTab = level.startTab
            await store.load()
        }
        .fullScreenCover(isPresented: Binding(get: { !onboardingCompleted }, set: { _ in })) {
            OnboardingView()
                .environment(navigation)
        }
    }
}

#Preview {
    RootView()
}
