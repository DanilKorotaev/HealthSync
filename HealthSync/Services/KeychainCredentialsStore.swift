import Foundation
import Security

enum KeychainCredentialsStoreError: Error {
    case unexpectedData
    case unhandledStatus(OSStatus)
}

final class KeychainCredentialsStore: CredentialsStoreProtocol {
    func save(credentials: NextCloudCredentials, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        let payload = try JSONEncoder().encode(credentials)
        var attributes = query
        attributes[kSecValueData as String] = payload

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainCredentialsStoreError.unhandledStatus(status)
        }
    }

    func load(service: String, account: String) throws -> NextCloudCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainCredentialsStoreError.unexpectedData
            }
            return try JSONDecoder().decode(NextCloudCredentials.self, from: data)
        default:
            throw KeychainCredentialsStoreError.unhandledStatus(status)
        }
    }
}
