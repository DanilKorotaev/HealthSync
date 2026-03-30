import SwiftUI

struct SettingsView: View {
    @State private var baseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudBaseURL) ?? ""
    @State private var webDAVRoot: String = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudWebDAVRoot) ?? "remote.php/dav/files"
    @State private var webhookURL: String = AppConfiguration.string(for: AppConfiguration.Keys.syncWebhookURL) ?? ""
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
            Section("Connection") {
                TextField("Nextcloud base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("WebDAV root", text: $webDAVRoot)
                    .textInputAutocapitalization(.never)
                TextField("Sync webhook URL (optional)", text: $webhookURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
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
