import Foundation

/// Cloud coach on the Claude Messages API (raw HTTP, streaming).
public struct ClaudeCoachProvider: CoachProvider {
    public static let defaultModel = "claude-opus-5"
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public let kind: CoachProviderKind = .claude
    public var apiKey: String
    public var model: String
    public var maxTokens: Int
    public var session: URLSession

    public init(apiKey: String, model: String = defaultModel, maxTokens: Int = 2048, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.session = session
    }

    struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        struct OutputConfig: Encodable {
            let effort: String
        }
        let model: String
        let maxTokens: Int
        let stream: Bool
        let system: String
        let messages: [Message]
        /// Server-side refusal fallbacks: on a policy decline the API re-runs on a fallback model.
        let fallbacks: String
        let outputConfig: OutputConfig

        enum CodingKeys: String, CodingKey {
            case model, stream, system, messages, fallbacks
            case maxTokens = "max_tokens"
            case outputConfig = "output_config"
        }
    }

    func makeRequest(conversation: [CoachMessage], instructions: String) throws -> URLRequest {
        let body = RequestBody(
            model: model,
            maxTokens: maxTokens,
            stream: true,
            system: instructions,
            messages: Self.mergedTurns(conversation).map { RequestBody.Message(role: $0.role.rawValue, content: $0.text) },
            fallbacks: "default",
            outputConfig: RequestBody.OutputConfig(effort: "medium")
        )
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(body)
        return request
    }

    /// The API requires alternating roles starting with the user; merge accidental doubles.
    static func mergedTurns(_ conversation: [CoachMessage]) -> [CoachMessage] {
        var result: [CoachMessage] = []
        for message in conversation where !message.text.isEmpty {
            if let last = result.last, last.role == message.role {
                result[result.count - 1].text += "\n\n" + message.text
            } else {
                result.append(message)
            }
        }
        if let first = result.first, first.role == .assistant {
            result.removeFirst()
        }
        return result
    }

    public func reply(to conversation: [CoachMessage], instructions: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(conversation: conversation, instructions: instructions)
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw Self.error(forStatus: status, body: body)
                    }
                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        guard let event = parser.feed(line: line) else { continue }
                        try Self.handle(event, yield: { continuation.yield($0) })
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func error(forStatus status: Int, body: String) -> CoachError {
        switch status {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        default: .http(status, Self.errorMessage(from: body) ?? body)
        }
    }

    private static func errorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any]
        else { return nil }
        return error["message"] as? String
    }

    /// Extracts text deltas from stream events; throws on API errors or refusals.
    static func handle(_ event: SSEEvent, yield: (String) -> Void) throws {
        guard let data = event.data.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return }
        switch type {
        case "content_block_delta":
            if let delta = object["delta"] as? [String: Any], delta["type"] as? String == "text_delta", let text = delta["text"] as? String {
                yield(text)
            }
        case "message_delta":
            if let delta = object["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                throw CoachError.refused
            }
        case "error":
            let message = (object["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            throw CoachError.http(0, message)
        default:
            break
        }
    }
}
