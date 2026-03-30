import Foundation

/// WebDAV / Nextcloud uploads (implementation in a later milestone).
protocol NextCloudServiceProtocol {
    func validateConfiguration() async throws
}

final class NextCloudService: NextCloudServiceProtocol {
    init() {}

    func validateConfiguration() async throws {
        // Future: PROPFIND against WebDAV root using credentials from Keychain.
    }
}
