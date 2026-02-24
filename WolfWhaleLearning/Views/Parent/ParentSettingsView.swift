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

                Section {
                    HStack {
                        Label {
                            Text("Absence Alerts")
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Toggle(
                            "Absence Alerts",
                            isOn: $viewModel.absenceAlertEnabled
                        )
                        .labelsHidden()
                        .sensoryFeedback(.selection, trigger: viewModel.absenceAlertEnabled)
                    }
                } header: {
                    Text("Alert Preferences")
                } footer: {
                    Text("When enabled, you will receive an immediate notification when your child is marked absent.")
                }

                Section {
                    HStack {
                        Label {
                            Text("Offline Mode")
                        } icon: {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.cyan)
                                .symbolRenderingMode(.hierarchical)
                        }
                        Spacer()
                        Toggle("Offline Mode", isOn: Binding(
                            get: { viewModel.offlineModeEnabled },
                            set: { newValue in
                                if newValue {
                                    Task { await viewModel.syncForOfflineUse() }
                                } else {
                                    viewModel.offlineModeEnabled = false
                                }
                            }
                        ))
                        .labelsHidden()
                        .sensoryFeedback(.selection, trigger: viewModel.offlineModeEnabled)
                    }

                    if viewModel.isSyncingOffline {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Downloading content for offline use...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.offlineModeEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .symbolRenderingMode(.hierarchical)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All content available offline")
                                    .font(.caption.bold())
                                if let lastSync = viewModel.offlineStorage.lastSyncDate {
                                    Text("Last synced \(lastSync, style: .relative) ago")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                Task { await viewModel.syncForOfflineUse() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption.bold())
                                    .foregroundStyle(.cyan)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Sync now")
                        }
                    }
                } header: {
                    Text("Offline Access")
                } footer: {
                    Text("When enabled, all your children's reports and messages are downloaded for offline viewing.")
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
                            .foregroundStyle(.red)
                    }
                    .tint(.red)
                    .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
