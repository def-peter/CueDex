import CryptoKit
import Darwin
import Foundation

nonisolated struct DownloadedUpdate: Equatable, Sendable {
    let url: URL
    let sha256: String
    let size: Int64
}

enum UpdateDownloadProgress: Sendable {
    case downloading(Double)
    case verifying
}

enum UpdateDownloadError: Error {
    case verificationFailed
    case openFailed
}

actor DmgUpdateDownloader {
    private let directory: URL
    private let session: URLSession

    init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
    }

    nonisolated static var architecture: String {
#if arch(arm64)
        "arm64"
#else
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0)
        return result == 0 && translated == 1 ? "arm64" : "x86_64"
#endif
    }

    func download(
        _ package: UpdatePackage,
        progress: @escaping @Sendable (UpdateDownloadProgress) -> Void
    ) async throws -> DownloadedUpdate {
        try Task.checkCancellation()
        let (checksumData, checksumResponse) = try await session.data(for: request(package.checksum.url))
        try validate(checksumResponse)
        guard checksumData.count == package.checksum.size,
              checksumData.count <= 4096,
              let text = String(data: checksumData, encoding: .utf8) else {
            throw UpdateDownloadError.verificationFailed
        }
        let checksum = try Self.parseChecksum(text, filename: package.installer.name)
        let manager = FileManager.default
        let cache = directory.appending(path: checksum, directoryHint: .isDirectory)
        try manager.createDirectory(at: cache, withIntermediateDirectories: true)
        let destination = cache.appending(path: package.installer.name)
        let update = DownloadedUpdate(url: destination, sha256: checksum, size: package.installer.size)
        if manager.fileExists(atPath: destination.path) {
            progress(.verifying)
            do {
                try verifyFile(update)
                return update
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try manager.removeItem(at: destination)
            }
        }
        progress(.downloading(0))
        let delegate = UpdateDownloadDelegate(size: package.installer.size, progress: progress)
        let (temporary, response) = try await session.download(for: request(package.installer.url), delegate: delegate)
        defer { try? manager.removeItem(at: temporary) }
        try validate(response)
        try Task.checkCancellation()
        progress(.verifying)
        let staging = cache.appending(path: UUID().uuidString + ".part")
        defer { try? manager.removeItem(at: staging) }
        try copyVerifiedFile(from: temporary, to: staging, expected: update)
        try Task.checkCancellation()
        try manager.moveItem(at: staging, to: destination)
        return update
    }

    func verify(_ update: DownloadedUpdate) throws {
        try verifyFile(update)
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("CueDex", forHTTPHeaderField: "User-Agent")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    nonisolated static func parseChecksum(_ text: String, filename: String) throws -> String {
        let fields = text.split(whereSeparator: \.isWhitespace)
        guard fields.count == 2,
              fields[0].range(of: #"\A[0-9a-fA-F]{64}\z"#, options: .regularExpression) != nil,
              fields[1] == Substring(filename) || fields[1] == Substring("*" + filename) else {
            throw UpdateDownloadError.verificationFailed
        }
        return fields[0].lowercased()
    }

    private func verifyFile(_ update: DownloadedUpdate) throws {
        let input = try FileHandle(forReadingFrom: update.url)
        defer { try? input.close() }
        try hashFile(input, output: nil, expected: update)
    }

    private func copyVerifiedFile(from source: URL, to destination: URL, expected: DownloadedUpdate) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil,
                                            attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        try hashFile(input, output: output, expected: expected)
    }

    private func hashFile(_ input: FileHandle, output: FileHandle?, expected: DownloadedUpdate) throws {
        var hash = SHA256()
        var size: Int64 = 0
        while true {
            try Task.checkCancellation()
            guard let data = try input.read(upToCount: 1_048_576), !data.isEmpty else { break }
            size += Int64(data.count)
            guard size <= expected.size else { throw UpdateDownloadError.verificationFailed }
            hash.update(data: data)
            try output?.write(contentsOf: data)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard size == expected.size, digest == expected.sha256 else { throw UpdateDownloadError.verificationFailed }
    }
}

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    private let size: Int64
    private let progress: @Sendable (UpdateDownloadProgress) -> Void

    nonisolated init(size: Int64, progress: @escaping @Sendable (UpdateDownloadProgress) -> Void) {
        self.size = size
        self.progress = progress
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                               didFinishDownloadingTo location: URL) {}

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                               didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                               totalBytesExpectedToWrite: Int64) {
        progress(.downloading(min(1, Double(totalBytesWritten) / Double(size))))
    }
}
