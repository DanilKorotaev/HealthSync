import Foundation

struct SyncWebhookPayload: Codable, Equatable {
    var date: String
    var files: [String]
}

protocol SyncWebhookClientProtocol {
    func postSyncCompleteIfConfigured(date: String, files: [String]) async throws
}

final class SyncWebhookClient: SyncWebhookClientProtocol {
    private let urlProvider: () -> URL?
    private let session: URLSession

    init(
        urlProvider: @escaping () -> URL? = { AppConfiguration.url(for: AppConfiguration.Keys.syncWebhookURL) },
        session: URLSession = .shared
    ) {
        self.urlProvider = urlProvider
        self.session = session
    }

    func postSyncCompleteIfConfigured(date: String, files: [String]) async throws {
        guard let url = urlProvider() else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = SyncWebhookPayload(date: date, files: files)
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncServiceError.invalidWebhookResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SyncServiceError.webhookRejected(statusCode: http.statusCode)
        }
    }
}
