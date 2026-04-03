import Foundation
import HealthKit

protocol HealthKitBackgroundObserverRegistrarProtocol: AnyObject {
    func startObserving(
        sampleTypes: [HKSampleType],
        onUpdates: @escaping (@escaping () -> Void) -> Void
    ) async throws
}

/// Enables HealthKit background delivery and registers `HKObserverQuery` for each sample type. Always calls the query completion handler.
final class HealthKitBackgroundObserverRegistrar: HealthKitBackgroundObserverRegistrarProtocol {
    private let store: HKBackgroundCapableHealthStore
    private var observerQueries: [HKObserverQuery] = []

    init(store: HKBackgroundCapableHealthStore) {
        self.store = store
    }

    func startObserving(
        sampleTypes: [HKSampleType],
        onUpdates: @escaping (@escaping () -> Void) -> Void
    ) async throws {
        for type in sampleTypes {
            try await store.enableBackgroundDelivery(for: type, frequency: .immediate)
        }
        for type in sampleTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if error != nil {
                    completionHandler()
                    return
                }
                onUpdates {
                    completionHandler()
                }
            }
            store.execute(query: query)
            observerQueries.append(query)
        }
    }
}
