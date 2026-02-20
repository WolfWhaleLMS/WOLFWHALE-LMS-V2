import SwiftUI
import Supabase

struct AppSettingsView: View {
    @Bindable var viewModel: AppViewModel

    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("pushNotificationsEnabled") private var pushNotifications: Bool = true
    @AppStorage("emailNotificationsEnabled") private var emailNotifications: Bool = true

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2024.1"
    }

    // MARK: - Body

    var body: some View {
        List {
            accountSection
            appearanceSection
            notificationsSection
            legalSection
            aboutSection
            dangerZoneSection
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
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
                        .foregroundStyle(.pink)
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
                }
            }
        } header: {
            sectionHeader(title: "Account", icon: "person.circle.fill")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            HStack {
                Label {
                    Text("Dark Mode")
                } icon: {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(isDarkMode ? .indigo : .orange)
                }
                Spacer()
                Toggle("Dark Mode", isOn: $isDarkMode)
                    .labelsHidden()
                    .accessibilityLabel("Dark Mode")
                    .accessibilityHint("Double tap to toggle dark mode")
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
                }
                Spacer()
                Toggle("Push Notifications", isOn: $pushNotifications)
                    .labelsHidden()
                    .accessibilityLabel("Push Notifications")
                    .accessibilityHint("Double tap to toggle push notifications")
            }

            HStack {
                Label {
                    Text("Email Notifications")
                } icon: {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Toggle("Email Notifications", isOn: $emailNotifications)
                    .labelsHidden()
                    .accessibilityLabel("Email Notifications")
                    .accessibilityHint("Double tap to toggle email notifications")
            }
        } header: {
            sectionHeader(title: "Notifications", icon: "bell.fill")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            Button {
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
                }
            }

            Button {
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
                }
            }
        } header: {
            sectionHeader(title: "Legal", icon: "scale.3d")
        }
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
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text(buildNumber)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "w.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("WolfWhale LMS")
                        .font(.caption.bold())
                    Text("\u{00A9} 2024 WolfWhale. All rights reserved.")
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
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Label {
                    Text("Sign Out")
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label {
                    Text("Delete Account")
                } icon: {
                    Image(systemName: "trash")
                }
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
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
    }
}
