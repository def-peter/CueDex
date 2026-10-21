import Darwin
import Foundation
import OSLog

final class CueEventMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Events")
    private let fileManager: FileManager
    private let eventsDirectory: URL
    private let freshnessInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.peter.CueDex.events", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var handler: (@MainActor @Sendable (CueEvent) -> Void)?

    init(
        eventsDirectory: URL,
        freshnessInterval: TimeInterval = 60,
        fileManager: FileManager = .default
    ) {
        self.eventsDirectory = eventsDirectory
        self.freshnessInterval = freshnessInterval
        self.fileManager = fileManager
    }

    deinit {
        if let source {
            source.cancel()
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    func start(handler: @escaping @MainActor @Sendable (CueEvent) -> Void) throws {
        guard source == nil else { return }
        self.handler = handler
        try fileManager.createDirectory(at: eventsDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        fileDescriptor = open(eventsDirectory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw CocoaError(.fileReadUnknown)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.consumePendingEvents() }
        source.setCancelHandler { [fileDescriptor] in close(fileDescriptor) }
        self.source = source
        source.resume()
        queue.async { [weak self] in self?.consumePendingEvents() }
        logger.info("Started local cue event monitor")
    }

    private func consumePendingEvents() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: eventsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        var events: [CueEvent] = []
        for url in urls where url.lastPathComponent.hasPrefix("turn-complete.")
            || (url.lastPathComponent.hasPrefix("cue-") && url.pathExtension == "json") {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { continue }
            if let modified = values?.contentModificationDate,
               Self.isFreshEvent(
                   modifiedAt: modified,
                   now: now,
                   freshnessInterval: freshnessInterval
               ) {
                if let size = values?.fileSize, size <= 16_384, let data = try? Data(contentsOf: url) {
                    if let event = try? CueEvent.decode(data) {
                        events.append(event)
                    } else if data.isEmpty && url.lastPathComponent.hasPrefix("turn-complete.") {
                        // Existing installed helpers remain valid during the upgrade.
                        events.append(CueEvent(
                            source: .codex,
                            eventID: "legacy-\(url.lastPathComponent)-\(modified.timeIntervalSince1970)",
                            sessionID: "legacy", completedAt: modified
                        ))
                    }
                }
            }
            try? fileManager.removeItem(at: url)
        }

        guard !events.isEmpty, let handler else { return }
        let sorted = events.sorted { $0.completedAt < $1.completedAt }
        Task { @MainActor in
            for event in sorted { handler(event) }
        }
    }

    nonisolated static func isFreshEvent(
        modifiedAt: Date,
        now: Date,
        freshnessInterval: TimeInterval
    ) -> Bool {
        let age = now.timeIntervalSince(modifiedAt)
        return age >= 0 && age < freshnessInterval
    }
}
