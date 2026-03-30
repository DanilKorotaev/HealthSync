import SwiftUI

struct MainView: View {
    private let syncService: SyncServiceProtocol
    @State private var isSyncing = false
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
                .disabled(isSyncing)
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
}

#Preview {
    MainView()
}
