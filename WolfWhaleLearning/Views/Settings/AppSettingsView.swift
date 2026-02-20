import SwiftUI

struct AppSettingsView: View {
    @Bindable var viewModel: AppViewModel

    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("pushNotificationsEnabled") private var pushNotifications: Bool = true
    @AppStorage("emailNotificationsEnabled") private var emailNotifications: Bool = true

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showSignOutConfirmation = false

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
                Toggle("", isOn: $isDarkMode)
                    .labelsHidden()
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
                Toggle("", isOn: $pushNotifications)
                    .labelsHidden()
            }

            HStack {
                Label {
                    Text("Email Notifications")
                } icon: {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Toggle("", isOn: $emailNotifications)
                    .labelsHidden()
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
        } header: {
            sectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill")
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
