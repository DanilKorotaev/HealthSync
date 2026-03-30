import Foundation

protocol NextCloudServiceProtocol {
    func validateConfiguration() async throws
    func saveCredentials(username: String, password: String) throws
    func loadCredentials() throws -> NextCloudCredentials?
    func upload(data: Data, remotePath: String, contentType: String) async throws
}

struct NextCloudCredentials: Codable, Equatable {
    var username: String
    var password: String
}

struct NextCloudConfiguration: Equatable {
    var baseURL: URL
    var webDAVRoot: String

    var webDAVURL: URL {
        let root = webDAVRoot.hasPrefix("/") ? String(webDAVRoot.dropFirst()) : webDAVRoot
        return baseURL.appending(path: root, directoryHint: .isDirectory)
    }
}

enum NextCloudServiceError: Error, Equatable {
    case missingBaseURL
    case missingCredentials
    case invalidHTTPResponse
    case server(statusCode: Int)
}

protocol CredentialsStoreProtocol {
    func save(credentials: NextCloudCredentials, service: String, account: String) throws
    func load(service: String, account: String) throws -> NextCloudCredentials?
}

protocol WebDAVHTTPClientProtocol {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

protocol SleepProtocol {
    func sleep(nanoseconds: UInt64) async
}

struct TaskSleeper: SleepProtocol {
    func sleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

struct URLSessionWebDAVClient: WebDAVHTTPClientProtocol {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NextCloudServiceError.invalidHTTPResponse
        }
        return (data, http)
    }
}

final class NextCloudService: NextCloudServiceProtocol {
    private static let keychainService = "com.healthsync.nextcloud"
    private static let keychainAccount = "default"

    private let credentialsStore: CredentialsStoreProtocol
    private let httpClient: WebDAVHTTPClientProtocol
    private let sleeper: SleepProtocol
    private let configurationProvider: () -> NextCloudConfiguration?

    init(
        credentialsStore: CredentialsStoreProtocol = KeychainCredentialsStore(),
        httpClient: WebDAVHTTPClientProtocol = URLSessionWebDAVClient(),
        sleeper: SleepProtocol = TaskSleeper(),
        configurationProvider: @escaping () -> NextCloudConfiguration? = {
            guard let baseURL = AppConfiguration.url(for: AppConfiguration.Keys.nextcloudBaseURL) else {
                return nil
            }
            let root = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudWebDAVRoot) ?? "remote.php/dav/files"
            return NextCloudConfiguration(baseURL: baseURL, webDAVRoot: root)
        }
    ) {
        self.credentialsStore = credentialsStore
        self.httpClient = httpClient
        self.sleeper = sleeper
        self.configurationProvider = configurationProvider
    }

    func validateConfiguration() async throws {
        let config = try configuration()
        let credentials = try credentials()
        var request = URLRequest(url: config.webDAVURL)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.basicAuthorizationHeader, forHTTPHeaderField: "Authorization")

        let (_, response) = try await httpClient.send(request)
        guard (200...299).contains(response.statusCode) || response.statusCode == 207 else {
            throw NextCloudServiceError.server(statusCode: response.statusCode)
        }
    }

    func saveCredentials(username: String, password: String) throws {
        let creds = NextCloudCredentials(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        try credentialsStore.save(
            credentials: creds,
            service: Self.keychainService,
            account: Self.keychainAccount
        )
    }

    func loadCredentials() throws -> NextCloudCredentials? {
        try credentialsStore.load(service: Self.keychainService, account: Self.keychainAccount)
    }

    func upload(data: Data, remotePath: String, contentType: String = "application/json") async throws {
        let config = try configuration()
        let credentials = try credentials()
        let cleanedPath = remotePath.hasPrefix("/") ? String(remotePath.dropFirst()) : remotePath
        let destinationURL = config.webDAVURL.appending(path: cleanedPath)

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                var request = URLRequest(url: destinationURL)
                request.httpMethod = "PUT"
                request.httpBody = data
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
                request.setValue(credentials.basicAuthorizationHeader, forHTTPHeaderField: "Authorization")

                let (_, response) = try await httpClient.send(request)
                if (200...299).contains(response.statusCode) || response.statusCode == 201 || response.statusCode == 204 {
                    return
                }
                if response.statusCode >= 500 && attempt < 2 {
                    await sleeper.sleep(nanoseconds: UInt64(300_000_000 * (attempt + 1)))
                    continue
                }
                throw NextCloudServiceError.server(statusCode: response.statusCode)
            } catch {
                lastError = error
                if attempt < 2 {
                    await sleeper.sleep(nanoseconds: UInt64(300_000_000 * (attempt + 1)))
                    continue
                }
            }
        }
        throw lastError ?? NextCloudServiceError.invalidHTTPResponse
    }

    private func configuration() throws -> NextCloudConfiguration {
        guard let config = configurationProvider() else {
            throw NextCloudServiceError.missingBaseURL
        }
        return config
    }

    private func credentials() throws -> NextCloudCredentials {
        guard let credentials = try loadCredentials(),
              !credentials.username.isEmpty,
              !credentials.password.isEmpty
        else {
            throw NextCloudServiceError.missingCredentials
        }
        return credentials
    }
}

private extension NextCloudCredentials {
    var basicAuthorizationHeader: String {
        let combined = "\(username):\(password)"
        let token = Data(combined.utf8).base64EncodedString()
        return "Basic \(token)"
    }
}
