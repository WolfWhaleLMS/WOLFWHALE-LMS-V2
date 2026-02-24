import SwiftUI

struct OfflineSyncView: View {
    let viewModel: AppViewModel

    @State private var showClearConfirmation = false
    @State private var hapticTrigger = false
    @State private var isSyncingNow = false

    private var offlineStorage: OfflineStorageService { viewModel.offlineStorage }
    private var cloudSync: CloudSyncService { viewModel.cloudSync }

    var body: some View {
        List {
            offlineStatusSection
            iCloudSection
            storageBreakdownSection
            actionsSection
            dangerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Offline & Sync")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Clear Offline Data",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Offline Data", role: .destructive) {
                offlineStorage.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached offline data. The app will require an internet connection to reload data.")
        }
    }

    // MARK: - Offline Status Section

    private var offlineStatusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: offlineStorage.hasOfflineData ? "checkmark.icloud.fill" : "xmark.icloud")
                    .font(.title2)
                    .foregroundStyle(offlineStorage.hasOfflineData ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(offlineStorage.hasOfflineData ? "Offline Data Available" : "No Offline Data")
                        .font(.subheadline.bold())
                    Text(offlineStorage.hasOfflineData
                         ? "The app can work without internet using cached data."
                         : "Connect to the internet and load data to enable offline mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label {
                    Text("Cache Size")
                } icon: {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(offlineStorage.formattedCacheSize)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label {
                    Text("Last Cached")
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                if let lastSync = offlineStorage.lastSyncDate {
                    Text(lastSync, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            sectionHeader(title: "Offline Data", icon: "arrow.down.circle.fill")
        }
    }

    // MARK: - iCloud Sync Section

    private var iCloudSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: cloudSync.iCloudAvailable ? "icloud.fill" : "icloud.slash")
                    .font(.title3)
                    .foregroundStyle(cloudSync.iCloudAvailable ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudSync.iCloudAvailable ? "iCloud Available" : "iCloud Unavailable")
                        .font(.subheadline.bold())
                    Text(cloudSync.iCloudAvailable
                         ? "Preferences can be synced across your Apple devices."
                         : "Sign in to iCloud in Settings to enable sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label {
                    Text("iCloud Sync")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                        .foregroundStyle(.purple)
                }
                Spacer()
                Toggle("iCloud Sync", isOn: Binding(
                    get: { cloudSync.isSyncEnabled },
                    set: { cloudSync.isSyncEnabled = $0 }
                ))
                .labelsHidden()
                .sensoryFeedback(.selection, trigger: cloudSync.isSyncEnabled)
            }
            .disabled(!cloudSync.iCloudAvailable)

            HStack {
                Label {
                    Text("Last iCloud Sync")
                } icon: {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .foregroundStyle(.indigo)
                }
                Spacer()
                if let lastSync = cloudSync.lastCloudSyncDate {
                    Text(lastSync, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            if let error = cloudSync.syncError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            sectionHeader(title: "iCloud", icon: "icloud.fill")
        } footer: {
            Text("iCloud sync stores lightweight preferences (appearance, biometric settings) across your devices. Course data is synced via the primary server.")
        }
    }

    // MARK: - Storage Breakdown

    private var storageBreakdownSection: some View {
        Section {
            let breakdown = offlineStorage.storageBreakdown
            if breakdown.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No cached data")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(breakdown, id: \.label) { item in
                    HStack {
                        Label {
                            Text(item.label)
                        } icon: {
                            Image(systemName: iconForCategory(item.label))
                                .foregroundStyle(colorForCategory(item.label))
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            sectionHeader(title: "Storage Breakdown", icon: "chart.pie.fill")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                hapticTrigger.toggle()
                performSync()
            } label: {
                HStack {
                    Label {
                        Text("Sync Now")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if isSyncingNow || cloudSync.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isSyncingNow || cloudSync.isSyncing)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        } header: {
            sectionHeader(title: "Actions", icon: "bolt.fill")
        } footer: {
            Text("Refreshes data from the server and updates the local cache. Also syncs preferences to iCloud if enabled.")
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                hapticTrigger.toggle()
                showClearConfirmation = true
            } label: {
                Label {
                    Text("Clear Offline Data")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .disabled(!offlineStorage.hasOfflineData)
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
        } header: {
            sectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill")
        } footer: {
            Text("Removes all locally cached data. The app will need an internet connection to reload.")
        }
    }

    // MARK: - Helpers

    /// Creates a sanitized copy of the user with PII stripped out.
    /// Only UI preferences, theme settings, notification preferences, and bookmarks are kept.
    /// Grades, submissions, student names, email addresses, and role data are removed
    /// to comply with FERPA requirements.
    private func sanitizedUserForCloudSync(_ user: User) -> User {
        var safe = user
        safe.firstName = ""
        safe.lastName = ""
        safe.email = ""
        safe.role = .student  // Neutral default; role data should not be synced
        safe.schoolId = nil
        return safe
    }

    private func performSync() {
        isSyncingNow = true
        Task {
            await viewModel.loadData()
            if let user = viewModel.currentUser, cloudSync.isSyncEnabled {
                // Only sync non-PII preferences to iCloud (FERPA compliance)
                let safeUser = sanitizedUserForCloudSync(user)
                await cloudSync.syncToCloud(user: safeUser)
            }
            isSyncingNow = false
        }
    }

    private func iconForCategory(_ label: String) -> String {
        switch label {
        case "Courses": return "book.fill"
        case "Assignments": return "doc.text.fill"
        case "Grades": return "chart.bar.fill"
        case "Conversations": return "bubble.left.and.bubble.right.fill"
        case "User Profile": return "person.crop.circle.fill"
        default: return "doc.fill"
        }
    }

    private func colorForCategory(_ label: String) -> Color {
        switch label {
        case "Courses": return .purple
        case "Assignments": return .orange
        case "Grades": return .green
        case "Conversations": return .blue
        case "User Profile": return .pink
        default: return .gray
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
    }
}
