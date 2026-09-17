import Foundation

/// Builds the system instructions shared by every provider.
public enum CoachPromptBuilder {
    public static func instructions(context: CoachContext) -> String {
        var lines: [String] = []
        lines.append("You are the in-app coach of Guitarro, a guitar learning app for iPhone and iPad. You help beginners and intermediate players on acoustic and electric guitar.")
        lines.append("Always answer in \(context.languageName). Be warm, concrete and brief: usually under 120 words, unless the player asks for a full exercise or explanation. Use short bullet lists and bold chord names sparingly; no headings.")
        lines.append("Note names: \(context.noteNamingDescription). The player's guitar is tuned \(context.tuningDescription).")
        lines.append("You cannot hear or see the player. Never claim to have listened or watched. When it helps, point them to the app's tools: the tuner, the living fretboard (notes, intervals, chord shapes with explanations), the chord change trainer (one-minute changes with spaced repetition), the camera coach (finger arch and thumb position), and the songs mode (chords with backing, tempo and loops).")
        if !context.availableChords.isEmpty {
            lines.append("Chord shapes the app can show: \(context.availableChords.joined(separator: ", ")).")
        }
        if !context.songTitles.isEmpty {
            lines.append("Songs in the app: \(context.songTitles.joined(separator: "; ")).")
        }
        if context.progressLines.isEmpty {
            lines.append("The player has not practised chord changes in the app yet.")
        } else {
            lines.append("The player's chord change progress:\n- " + context.progressLines.joined(separator: "\n- "))
        }
        lines.append("Prefer practical advice over theory dumps. When suggesting practice, give a time-boxed plan (e.g. 3 × 2 minutes). If the question is not about guitar or music, say so kindly and steer back.")
        return lines.joined(separator: "\n\n")
    }

    /// Shorter instructions for small on-device models: fewer lists, firm length limit, terminology hint.
    public static func compactInstructions(context: CoachContext) -> String {
        var lines: [String] = []
        lines.append("You are a friendly guitar coach inside the Guitarro app. Answer in \(context.languageName), in at most 5 short sentences or 4 short bullet points. Never repeat a sentence. Use correct guitar terminology in that language (German: Bund, Saite, Griffhand, Anschlag, Barré).")
        lines.append("Note names: \(context.noteNamingDescription). You cannot hear or see the player.")
        if !context.progressLines.isEmpty {
            lines.append("Player progress: " + context.progressLines.prefix(3).joined(separator: "; ") + ".")
        }
        lines.append("Give one concrete tip first, then at most one practice suggestion with a time box.")
        return lines.joined(separator: " ")
    }

    /// Detects runaway repetition in streamed text: the same non-empty line three times in a row.
    public static func hasRunawayRepetition(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "*-• ")) }
            .filter { !$0.isEmpty }
        guard lines.count >= 3 else { return false }
        let last = lines.suffix(3)
        return Set(last).count == 1 && (last.first?.count ?? 0) > 12
    }

    /// Cuts repeated trailing lines, keeping the first occurrence.
    public static func trimmingRepetition(_ text: String) -> String {
        var kept: [Substring] = []
        var previous = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let normalised = line.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "*-• "))
            if !normalised.isEmpty, normalised == previous { continue }
            if !normalised.isEmpty { previous = normalised }
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Prior turns folded into a single prompt for providers without server-side history.
    public static func flattenedPrompt(conversation: [CoachMessage], maximumTurns: Int = 8) -> String {
        let recent = Array(conversation.suffix(maximumTurns))
        guard let last = recent.last, last.role == .user else {
            return recent.map(\.text).joined(separator: "\n")
        }
        let history = recent.dropLast()
        guard !history.isEmpty else { return last.text }
        let transcript = history.map { "\($0.role == .user ? "Player" : "Coach"): \($0.text)" }.joined(separator: "\n")
        return "Earlier in this conversation:\n\(transcript)\n\nPlayer now asks:\n\(last.text)"
    }
}
