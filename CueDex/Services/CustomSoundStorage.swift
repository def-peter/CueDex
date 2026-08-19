import Foundation

struct CustomSoundStorage {
    let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static func live(fileManager: FileManager = .default) -> CustomSoundStorage {
        CustomSoundStorage(
            directory: CueDexPaths.live(fileManager: fileManager).customSoundsDirectory,
            fileManager: fileManager
        )
    }

    func importSound(from sourceURL: URL) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension.lowercased()
        let destinationURL = directory
            .appending(path: "custom-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func removeManagedSound(at url: URL?) {
        guard let url, isManaged(url) else { return }
        try? fileManager.removeItem(at: url)
    }

    func isManaged(_ url: URL) -> Bool {
        url.standardizedFileURL.deletingLastPathComponent() == directory.standardizedFileURL
    }
}
