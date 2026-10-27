import Foundation

nonisolated struct AppRelease: Equatable, Identifiable, Sendable {
    let version: String
    let pageURL: URL
    var assets: [ReleaseAsset] = []

    var id: URL { pageURL }

    func updatePackage(for architecture: String) -> UpdatePackage? {
        guard ["arm64", "x86_64"].contains(architecture),
              version.range(of: #"\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z"#,
                            options: .regularExpression) != nil else { return nil }
        let name = "CueDex-\(version)-\(architecture)-unsigned.dmg"
        let base = "https://github.com/def-peter/CueDex/releases/download/v\(version)/"
        let installers = assets.filter { $0.name == name && $0.url.absoluteString == base + name && $0.size > 0 }
        let checksums = assets.filter {
            $0.name == name + ".sha256" && $0.url.absoluteString == base + name + ".sha256"
                && $0.size > 0 && $0.size <= 4096
        }
        guard installers.count == 1, checksums.count == 1 else { return nil }
        return UpdatePackage(installer: installers[0], checksum: checksums[0])
    }
}

nonisolated struct ReleaseAsset: Decodable, Equatable, Sendable {
    let name: String
    let url: URL
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name, size
        case url = "browser_download_url"
    }
}

nonisolated struct UpdatePackage: Equatable, Sendable {
    let installer: ReleaseAsset
    let checksum: ReleaseAsset
}
