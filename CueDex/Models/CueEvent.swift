import Foundation

struct CueEvent: Codable, Equatable, Sendable {
    let source: AttentionSource
    let eventID: String
    let sessionID: String
    let completedAt: Date

    var identity: String { "\(source.rawValue):\(eventID)" }

    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(completedAt)
        return age >= 0 && age < 60
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let event = try decoder.decode(Self.self, from: data)
        guard !event.eventID.isEmpty, event.eventID.utf8.count <= 512,
              !event.sessionID.isEmpty, event.sessionID.utf8.count <= 512 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return event
    }
}

struct CueEventQueue {
    private(set) var pending: [CueEvent] = []
    private var seen: [String: Date] = [:]

    @discardableResult
    mutating func receive(_ event: CueEvent, deliver: Bool, now: Date = .now) -> Bool {
        seen = seen.filter { now.timeIntervalSince($0.value) < 60 }
        guard event.isFresh(at: now), seen[event.identity] == nil else { return false }
        seen[event.identity] = now
        guard deliver else { return true }
        if let index = pending.firstIndex(where: { $0.source == event.source }) {
            if event.completedAt >= pending[index].completedAt { pending[index] = event }
        } else {
            pending.append(event)
        }
        return true
    }

    mutating func next(now: Date = .now) -> CueEvent? {
        while !pending.isEmpty {
            let event = pending.removeFirst()
            if event.isFresh(at: now) { return event }
        }
        return nil
    }

    mutating func remove(source: AttentionSource) { pending.removeAll { $0.source == source } }
    mutating func clear() { pending.removeAll() }
}
