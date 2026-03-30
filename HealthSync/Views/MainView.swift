import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("HealthSync")
                    .font(.title2.weight(.semibold))
                Text("Skeleton build — HealthKit and WebDAV sync are not wired yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                NavigationLink("Settings") {
                    SettingsView()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Today")
        }
    }
}

#Preview {
    MainView()
}
