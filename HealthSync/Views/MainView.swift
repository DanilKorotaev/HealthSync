import SwiftUI

struct MainView: View {
    private let syncService: SyncServiceProtocol
    @State private var isSyncing = false
    @State private var isBackgroundSyncing = false
    @State private var lastSyncMessage: String?
    @State private var syncError: String?

    init(syncService: SyncServiceProtocol = SyncService()) {
        self.syncService = syncService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("HealthSync")
                    .font(.title2.weight(.semibold))
                Text("Export today’s daily snapshot to Nextcloud (HealthData/) when configured in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button(isSyncing ? "Syncing…" : "Sync now") {
                    Task { await runSync() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSyncing || isBackgroundSyncing)
                Button(isBackgroundSyncing ? "Background sync…" : "Sync (background)") {
                    Task { await runBackgroundSync() }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing || isBackgroundSyncing)
                Text("Background mode uses URLSession background transfers; uploads can finish while the app is not in the foreground.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let lastSyncMessage {
                    Text(lastSyncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let syncError {
                    Text(syncError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                NavigationLink("Settings") {
                    SettingsView()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Today")
        }
    }

    @MainActor
    private func runSync() async {
        isSyncing = true
        lastSyncMessage = nil
        syncError = nil
        defer { isSyncing = false }
        do {
            try await syncService.syncNow()
            lastSyncMessage = "Sync finished."
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    private func runBackgroundSync() async {
        isBackgroundSyncing = true
        lastSyncMessage = nil
        syncError = nil
        defer { isBackgroundSyncing = false }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            syncService.syncNowUsingBackgroundUploads { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        lastSyncMessage = "Background uploads finished."
                    case let .failure(error):
                        syncError = error.localizedDescription
                    }
                    continuation.resume()
                }
            }
        }
    }
}

#Preview {
    MainView()
}
