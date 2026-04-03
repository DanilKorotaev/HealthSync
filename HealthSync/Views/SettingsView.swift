import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var baseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudBaseURL) ?? ""
    @State private var webDAVRoot: String = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudWebDAVRoot) ?? "remote.php/dav/files"
    @State private var webhookURL: String = AppConfiguration.string(for: AppConfiguration.Keys.syncWebhookURL) ?? ""
    @State private var webhookToken: String = AppConfiguration.string(for: AppConfiguration.Keys.syncWebhookToken) ?? ""
    @State private var backgroundSyncNotifications = AppConfiguration.backgroundSyncNotificationsEnabled
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var connectionStatus: String?
    @State private var isCheckingConnection = false

    private let nextCloudService: NextCloudServiceProtocol

    init(nextCloudService: NextCloudServiceProtocol = NextCloudService()) {
        self.nextCloudService = nextCloudService
    }

    var body: some View {
        Form {
            Section {
                Toggle("Notify when background sync finishes", isOn: $backgroundSyncNotifications)
                    .onChange(of: backgroundSyncNotifications) { _, newValue in
                        AppConfiguration.setBackgroundSyncNotificationsEnabled(newValue)
                        if newValue {
                            Task { await requestNotificationAuthorizationIfNeeded() }
                        }
                    }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Optional. Requires notification permission when enabled.")
            }
            Section("Connection") {
                TextField("Nextcloud base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("WebDAV root", text: $webDAVRoot)
                    .textInputAutocapitalization(.never)
                TextField("Sync webhook URL (optional)", text: $webhookURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                SecureField("Webhook Bearer token (optional)", text: $webhookToken)
                    .textInputAutocapitalization(.never)
            }
            Section("Credentials") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                SecureField("App password / token", text: $password)
            }
            Section {
                Button("Save to this device") {
                    AppConfiguration.setUserString(baseURL.nilIfEmpty, for: AppConfiguration.Keys.nextcloudBaseURL)
                    AppConfiguration.setUserString(webDAVRoot.nilIfEmpty, for: AppConfiguration.Keys.nextcloudWebDAVRoot)
                    AppConfiguration.setUserString(webhookURL.nilIfEmpty, for: AppConfiguration.Keys.syncWebhookURL)
                    AppConfiguration.setUserString(webhookToken.nilIfEmpty, for: AppConfiguration.Keys.syncWebhookToken)
                    do {
                        try nextCloudService.saveCredentials(username: username, password: password)
                        connectionStatus = "Credentials saved to Keychain."
                    } catch {
                        connectionStatus = "Failed to save credentials: \(error.localizedDescription)"
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(isCheckingConnection ? "Checking..." : "Check Nextcloud connection") {
                    Task { await checkConnection() }
                }
                .disabled(isCheckingConnection)
            } footer: {
                Text("URLs are stored in UserDefaults. Credentials are saved in Keychain.")
            }
            if let connectionStatus {
                Section("Status") {
                    Text(connectionStatus)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func requestNotificationAuthorizationIfNeeded() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    @MainActor
    private func checkConnection() async {
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        do {
            try await nextCloudService.validateConfiguration()
            connectionStatus = "Connection successful."
        } catch {
            connectionStatus = "Connection failed: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
