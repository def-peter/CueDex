import Foundation

struct GitHubReleaseClient {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/def-peter/CueDex/releases/latest"
    )!

    private let session: URLSession
    private let endpoint: URL

    init(session: URLSession = .shared, endpoint: URL = Self.latestReleaseURL) {
        self.session = session
        self.endpoint = endpoint
    }

    func fetchLatestRelease() async throws -> AppRelease {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CueDex", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try Self.decodeRelease(from: data)
    }

    static func decodeRelease(from data: Data) throws -> AppRelease {
        let response = try JSONDecoder().decode(ReleaseResponse.self, from: data)
        return AppRelease(
            version: AppVersion.normalized(response.tagName),
            pageURL: response.pageURL
        )
    }
}

private extension GitHubReleaseClient {
    struct ReleaseResponse: Decodable {
        let tagName: String
        let pageURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case pageURL = "html_url"
        }
    }
}
