#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// On-device coach using Apple's system language model. No network, no key, private.
@available(iOS 26, macOS 26, *)
public struct OnDeviceCoachProvider: CoachProvider {
    public let kind: CoachProviderKind = .onDevice

    public init() {}

    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// A short, stable identifier for why the model is unavailable, or nil when it is available.
    public static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: "deviceNotEligible"
            case .appleIntelligenceNotEnabled: "appleIntelligenceNotEnabled"
            case .modelNotReady: "modelNotReady"
            @unknown default: "unknown"
            }
        }
    }

    public func reply(to conversation: [CoachMessage], instructions: String) -> AsyncThrowingStream<String, Error> {
        let prompt = CoachPromptBuilder.flattenedPrompt(conversation: conversation)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    // Small models drift into loops when left unbounded: cap length and cool sampling.
                    let options = GenerationOptions(temperature: 0.6, maximumResponseTokens: 350)
                    var previous = ""
                    for try await snapshot in session.streamResponse(to: prompt, options: options) {
                        let content = snapshot.content
                        if content.hasPrefix(previous) {
                            continuation.yield(String(content.dropFirst(previous.count)))
                        } else {
                            continuation.yield(content)
                        }
                        previous = content
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
