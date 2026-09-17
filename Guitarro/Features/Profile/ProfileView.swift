import DesignSystem
import MusicTheory
import SwiftUI

struct ProfileView: View {
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale

    @State private var showsKeySheet = false
    @State private var hasKey = KeychainStore.read(account: KeychainStore.claudeAPIKeyAccount) != nil

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        Form {
                Section("settings.section.music") {
                    Picker("settings.noteNaming", selection: $noteNaming) {
                        Text("settings.noteNaming.international").tag(NoteNamingStyle.international)
                        Text("settings.noteNaming.german").tag(NoteNamingStyle.german)
                    }
                }
                .guitarroRow()
                Section {
                    Button {
                        showsKeySheet = true
                    } label: {
                        LabeledContent("coach.ai.key.title", value: hasKey ? "••••••" : "–")
                    }
                    .tint(.primary)
                } header: {
                    Text("settings.section.coach")
                } footer: {
                    Text("settings.coach.footer")
                }
                .guitarroRow()
                Section("settings.section.about") {
                    LabeledContent("settings.version", value: version)
                }
                .guitarroRow()
            }
        .guitarroScreen()
        .navigationTitle("tab.profile")
        .sheet(isPresented: $showsKeySheet) {
            APIKeySheet {
                hasKey = KeychainStore.read(account: KeychainStore.claudeAPIKeyAccount) != nil
            }
        }
    }
}

#Preview {
    ProfileView()
}
