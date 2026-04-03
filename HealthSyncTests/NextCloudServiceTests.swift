import XCTest
@testable import HealthSync

final class NextCloudServiceTests: XCTestCase {
    func testValidateConfigurationSendsPropfindWithAuth() async throws {
        let client = HTTPClientMock()
        let store = CredentialsStoreMock(credentials: .init(username: "u", password: "p"))
        let sut = NextCloudService(
            credentialsStore: store,
            httpClient: client,
            sleeper: SleeperMock(),
            configurationProvider: {
                .init(baseURL: URL(string: "https://cloud.example.com")!, webDAVRoot: "remote.php/dav/files")
            }
        )

        try await sut.validateConfiguration()

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.httpMethod, "PROPFIND")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Depth"), "0")
        XCTAssertEqual(request.url?.absoluteString, "https://cloud.example.com/remote.php/dav/files/")
        XCTAssertTrue((request.value(forHTTPHeaderField: "Authorization") ?? "").hasPrefix("Basic "))
    }

    func testUploadRetriesOnServerError() async throws {
        let client = HTTPClientMock(statusCodes: [500, 502, 201])
        let sleeper = SleeperMock()
        let sut = NextCloudService(
            credentialsStore: CredentialsStoreMock(credentials: .init(username: "u", password: "p")),
            httpClient: client,
            sleeper: sleeper,
            configurationProvider: {
                .init(baseURL: URL(string: "https://cloud.example.com")!, webDAVRoot: "remote.php/dav/files")
            }
        )

        try await sut.upload(data: Data("{}".utf8), remotePath: "HealthData/daily/2026-03-31.json", contentType: "application/json")

        XCTAssertEqual(client.requests.count, 3)
        XCTAssertEqual(sleeper.calls, 2)
        XCTAssertEqual(client.requests.first?.httpMethod, "PUT")
    }

    func testDownloadReturnsNilFor404() async throws {
        let client = HTTPClientMock(getStatusCode: 404, getData: Data())
        let sut = NextCloudService(
            credentialsStore: CredentialsStoreMock(credentials: .init(username: "u", password: "p")),
            httpClient: client,
            sleeper: SleeperMock(),
            configurationProvider: {
                .init(baseURL: URL(string: "https://cloud.example.com")!, webDAVRoot: "remote.php/dav/files")
            }
        )

        let data = try await sut.download(remotePath: "HealthData/sync_state.json")
        XCTAssertNil(data)
        XCTAssertEqual(client.requests.last?.httpMethod, "GET")
    }

    func testDownloadReturnsBodyFor200() async throws {
        let payload = Data("{\"x\":1}".utf8)
        let client = HTTPClientMock(getStatusCode: 200, getData: payload)
        let sut = NextCloudService(
            credentialsStore: CredentialsStoreMock(credentials: .init(username: "u", password: "p")),
            httpClient: client,
            sleeper: SleeperMock(),
            configurationProvider: {
                .init(baseURL: URL(string: "https://cloud.example.com")!, webDAVRoot: "remote.php/dav/files")
            }
        )

        let data = try await sut.download(remotePath: "HealthData/sync_state.json")
        XCTAssertEqual(data, payload)
    }

    func testSaveAndLoadCredentialsUsesStore() throws {
        let store = CredentialsStoreMock()
        let sut = NextCloudService(
            credentialsStore: store,
            httpClient: HTTPClientMock(),
            sleeper: SleeperMock(),
            configurationProvider: { nil }
        )
        try sut.saveCredentials(username: "user", password: "secret")

        let loaded = try sut.loadCredentials()
        XCTAssertEqual(loaded, NextCloudCredentials(username: "user", password: "secret"))
    }
}

private final class CredentialsStoreMock: CredentialsStoreProtocol {
    private(set) var stored: NextCloudCredentials?

    init(credentials: NextCloudCredentials? = nil) {
        self.stored = credentials
    }

    func save(credentials: NextCloudCredentials, service: String, account: String) throws {
        stored = credentials
    }

    func load(service: String, account: String) throws -> NextCloudCredentials? {
        stored
    }
}

private final class HTTPClientMock: WebDAVHTTPClientProtocol {
    private(set) var requests: [URLRequest] = []
    private var statusCodes: [Int]
    private var getStatusCode: Int?
    private var getData: Data

    init(statusCodes: [Int] = [207], getStatusCode: Int? = nil, getData: Data = Data()) {
        self.statusCodes = statusCodes
        self.getStatusCode = getStatusCode
        self.getData = getData
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if request.httpMethod == "GET", let code = getStatusCode {
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (getData, response)
        }
        let code = statusCodes.isEmpty ? 207 : statusCodes.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}

private final class SleeperMock: SleepProtocol {
    private(set) var calls = 0
    func sleep(nanoseconds: UInt64) async {
        calls += 1
    }
}
