import Foundation

/// Background `URLSession` for sequential WebDAV PUTs (daily JSON → sync_state) while the app may be suspended.
final class BackgroundWebDAVSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let sessionIdentifier = "com.example.HealthSync.background"
    static let shared = BackgroundWebDAVSession()

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }()

    private let lock = NSLock()
    private var pendingSessionCompletionHandler: (() -> Void)?
    private var activeChain: ChainState?

    private final class ChainState {
        let items: [(url: URL, body: Data, contentType: String)]
        let authorizationHeader: String
        let completion: (Result<Void, Error>) -> Void

        init(
            items: [(url: URL, body: Data, contentType: String)],
            authorizationHeader: String,
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
            self.items = items
            self.authorizationHeader = authorizationHeader
            self.completion = completion
        }
    }

    private override init() {
        super.init()
    }

    func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
        lock.lock()
        pendingSessionCompletionHandler = completionHandler
        lock.unlock()
    }

    /// Enqueues uploads in order. Only one chain may run at a time.
    func enqueueSequentialPUTs(
        authorizationHeader: String,
        items: [(url: URL, body: Data, contentType: String)],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lock.lock()
        if activeChain != nil {
            lock.unlock()
            completion(.failure(NextCloudServiceError.backgroundUploadAlreadyInProgress))
            return
        }
        if items.isEmpty {
            lock.unlock()
            completion(.success(()))
            return
        }
        let chain = ChainState(items: items, authorizationHeader: authorizationHeader, completion: completion)
        activeChain = chain
        lock.unlock()
        startUpload(at: 0, chain: chain)
    }

    private func startUpload(at index: Int, chain: ChainState) {
        guard index < chain.items.count else { return }
        let item = chain.items[index]

        var request = URLRequest(url: item.url)
        request.httpMethod = "PUT"
        request.setValue(item.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(chain.authorizationHeader, forHTTPHeaderField: "Authorization")

        let task = urlSession.uploadTask(with: request, from: item.body)
        task.taskDescription = String(index)
        task.resume()
    }

    private func finishChain(_ chain: ChainState, result: Result<Void, Error>) {
        lock.lock()
        if activeChain === chain {
            activeChain = nil
        }
        lock.unlock()
        chain.completion(result)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard let chain = activeChain else {
            lock.unlock()
            return
        }
        lock.unlock()

        if let error {
            finishChain(chain, result: .failure(error))
            return
        }

        guard let http = task.response as? HTTPURLResponse else {
            finishChain(chain, result: .failure(NextCloudServiceError.invalidHTTPResponse))
            return
        }

        let ok = (200...299).contains(http.statusCode) || http.statusCode == 201 || http.statusCode == 204
        if !ok {
            finishChain(chain, result: .failure(NextCloudServiceError.server(statusCode: http.statusCode)))
            return
        }

        guard let rawIndex = task.taskDescription, let index = Int(rawIndex) else {
            finishChain(chain, result: .failure(NextCloudServiceError.invalidHTTPResponse))
            return
        }

        let next = index + 1
        if next >= chain.items.count {
            finishChain(chain, result: .success(()))
            return
        }

        startUpload(at: next, chain: chain)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = pendingSessionCompletionHandler
        pendingSessionCompletionHandler = nil
        lock.unlock()
        DispatchQueue.main.async {
            handler?()
        }
    }
}
