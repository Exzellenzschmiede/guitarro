import Foundation

public struct SSEEvent: Equatable, Sendable {
    public var event: String?
    public var data: String
}

/// Incremental parser for text/event-stream: feed lines, get events back on blank lines.
public struct SSEParser: Sendable {
    private var event: String?
    private var dataLines: [String] = []

    public init() {}

    public mutating func feed(line: String) -> SSEEvent? {
        if line.isEmpty {
            guard !dataLines.isEmpty || event != nil else { return nil }
            let result = SSEEvent(event: event, data: dataLines.joined(separator: "\n"))
            event = nil
            dataLines.removeAll()
            return result
        }
        if line.hasPrefix(":") { return nil }
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        var value = parts.count > 1 ? String(parts[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        switch field {
        case "event": event = value
        case "data": dataLines.append(value)
        default: break
        }
        return nil
    }
}
