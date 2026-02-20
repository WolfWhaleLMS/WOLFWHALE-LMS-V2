import SwiftUI

struct ParentSettingsView: View {
    let viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.currentUser?.fullName ?? "")
                                .font(.headline)
                            Text(viewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Preferences") {
                    Label("Notifications", systemImage: "bell.fill")
                    Label("Privacy", systemImage: "lock.fill")
                    Label("Help & Support", systemImage: "questionmark.circle.fill")
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
