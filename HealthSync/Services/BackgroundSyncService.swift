import Foundation
import HealthKit

/// Wires HealthKit background observers to a background WebDAV upload chain and optional local notifications.
final class BackgroundSyncCoordinator {
    static let shared = BackgroundSyncCoordinator()

    private let lock = NSLock()
    private var didStart = false

    private let registrar: HealthKitBackgroundObserverRegistrarProtocol
    private let syncService: SyncServiceProtocol
    private let notificationScheduler: LocalNotificationSchedulingProtocol
    private let isHealthDataAvailable: () -> Bool
    private let sampleTypesProvider: () -> [HKSampleType]

    init(
        registrar: HealthKitBackgroundObserverRegistrarProtocol = HealthKitBackgroundObserverRegistrar(store: HealthStoreAdapter.shared),
        syncService: SyncServiceProtocol = SyncService(),
        notificationScheduler: LocalNotificationSchedulingProtocol = LocalNotificationScheduler(),
        isHealthDataAvailable: @escaping () -> Bool = { HealthStoreAdapter.shared.isHealthDataAvailable },
        sampleTypesProvider: @escaping () -> [HKSampleType] = {
            HealthKitService().requiredReadTypes.compactMap { $0 as? HKSampleType }
        }
    ) {
        self.registrar = registrar
        self.syncService = syncService
        self.notificationScheduler = notificationScheduler
        self.isHealthDataAvailable = isHealthDataAvailable
        self.sampleTypesProvider = sampleTypesProvider
    }

    func startIfNeeded() {
        lock.lock()
        if didStart {
            lock.unlock()
            return
        }
        didStart = true
        lock.unlock()

        Task {
            guard isHealthDataAvailable() else { return }
            let types = sampleTypesProvider()
            do {
                try await registrar.startObserving(sampleTypes: types) { done in
                    self.syncService.syncNowUsingBackgroundUploads { result in
                        Task {
                            switch result {
                            case .success:
                                await self.notificationScheduler.notifySyncCompletedIfEnabled()
                            case let .failure(error):
                                await self.notificationScheduler.notifySyncFailedIfEnabled(
                                    errorDescription: error.localizedDescription
                                )
                            }
                            done()
                        }
                    }
                }
            } catch {
                await self.notificationScheduler.notifySyncFailedIfEnabled(
                    errorDescription: error.localizedDescription
                )
            }
        }
    }
}
