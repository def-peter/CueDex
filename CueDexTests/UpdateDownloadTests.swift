import CryptoKit
import Foundation
import Testing
@testable import CueDex

struct UpdateDownloadTests {
    @Test @MainActor func releaseSelectsOnlyMatchingOfficialArchitectureAssets() throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        let asset = fixture.package.installer
        let data = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v1.2.3",
            "html_url": "https://github.com/def-peter/CueDex/releases/tag/v1.2.3",
            "assets": [asset, fixture.package.checksum].map {
                ["name": $0.name, "browser_download_url": $0.url.absoluteString, "size": $0.size] as [String: Any]
            }
        ])
        var release = try GitHubReleaseClient.decodeRelease(from: data)
        #expect(release.updatePackage(for: "arm64") == fixture.package)
        #expect(release.updatePackage(for: "x86_64") == nil)
        #expect(release.updatePackage(for: "../arm64") == nil)
        release.assets = [asset]
        #expect(release.updatePackage(for: "arm64") == nil)
        release.assets = [
            ReleaseAsset(name: asset.name, url: URL(string: "https://example.com/\(asset.name)")!, size: asset.size),
            fixture.package.checksum
        ]
        #expect(release.updatePackage(for: "arm64") == nil)
        release.assets = [asset, asset, fixture.package.checksum]
        #expect(release.updatePackage(for: "arm64") == nil)
    }

    @Test func checksumMustBindOneHashToTheExpectedFilename() throws {
        let digest = String(repeating: "a", count: 64)
        #expect(try DmgUpdateDownloader.parseChecksum("\(digest.uppercased())  CueDex.dmg\n", filename: "CueDex.dmg") == digest)
        #expect(try DmgUpdateDownloader.parseChecksum("\(digest) *CueDex.dmg\n", filename: "CueDex.dmg") == digest)
        for text in ["\(digest) other.dmg", "bad CueDex.dmg", "\(digest) CueDex.dmg\n\(digest) other.dmg", "\(digest)"] {
            #expect(throws: UpdateDownloadError.self) {
                try DmgUpdateDownloader.parseChecksum(text, filename: "CueDex.dmg")
            }
        }
    }

    @Test func verifiedDownloadIsCachedAndCorruptedCacheIsReplaced() async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        let first = try await fixture.downloader.download(fixture.package) { _ in }
        #expect(try Data(contentsOf: first.url) == fixture.body)
        #expect(fixture.installerRequests == 1)
        let second = try await fixture.downloader.download(fixture.package) { _ in }
        #expect(second == first)
        #expect(fixture.installerRequests == 1)
        try Data("modified".utf8).write(to: first.url)
        await #expect(throws: UpdateDownloadError.self) { try await fixture.downloader.verify(first) }
        let repaired = try await fixture.downloader.download(fixture.package) { _ in }
        #expect(try Data(contentsOf: repaired.url) == fixture.body)
        #expect(fixture.installerRequests == 2)
    }

    @Test(arguments: [Data("wrong payload".utf8), Data("short".utf8), Data(repeating: 0, count: 200)])
    func invalidDownloadsNeverBecomeInstallers(body: Data) async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        fixture.setInstaller(body: body)
        do {
            _ = try await fixture.downloader.download(fixture.package) { _ in }
            Issue.record("An invalid package was accepted")
        } catch {
            #expect(error is UpdateDownloadError)
        }
        let files = FileManager.default.enumerator(at: fixture.root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        #expect(!files.contains { ["dmg", "part"].contains($0.pathExtension) })
        fixture.setInstaller(body: fixture.body)
        let retried = try await fixture.downloader.download(fixture.package) { _ in }
        #expect(try Data(contentsOf: retried.url) == fixture.body)
    }

    @Test func httpErrorsAreNotAcceptedAsInstallers() async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        fixture.setInstaller(body: fixture.body, status: 503)
        do {
            _ = try await fixture.downloader.download(fixture.package) { _ in }
            Issue.record("HTTP error response was accepted")
        } catch {
            #expect((error as? URLError)?.code == .badServerResponse)
        }
    }

    @Test @MainActor func controllerDownloadsOnlyOnRequestAndRechecksBeforeOpening() async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        let suite = "CueDexUpdateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var opened: [URL] = []
        let controller = UpdateController(
            currentVersion: "1.0.0", defaults: defaults,
            downloader: fixture.downloader, architecture: "arm64",
            openInstaller: { opened.append($0) }
        )
        #expect(fixture.installerRequests == 0)
        controller.presentDownload(for: fixture.release)
        try await waitForDownload(controller)
        #expect(controller.downloadState == .ready)
        #expect(opened.isEmpty)
        await controller.openDownloadedInstaller()
        #expect(controller.downloadState == .opened)
        let file = try #require(opened.first)
        try Data("tampered".utf8).write(to: file)
        await controller.openDownloadedInstaller()
        #expect(opened.count == 1)
        #expect(controller.downloadState == .failed("Verification failed. The downloaded file does not match the release checksum."))
    }

    @Test @MainActor func cancellationCannotDeliverLateSuccessAndCanBeRetried() async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        fixture.setInstaller(body: fixture.body, delay: 0.3)
        let controller = UpdateController(downloader: fixture.downloader, architecture: "arm64", openInstaller: { _ in })
        controller.presentDownload(for: fixture.release)
        let deadline = Date().addingTimeInterval(5)
        while fixture.installerRequests == 0 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(fixture.installerRequests == 1)
        controller.cancelDownload()
        #expect(controller.downloadState == .idle)
        fixture.setInstaller(body: fixture.body)
        controller.startDownload()
        try await waitForDownload(controller)
        #expect(controller.downloadState == .ready)
        try await Task.sleep(for: .milliseconds(350))
        #expect(controller.downloadState == .ready)
    }

    @Test @MainActor func installerOpenFailureKeepsTheReleaseAvailableForRetry() async throws {
        let fixture = UpdateFixture()
        defer { fixture.close() }
        var attempts = 0
        let controller = UpdateController(downloader: fixture.downloader, architecture: "arm64", openInstaller: { _ in
            attempts += 1
            throw UpdateDownloadError.openFailed
        })
        controller.presentDownload(for: fixture.release)
        try await waitForDownload(controller)
        await controller.openDownloadedInstaller()
        #expect(attempts == 1)
        #expect(controller.downloadState == .failed("Unable to open the installer. You can view the release to download it manually."))
        #expect(controller.downloadRelease == fixture.release)
        controller.startDownload()
        try await waitForDownload(controller)
        #expect(controller.downloadState == .ready)
        #expect(fixture.installerRequests == 1)
    }

    @Test func updateDownloadActionsAreLocalized() throws {
        let chinese = try #require(Bundle.main.url(forResource: "zh-Hans", withExtension: "lproj").flatMap(Bundle.init(url:)))
        let english = try #require(Bundle.main.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:)))
        for (key, translation) in [
            ("Download Update", "下载更新"), ("Open Installer", "打开安装包"),
            ("Cancel Download", "取消下载"), ("Retry Download", "重试下载"),
            ("Installer Ready", "安装包已就绪"), ("Verifying Download…", "正在校验安装包…")
        ] {
            #expect(chinese.localizedString(forKey: key, value: nil, table: nil) == translation)
            #expect(english.localizedString(forKey: key, value: nil, table: nil) == key)
        }
    }

    @MainActor private func waitForDownload(_ controller: UpdateController) async throws {
        let deadline = Date().addingTimeInterval(5)
        while controller.isDownloading && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!controller.isDownloading)
    }
}

