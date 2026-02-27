import SwiftUI
import Supabase

struct AppSettingsView: View {
    @Bindable var viewModel: AppViewModel

    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("pushNotificationsEnabled") private var pushNotifications: Bool = true
    @AppStorage("emailNotificationsEnabled") private var emailNotifications: Bool = true

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showDataPrivacyInfo = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var hapticTrigger = false
    @State private var signOutHapticTrigger = false
    @State private var deleteHapticTrigger = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2026.2.20"
    }

    // MARK: - Body

    var body: some View {
        List {
            accountSection
            securitySection
            appearanceSection
            notificationsSection
            dataAndStorageSection
            legalSection
            aboutSection
            dangerZoneSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showDataPrivacyInfo) {
            DataPrivacyInfoView()
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                viewModel.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out of your account?")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showFinalDeleteConfirmation = true
            }
        } message: {
            Text("This will permanently delete your account, all your data, grades, submissions, and messages. This action cannot be undone.")
        }
        .alert("Type DELETE to confirm", isPresented: $showFinalDeleteConfirmation) {
            TextField("Type DELETE", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Forever", role: .destructive) {
                if deleteConfirmationText == "DELETE" {
                    Task { await deleteAccount() }
                }
                deleteConfirmationText = ""
            }
        } message: {
            Text("This is your final warning. Type DELETE to permanently remove your account.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text("Deleting account...")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Please wait while we remove your data.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
                }
                .transition(.opacity)
                .animation(.smooth, value: isDeletingAccount)
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            NavigationLink {
                EditProfileView(viewModel: viewModel)
            } label: {
                Label {
                    Text("Edit Profile")
                } icon: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            NavigationLink {
                ChangePasswordView(viewModel: viewModel)
            } label: {
                Label {
                    Text("Change Password")
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Account", icon: "person.circle.fill")
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section {
            if viewModel.biometricService.isBiometricAvailable {
                HStack {
                    Label {
                        Text("Use \(viewModel.biometricService.biometricName)")
                    } icon: {
                        Image(systemName: viewModel.biometricService.biometricSystemImage)
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)
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
                    .accessibilityLabel("Use \(viewModel.biometricService.biometricName)")
                    .accessibilityHint("Double tap to toggle biometric authentication")
                }
            } else {
                Label {
                    Text("Biometric authentication is not available on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Security", icon: "lock.shield.fill")
        } footer: {
            if viewModel.biometricService.isBiometricAvailable {
                Text("When enabled, \(viewModel.biometricService.biometricName) will be required to unlock the app after returning from the background.")
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceIcon: String {
        switch colorSchemePreference {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private var appearanceIconColor: Color {
        switch colorSchemePreference {
        case "light": return .orange
        case "dark": return .indigo
        default: return .gray
        }
    }

    private var appearanceSection: some View {
        Section {
            HStack {
                Label {
                    Text("Appearance")
                } icon: {
                    Image(systemName: appearanceIcon)
                        .foregroundStyle(appearanceIconColor)
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))
                }
                Spacer()
                Picker("Appearance", selection: $colorSchemePreference) {
                    Label("System", systemImage: "circle.lefthalf.filled")
                        .tag("system")
                    Label("Light", systemImage: "sun.max.fill")
                        .tag("light")
                    Label("Dark", systemImage: "moon.fill")
                        .tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                .sensoryFeedback(.selection, trigger: colorSchemePreference)
                .accessibilityLabel("Appearance mode")
                .accessibilityHint("Select system, light, or dark mode")
            }
        } header: {
            sectionHeader(title: "Appearance", icon: "paintbrush.fill")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            HStack {
                Label {
                    Text("Push Notifications")
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.red)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Toggle("Push Notifications", isOn: $pushNotifications)
                    .labelsHidden()
                    .sensoryFeedback(.selection, trigger: pushNotifications)
                    .accessibilityLabel("Push Notifications")
                    .accessibilityHint("Double tap to toggle push notifications")
            }

            HStack {
                Label {
                    Text("Email Notifications")
                } icon: {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Toggle("Email Notifications", isOn: $emailNotifications)
                    .labelsHidden()
                    .sensoryFeedback(.selection, trigger: emailNotifications)
                    .accessibilityLabel("Email Notifications")
                    .accessibilityHint("Double tap to toggle email notifications")
            }

            NavigationLink {
                NotificationSettingsView(notificationService: viewModel.notificationService)
            } label: {
                Label {
                    Text("Notification Preferences")
                } icon: {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .foregroundStyle(.purple)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Notifications", icon: "bell.fill")
        }
    }

    // MARK: - Data & Storage Section

    private var dataAndStorageSection: some View {
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
                if viewModel.isSyncingOffline {
                    ProgressView()
                        .controlSize(.small)
                }
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

            NavigationLink {
                OfflineSyncView(viewModel: viewModel)
            } label: {
                Label {
                    Text("Offline & Sync Settings")
                } icon: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.cyan)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            NavigationLink {
                CalendarSyncView(viewModel: viewModel)
            } label: {
                Label {
                    Text("Calendar Sync")
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.purple)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            NavigationLink {
                DataExportView(viewModel: viewModel)
            } label: {
                Label {
                    Text("Download My Data")
                } icon: {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Data & Storage", icon: "externaldrive.fill")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            Button {
                hapticTrigger.toggle()
                showTerms = true
            } label: {
                Label {
                    HStack {
                        Text("Terms of Service")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.purple)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            Button {
                hapticTrigger.toggle()
                showPrivacy = true
            } label: {
                Label {
                    HStack {
                        Text("Privacy Policy")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.teal)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            Button {
                hapticTrigger.toggle()
                showDataPrivacyInfo = true
            } label: {
                Label {
                    HStack {
                        Text("Your Data & Privacy")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fingers.spread.fill")
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Legal", icon: "scale.3d")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Label {
                    Text("Version")
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label {
                    Text("Build")
                } icon: {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Text(buildNumber)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    Text("WolfWhale LMS")
                        .font(.caption.bold())
                    Text("\u{00A9} 2025 WolfWhale. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            sectionHeader(title: "About", icon: "info.circle")
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        Section {
            Button {
                signOutHapticTrigger.toggle()
                showSignOutConfirmation = true
            } label: {
                Label {
                    Text("Sign Out")
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .foregroundStyle(.red)
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: signOutHapticTrigger)

            if viewModel.currentUser?.role != .admin && viewModel.currentUser?.role != .superAdmin {
                Button(role: .destructive) {
                    deleteHapticTrigger.toggle()
                    showDeleteConfirmation = true
                } label: {
                    Label {
                        Text("Delete Account")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: deleteHapticTrigger)
            }
        } header: {
            sectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill")
        } footer: {
            Text("Permanently deletes your account and all associated data. This cannot be undone.")
        }
    }

    // MARK: - Delete Account

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            guard let userId = viewModel.currentUser?.id else { return }
            try await supabaseClient
                .rpc("delete_user_complete", params: ["target_user_id": userId.uuidString])
                .execute()
            try? await supabaseClient.auth.signOut()
            await MainActor.run {
                isDeletingAccount = false
                viewModel.logout()
            }
        } catch {
            // If RPC fails (e.g. non-admin), fall back to signing out.
            // The user can contact their admin for full deletion.
            try? await supabaseClient.auth.signOut()
            await MainActor.run {
                isDeletingAccount = false
                viewModel.logout()
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .symbolRenderingMode(.hierarchical)
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(title)
    }
}
