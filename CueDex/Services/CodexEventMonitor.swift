import Darwin
import Foundation
import OSLog

final class CodexEventMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Events")
    private let fileManager: FileManager
    private let eventsDirectory: URL
    private let freshnessInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.peter.CueDex.events", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var handler: (@MainActor @Sendable () -> Void)?

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

    func start(handler: @escaping @MainActor @Sendable () -> Void) throws {
        guard source == nil else { return }
        self.handler = handler
        try fileManager.createDirectory(at: eventsDirectory, withIntermediateDirectories: true)

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
        logger.info("Started local Codex event monitor")
    }

    private func consumePendingEvents() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: eventsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        var freshEventCount = 0
        for url in urls where url.lastPathComponent.hasPrefix("turn-complete.") {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values?.contentModificationDate,
               Self.isFreshEvent(
                   modifiedAt: modified,
                   now: now,
                   freshnessInterval: freshnessInterval
               ) {
                freshEventCount += 1
            }
            try? fileManager.removeItem(at: url)
        }

        guard freshEventCount > 0, let handler else { return }
        logger.info("Received \(freshEventCount, privacy: .public) completion event(s)")
        Task { @MainActor in handler() }
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
