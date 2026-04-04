import SwiftUI

struct MainView: View {
    private let syncService: SyncServiceProtocol
    private let healthKit: HealthKitServiceProtocol
    @State private var isSyncing = false
    @State private var isBackgroundSyncing = false
    @State private var lastSyncMessage: String?
    @State private var syncError: String?
    @State private var todayData: DailyHealthData?
    @State private var previewError: String?
    @State private var isPreviewLoading = false

    init(syncService: SyncServiceProtocol = SyncService(), healthKit: HealthKitServiceProtocol = HealthKitService()) {
        self.syncService = syncService
        self.healthKit = healthKit
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if healthKit.isHealthDataAvailable {
                    if isPreviewLoading {
                        ProgressView("Loading today…")
                            .frame(maxWidth: .infinity)
                    } else if let todayData {
                        TodayPreviewSection(data: todayData)
                            .padding(.horizontal)
                    }
                    if let previewError {
                        Text(previewError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                if let last = SyncRunStore.lastSuccessfulSyncAt {
                    Text("Last successful sync: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("Export today’s daily snapshot to Nextcloud (HealthData/) when configured in Settings.")
                    .font(.subheadline)
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
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
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
            .navigationTitle("HealthSync")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshTodayPreview()
            }
        }
    }

    @MainActor
    private func refreshTodayPreview() async {
        previewError = nil
        guard healthKit.isHealthDataAvailable else {
            todayData = nil
            return
        }
        isPreviewLoading = true
        defer { isPreviewLoading = false }
        do {
            let input = try await healthKit.dailyAggregationInput(for: Date())
            todayData = healthKit.makeDailyHealthData(from: input)
        } catch {
            todayData = nil
            previewError = "Could not load today’s metrics."
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
            await refreshTodayPreview()
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
                        await refreshTodayPreview()
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