private final class UpdateFixture: @unchecked Sendable {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let body = Data("valid payload".utf8)
    let id = UUID().uuidString
    let package: UpdatePackage
    let session: URLSession
    let downloader: DmgUpdateDownloader

    init() {
        let name = "CueDex-1.2.3-arm64-unsigned.dmg"
        let base = "https://github.com/def-peter/CueDex/releases/download/v1.2.3/"
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let checksum = Data("\(hash)  \(name)\n".utf8)
        package = UpdatePackage(
            installer: ReleaseAsset(name: name, url: URL(string: base + name)!, size: Int64(body.count)),
            checksum: ReleaseAsset(name: name + ".sha256", url: URL(string: base + name + ".sha256")!, size: Int64(checksum.count))
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-CueDex-Test": id]
        session = URLSession(configuration: configuration)
        downloader = DmgUpdateDownloader(directory: root, session: session)
        UpdateURLProtocol.set(id: id, path: package.checksum.url.path, response: .init(data: checksum))
        setInstaller(body: body)
    }

    @MainActor var release: AppRelease {
        AppRelease(version: "1.2.3", pageURL: URL(string: "https://github.com/def-peter/CueDex/releases/tag/v1.2.3")!,
                   assets: [package.installer, package.checksum])
    }

    var installerRequests: Int { UpdateURLProtocol.count(id: id, path: package.installer.url.path) }

    func setInstaller(body: Data, status: Int = 200, delay: TimeInterval = 0) {
        UpdateURLProtocol.set(id: id, path: package.installer.url.path,
                              response: .init(data: body, status: status, delay: delay))
    }

    func close() {
        session.invalidateAndCancel()
        UpdateURLProtocol.remove(id: id)
        try? FileManager.default.removeItem(at: root)
    }
}

private final class UpdateURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub {
        let data: Data
        var status: Int = 200
        var delay: TimeInterval = 0
    }

    private static let lock = NSLock()
    private static var responses: [String: [String: Stub]] = [:]
    private static var counts: [String: [String: Int]] = [:]
    private var pending: DispatchWorkItem?

    static func set(id: String, path: String, response: Stub) {
        lock.withLock { responses[id, default: [:]][path] = response }
    }

    static func count(id: String, path: String) -> Int {
        lock.withLock { counts[id]?[path] ?? 0 }
    }

    static func remove(id: String) {
        lock.withLock {
            responses[id] = nil
            counts[id] = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-CueDex-Test") ?? ""
        let url = request.url!
        let stub = Self.lock.withLock {
            Self.counts[id, default: [:]][url.path, default: 0] += 1
            return Self.responses[id]?[url.path]
        }
        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pending?.isCancelled == false else { return }
            let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil,
                                           headerFields: ["Content-Length": String(stub.data.count)])!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: stub.data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        pending = work
        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: work)
    }

    override func stopLoading() { pending?.cancel() }
}
