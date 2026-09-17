import Foundation
import Testing
@testable import AICoach

@Suite struct SSEParserTests {
    @Test func parsesEventsSeparatedByBlankLines() {
        var parser = SSEParser()
        #expect(parser.feed(line: "event: content_block_delta") == nil)
        #expect(parser.feed(line: "data: {\"type\":\"content_block_delta\"}") == nil)
        let event = parser.feed(line: "")
        #expect(event == SSEEvent(event: "content_block_delta", data: "{\"type\":\"content_block_delta\"}"))
        #expect(parser.feed(line: "") == nil)
    }

    @Test func ignoresCommentsAndJoinsMultilineData() {
        var parser = SSEParser()
        _ = parser.feed(line: ": keep-alive")
        _ = parser.feed(line: "data: a")
        _ = parser.feed(line: "data: b")
        #expect(parser.feed(line: "") == SSEEvent(event: nil, data: "a\nb"))
    }
}

@Suite struct ClaudeProviderTests {
    let provider = ClaudeCoachProvider(apiKey: "sk-test")

    @Test func requestCarriesHeadersAndBody() throws {
        let conversation = [
            CoachMessage(role: .user, text: "Warum schnarrt mein F?"),
            CoachMessage(role: .assistant, text: "Wölbe die Finger."),
            CoachMessage(role: .user, text: "Und der Daumen?"),
        ]
        let request = try provider.makeRequest(conversation: conversation, instructions: "Be helpful.")
        #expect(request.url == ClaudeCoachProvider.endpoint)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(json["model"] as? String == "claude-opus-5")
        #expect(json["stream"] as? Bool == true)
        #expect(json["fallbacks"] as? String == "default")
        #expect(json["system"] as? String == "Be helpful.")
        #expect((json["output_config"] as? [String: Any])?["effort"] as? String == "medium")
        let messages = json["messages"] as! [[String: Any]]
        #expect(messages.count == 3)
        #expect(messages[0]["role"] as? String == "user")
        #expect(messages[2]["content"] as? String == "Und der Daumen?")
    }

    @Test func mergesConsecutiveTurnsAndDropsLeadingAssistant() {
        let turns = ClaudeCoachProvider.mergedTurns([
            CoachMessage(role: .assistant, text: "Hallo!"),
            CoachMessage(role: .user, text: "A"),
            CoachMessage(role: .user, text: "B"),
            CoachMessage(role: .assistant, text: ""),
        ])
        #expect(turns.count == 1)
        #expect(turns[0].text == "A\n\nB")
    }

    @Test func extractsTextDeltasAndDetectsRefusal() throws {
        var collected = ""
        try ClaudeCoachProvider.handle(SSEEvent(event: "content_block_delta", data: #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}"#)) { collected += $0 }
        try ClaudeCoachProvider.handle(SSEEvent(event: "message_start", data: #"{"type":"message_start"}"#)) { collected += $0 }
        #expect(collected == "Hi")
        #expect(throws: CoachError.refused) {
            try ClaudeCoachProvider.handle(SSEEvent(event: "message_delta", data: #"{"type":"message_delta","delta":{"stop_reason":"refusal"}}"#)) { _ in }
        }
        #expect(ClaudeCoachProvider.error(forStatus: 401, body: "") == .unauthorized)
        #expect(ClaudeCoachProvider.error(forStatus: 429, body: "") == .rateLimited)
        #expect(ClaudeCoachProvider.error(forStatus: 500, body: #"{"error":{"message":"boom"}}"#) == .http(500, "boom"))
    }
}

@Suite struct PromptBuilderTests {
    @Test func instructionsIncludeContext() {
        let context = CoachContext(
            languageName: "German",
            noteNamingDescription: "German convention (H for B)",
            tuningDescription: "standard (E A D G B E)",
            availableChords: ["E", "Am"],
            songTitles: ["Amazing Grace"],
            progressLines: ["Em → Am: best 11/min"]
        )
        let text = CoachPromptBuilder.instructions(context: context)
        #expect(text.contains("answer in German"))
        #expect(text.contains("H for B"))
        #expect(text.contains("E, Am"))
        #expect(text.contains("Amazing Grace"))
        #expect(text.contains("Em → Am: best 11/min"))
        #expect(text.contains("cannot hear"))
    }

    @Test func flattenedPromptKeepsRecentHistory() {
        let conversation = [
            CoachMessage(role: .user, text: "Q1"),
            CoachMessage(role: .assistant, text: "A1"),
            CoachMessage(role: .user, text: "Q2"),
        ]
        let prompt = CoachPromptBuilder.flattenedPrompt(conversation: conversation)
        #expect(prompt.contains("Player: Q1"))
        #expect(prompt.contains("Coach: A1"))
        #expect(prompt.hasSuffix("Q2"))
        #expect(CoachPromptBuilder.flattenedPrompt(conversation: [CoachMessage(role: .user, text: "Only")]) == "Only")
    }
}

@Suite struct RepetitionGuardTests {
    @Test func detectsAndTrimsLoops() {
        let line = "* Es ist wichtig, die Finger gewölbt zu halten."
        let looping = "Kurz gesagt:\n" + Array(repeating: line, count: 3).joined(separator: "\n")
        #expect(CoachPromptBuilder.hasRunawayRepetition(looping))
        #expect(!CoachPromptBuilder.hasRunawayRepetition("Kurz gesagt:\n" + line + "\n* Und den Daumen hinter den Hals."))
        #expect(!CoachPromptBuilder.hasRunawayRepetition("ja\nja\nja"))
        let trimmed = CoachPromptBuilder.trimmingRepetition(looping)
        #expect(trimmed == "Kurz gesagt:\n" + line)
    }

    @Test func compactInstructionsStayShort() {
        let context = CoachContext(languageName: "German", noteNamingDescription: "H for B", tuningDescription: "standard", progressLines: ["Em → Am: best 11/min"])
        let text = CoachPromptBuilder.compactInstructions(context: context)
        #expect(text.count < 700)
        #expect(text.contains("German"))
        #expect(text.contains("Bund"))
        #expect(text.contains("Em → Am"))
    }
}
