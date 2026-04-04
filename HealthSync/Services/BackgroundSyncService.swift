import Foundation
import HealthKit

/// Wires HealthKit background observers to a background WebDAV upload chain and optional local notifications.
final class BackgroundSyncCoordinator {
    static let shared = BackgroundSyncCoordinator()

    private let observationState = ObservationStateHolder()

    private let registrar: HealthKitBackgroundObserverRegistrarProtocol
    private let syncService: SyncServiceProtocol
    private let notificationScheduler: LocalNotificationSchedulingProtocol
    private let isHealthDataAvailable: () -> Bool
    private let isBackgroundSyncEnabled: () -> Bool
    private let sampleTypesProvider: () -> [HKSampleType]

    init(
        registrar: HealthKitBackgroundObserverRegistrarProtocol = HealthKitBackgroundObserverRegistrar(store: HealthStoreAdapter.shared),
        syncService: SyncServiceProtocol = SyncService(),
        notificationScheduler: LocalNotificationSchedulingProtocol = LocalNotificationScheduler(),
        isHealthDataAvailable: @escaping () -> Bool = { HealthStoreAdapter.shared.isHealthDataAvailable },
        isBackgroundSyncEnabled: @escaping () -> Bool = { AppConfiguration.backgroundSyncEnabled },
        sampleTypesProvider: @escaping () -> [HKSampleType] = {
            HealthKitService().requiredReadTypes.compactMap { $0 as? HKSampleType }
        }
    ) {
        self.registrar = registrar
        self.syncService = syncService
        self.notificationScheduler = notificationScheduler
        self.isHealthDataAvailable = isHealthDataAvailable
        self.isBackgroundSyncEnabled = isBackgroundSyncEnabled
        self.sampleTypesProvider = sampleTypesProvider
    }

    /// Aligns HealthKit observers with the user setting (call at launch and when the toggle changes).
    func syncWithUserPreference() {
        Task {
            await applyPreference()
        }
    }

    /// @deprecated Use `syncWithUserPreference()` — kept for tests by name.
    func startIfNeeded() {
        syncWithUserPreference()
    }

    private func applyPreference() async {
        guard isHealthDataAvailable() else { return }

        let enabled = isBackgroundSyncEnabled()
        let wasActive = await observationState.isObservationActive()

        if enabled {
            if wasActive { return }
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
                await observationState.setObservationActive(true)
            } catch {
                await self.notificationScheduler.notifySyncFailedIfEnabled(
                    errorDescription: error.localizedDescription
                )
            }
        } else {
            guard wasActive else { return }
            await registrar.stopObserving()
            await observationState.setObservationActive(false)
        }
    }
}

private actor ObservationStateHolder {
    private var observationActive = false

    func isObservationActive() -> Bool {
        observationActive
    }

    func setObservationActive(_ value: Bool) {
        observationActive = value
    }
}
