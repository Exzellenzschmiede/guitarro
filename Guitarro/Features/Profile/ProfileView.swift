import DesignSystem
import MusicTheory
import SwiftUI

struct ProfileView: View {
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @AppStorage(PlayerSettingsKeys.level) private var level: PlayerLevel = .beginner
    @AppStorage(PlayerSettingsKeys.instrument) private var instrument: Instrument = .acoustic
    @AppStorage(PlayerSettingsKeys.handedness) private var handedness: Handedness = .right
    @AppStorage(PlayerSettingsKeys.onboardingCompleted) private var onboardingCompleted = true
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsPaywall = false

    @State private var showsKeySheet = false
    @State private var hasKey = KeychainStore.read(account: KeychainStore.claudeAPIKeyAccount) != nil

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        Form {
                Section {
                    HStack {
                        GuitarroIconBadge("crown.fill", size: 36, palette: .gold)
                        VStack(alignment: .leading) {
                            Text(store.hasPro ? "pro.status.active" : "pro.status.free")
                                .font(.guitarroHeadline)
                            Text(store.hasPro ? "pro.status.active.body" : "pro.status.free.body")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !store.hasPro {
                            Button("pro.unlock") { showsPaywall = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.guitarroAccent)
                        }
                    }
                    Button("pro.restore") { Task { await store.restore() } }
                    #if DEBUG
                    Toggle("settings.debug.pro", isOn: Bindable(store).debugProOverride)
                    #endif
                }
                .guitarroRow()
                Section("settings.section.player") {
                    Picker("onboarding.player.level", selection: $level) {
                        ForEach(PlayerLevel.allCases) { Text(LocalizedStringKey(String("onboarding.level.\($0.rawValue)"))).tag($0) }
                    }
                    Picker("onboarding.player.instrument", selection: $instrument) {
                        ForEach(Instrument.allCases) { Text(LocalizedStringKey(String("onboarding.instrument.\($0.rawValue)"))).tag($0) }
                    }
                    Picker("onboarding.hands.handedness", selection: $handedness) {
                        ForEach(Handedness.allCases) { Text(LocalizedStringKey(String("onboarding.handedness.\($0.rawValue)"))).tag($0) }
                    }
                    Button("settings.showOnboarding") {
                        onboardingCompleted = false
                        dismiss()
                    }
                }
                .guitarroRow()
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
        .sheet(isPresented: $showsPaywall) { PaywallView() }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("common.close") { dismiss() }
            }
        }
    }
}

#Preview {
    ProfileView()
}
