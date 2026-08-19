import Foundation

struct AppRelease: Equatable, Identifiable {
    let version: String
    let pageURL: URL

    var id: URL { pageURL }
}
