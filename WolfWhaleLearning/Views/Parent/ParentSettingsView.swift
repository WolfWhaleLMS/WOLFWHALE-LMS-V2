import SwiftUI

struct ParentSettingsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var hapticTrigger = false

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

                if viewModel.biometricService.isBiometricAvailable {
                    Section {
                        HStack {
                            Label {
                                Text("Use \(viewModel.biometricService.biometricName)")
                            } icon: {
                                Image(systemName: viewModel.biometricService.biometricSystemImage)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            Toggle(
                                "Use \(viewModel.biometricService.biometricName)",
                                isOn: Binding(
                                    get: { viewModel.biometricEnabled },
                                    set: { newValue in
                                        if newValue {
                                            viewModel.enableBiometric()
                                        } else {
                                            viewModel.disableBiometric()
                                        }
                                    }
                                )
                            )
                            .labelsHidden()
                            .sensoryFeedback(.selection, trigger: viewModel.biometricEnabled)
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("When enabled, \(viewModel.biometricService.biometricName) will be required to unlock the app after returning from the background.")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        hapticTrigger.toggle()
                        viewModel.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
