import SwiftUI

struct SettingsView: View {
    @Binding var isDeveloperModeEnabled: Bool

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Developer Mode", isOn: $isDeveloperModeEnabled)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
        }
    }
}
