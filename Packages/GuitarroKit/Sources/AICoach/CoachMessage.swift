import Foundation

public struct CoachMessage: Identifiable, Hashable, Sendable, Codable {
    public enum Role: String, Sendable, Codable {
        case user, assistant
    }

    public let id: UUID
    public let role: Role
    public var text: String
    public let date: Date

    public init(id: UUID = UUID(), role: Role, text: String, date: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}

/// What the coach knows about the player and the app when answering.
public struct CoachContext: Sendable, Hashable {
    /// Language the coach must answer in, e.g. "German".
    public var languageName: String
    /// e.g. "German convention: B is written H, B♭ is written B".
    public var noteNamingDescription: String
    public var tuningDescription: String
    /// Chord voicings the app can show, by symbol.
    public var availableChords: [String]
    public var songTitles: [String]
    /// One line per practised chord change, e.g. "Em → Am: best 11 changes/min, due in 12 hours".
    public var progressLines: [String]

    public init(
        languageName: String,
        noteNamingDescription: String,
        tuningDescription: String,
        availableChords: [String] = [],
        songTitles: [String] = [],
        progressLines: [String] = []
    ) {
        self.languageName = languageName
        self.noteNamingDescription = noteNamingDescription
        self.tuningDescription = tuningDescription
        self.availableChords = availableChords
        self.songTitles = songTitles
        self.progressLines = progressLines
    }
}

public enum CoachError: Error, Sendable, LocalizedError, Equatable {
    case noProvider
    case unauthorized
    case rateLimited
    case http(Int, String)
    case refused
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .noProvider: "No coach is configured."
        case .unauthorized: "The API key was rejected."
        case .rateLimited: "Too many requests. Please wait a moment."
        case .http(let status, let message): "Request failed (\(status)): \(message)"
        case .refused: "The coach declined to answer this."
        case .unavailable(let reason): reason
        }
    }
}
