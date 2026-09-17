import Foundation

public enum CoachProviderKind: String, Sendable, Hashable {
    case onDevice
    case claude
}

/// Produces a streamed reply. Elements are text deltas to append.
public protocol CoachProvider: Sendable {
    var kind: CoachProviderKind { get }
    func reply(to conversation: [CoachMessage], instructions: String) -> AsyncThrowingStream<String, Error>
}
