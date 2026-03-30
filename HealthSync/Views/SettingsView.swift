import SwiftUI

struct SettingsView: View {
    @State private var baseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.nextcloudBaseURL) ?? ""
    @State private var webhookURL: String = AppConfiguration.string(for: AppConfiguration.Keys.syncWebhookURL) ?? ""

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Nextcloud base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("Sync webhook URL (optional)", text: $webhookURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            Section {
                Button("Save to this device") {
                    AppConfiguration.setUserString(baseURL.nilIfEmpty, for: AppConfiguration.Keys.nextcloudBaseURL)
                    AppConfiguration.setUserString(webhookURL.nilIfEmpty, for: AppConfiguration.Keys.syncWebhookURL)
                }
            } footer: {
                Text("Credentials belong in Keychain in a future milestone. Values here are stored in UserDefaults for development only.")
            }
        }
        .navigationTitle("Settings")
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
