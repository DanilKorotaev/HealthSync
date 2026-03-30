import Foundation

/// WebDAV / Nextcloud uploads (implementation in a later milestone).
final class NextCloudService {
    init() {}

    func validateConfiguration() async throws {
        // Future: PROPFIND against WebDAV root using credentials from Keychain.
    }
}
