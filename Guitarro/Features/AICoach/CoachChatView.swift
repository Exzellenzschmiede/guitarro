import AICoach
import DesignSystem
import MusicTheory
import SwiftData
import SwiftUI
import Training

struct CoachChatView: View {
    @Query private var progress: [ChordChangeProgress]
    @AppStorage(SettingsKeys.noteNaming) private var noteNaming: NoteNamingStyle = .defaultForCurrentLocale
    @State private var model: CoachChatModel?
    @State private var input = ""
    @State private var showsKeySheet = false
    @FocusState private var inputFocused: Bool

    private let suggestionKeys = ["coach.ai.suggestion.buzz", "coach.ai.suggestion.plan", "coach.ai.suggestion.theory", "coach.ai.suggestion.song"]

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .guitarroScreen(glow: .violet)
        .navigationTitle("coach.ai.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model?.clear()
                } label: {
                    Label("coach.ai.clear", systemImage: "trash")
                }
                .disabled(model?.messages.isEmpty ?? true)
            }
        }
        .onAppear {
            if model == nil {
                model = CoachChatModel(context: .current(noteNaming: noteNaming, progress: progress.skillStates))
            }
        }
        .onChange(of: progress.count) { _, _ in
            model?.context = .current(noteNaming: noteNaming, progress: progress.skillStates)
        }
        .sheet(isPresented: $showsKeySheet) {
            APIKeySheet {
                model?.configureProvider()
            }
        }
    }

    private func content(_ model: CoachChatModel) -> some View {
        VStack(spacing: 0) {
            providerBanner(model)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: GuitarroSpacing.medium) {
                        if model.messages.isEmpty {
                            suggestions(model)
                        }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message, isStreaming: model.isStreaming && message.id == model.messages.last?.id && message.role == .assistant)
                                .id(message.id)
                        }
                        if let error = model.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(Color.guitarroSharp)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.last?.text) { _, _ in
                    if let last = model.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            inputBar(model)
        }
    }

    @ViewBuilder
    private func providerBanner(_ model: CoachChatModel) -> some View {
        switch model.providerKind {
        case .onDevice:
            Label("coach.ai.provider.onDevice", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        case .claude:
            Label("coach.ai.provider.claude", systemImage: "cloud")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        case nil:
            VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
                Label("coach.ai.setup.title", systemImage: "sparkles")
                    .font(.headline)
                Text(setupBody(model))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("coach.ai.setup.addKey") {
                    showsKeySheet = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .guitarroCard()
            .padding([.horizontal, .top])
        }
    }

    private func setupBody(_ model: CoachChatModel) -> LocalizedStringKey {
        switch model.onDeviceUnavailableReason {
        case "appleIntelligenceNotEnabled": "coach.ai.setup.enableAppleIntelligence"
        case "modelNotReady": "coach.ai.setup.modelNotReady"
        default: "coach.ai.setup.body"
        }
    }

    private func suggestions(_ model: CoachChatModel) -> some View {
        VStack(alignment: .leading, spacing: GuitarroSpacing.small) {
            Text("coach.ai.intro")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(suggestionKeys, id: \.self) { key in
                Button {
                    model.send(String(localized: String.LocalizationValue(key)))
                } label: {
                    Text(LocalizedStringKey(key))
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.guitarroAccent.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(!model.hasProvider)
            }
        }
    }

    private func inputBar(_ model: CoachChatModel) -> some View {
        HStack(spacing: GuitarroSpacing.small) {
            TextField("coach.ai.placeholder", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .disabled(!model.hasProvider)
                .onSubmit { submit(model) }
            if model.isStreaming {
                Button {
                    model.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                }
            } else {
                Button {
                    submit(model)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(!model.hasProvider || input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    private func submit(_ model: CoachChatModel) {
        let text = input
        input = ""
        model.send(text)
    }
}

private struct MessageBubble: View {
    let message: CoachMessage
    let isStreaming: Bool

    /// Inline markdown rendering has no headings or lists: turn them into plain, readable lines.
    static func normalised(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var line = String(line)
            while line.hasPrefix("#") { line.removeFirst() }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("* ") || line.hasPrefix("- ") {
                line = "•" + line.dropFirst(1)
            }
            return line
        }.joined(separator: "\n")
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant, let attributed = try? AttributedString(markdown: Self.normalised(message.text), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                } else {
                    Text(message.text)
                }
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.role == .user ? Color.guitarroAccent : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

/// Lets the player store a Claude API key when the on-device model is unavailable.
struct APIKeySheet: View {
    let onSave: () -> Void
    @State private var key = KeychainStore.read(account: KeychainStore.claudeAPIKeyAccount) ?? ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("coach.ai.key.placeholder", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("coach.ai.key.footer")
                }
                .guitarroRow()
            }
            .guitarroScreen(glow: .violet)
            .navigationTitle("coach.ai.key.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            KeychainStore.delete(account: KeychainStore.claudeAPIKeyAccount)
                        } else {
                            KeychainStore.write(trimmed, account: KeychainStore.claudeAPIKeyAccount)
                        }
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
