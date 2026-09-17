import AICoach
import Foundation
import MusicTheory
import Observation
import Songs
import Training

@MainActor
@Observable
final class CoachChatModel {
    private(set) var messages: [CoachMessage] = []
    private(set) var isStreaming = false
    private(set) var errorMessage: String?
    private(set) var providerKind: CoachProviderKind?
    /// Why the on-device model is unavailable, when it is.
    private(set) var onDeviceUnavailableReason: String?
    var context: CoachContext

    private var provider: (any CoachProvider)?
    private var task: Task<Void, Never>?

    init(context: CoachContext) {
        self.context = context
        configureProvider()
    }

    var hasProvider: Bool { provider != nil }

    /// Prefers Claude when the player stored a key (much stronger answers); otherwise the
    /// on-device model, which needs no key and keeps everything private.
    func configureProvider() {
        if let key = KeychainStore.read(account: KeychainStore.claudeAPIKeyAccount), !key.isEmpty {
            provider = ClaudeCoachProvider(apiKey: key)
            providerKind = .claude
            onDeviceUnavailableReason = nil
            return
        }
        #if canImport(FoundationModels)
        if OnDeviceCoachProvider.isAvailable {
            provider = OnDeviceCoachProvider()
            providerKind = .onDevice
            onDeviceUnavailableReason = nil
            return
        }
        onDeviceUnavailableReason = OnDeviceCoachProvider.unavailabilityReason
        #endif
        provider = nil
        providerKind = nil
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, let provider else { return }
        errorMessage = nil
        messages.append(CoachMessage(role: .user, text: trimmed))
        let conversation = messages
        let reply = CoachMessage(role: .assistant, text: "")
        messages.append(reply)
        isStreaming = true

        let instructions = provider.kind == .onDevice
            ? CoachPromptBuilder.compactInstructions(context: context)
            : CoachPromptBuilder.instructions(context: context)
        task = Task {
            do {
                for try await delta in provider.reply(to: conversation, instructions: instructions) {
                    append(delta, to: reply.id)
                    if let index = messages.firstIndex(where: { $0.id == reply.id }),
                       CoachPromptBuilder.hasRunawayRepetition(messages[index].text) {
                        messages[index].text = CoachPromptBuilder.trimmingRepetition(messages[index].text)
                        break
                    }
                }
            } catch is CancellationError {
                // Stopped by the user; keep what arrived.
            } catch {
                errorMessage = error.localizedDescription
            }
            if let index = messages.firstIndex(where: { $0.id == reply.id }), messages[index].text.isEmpty {
                messages.remove(at: index)
            }
            isStreaming = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isStreaming = false
    }

    func clear() {
        stop()
        messages.removeAll()
        errorMessage = nil
    }

    private func append(_ delta: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += delta
    }
}

extension CoachContext {
    /// Builds the coach's knowledge of this player from app state.
    static func current(noteNaming: NoteNamingStyle, progress: [ChordPair: SkillState]) -> CoachContext {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let languageName = Locale(identifier: "en").localizedString(forLanguageCode: language) ?? "English"
        let naming = noteNaming == .german
            ? "German convention: B is written H and B♭ is written B; sharps use ♯ (e.g. F♯)"
            : "International convention: C D E F G A B with ♯/♭"
        let lines = progress.sorted { $0.value.due < $1.value.due }.map { pair, state -> String in
            let due = state.due <= .now ? "due now" : "due \(state.due.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
            return "\(pair.from) → \(pair.to): best \(state.best) changes/min, last \(state.last), \(state.reviews) sessions, \(due)"
        }
        return CoachContext(
            languageName: languageName,
            noteNamingDescription: naming,
            tuningDescription: "standard (E A D G B E)",
            availableChords: ChordLibrary.openChords.map { $0.chord.symbol() },
            songTitles: SongLibrary.songs.map { "\($0.title) (\($0.key), chords \($0.chordIDs.joined(separator: " ")))" },
            progressLines: lines
        )
    }
}
