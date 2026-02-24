import SwiftUI

struct TeacherProfileView: View {
    let viewModel: AppViewModel
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsSection
                    settingsSection
                    aboutSection
                    logoutButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background { HolographicBackground() }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AppSettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Double tap to open settings")
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            Text(viewModel.currentUser?.fullName ?? "Teacher")
                .font(.title2.bold())
            Text(viewModel.currentUser?.email ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 20)
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("\(viewModel.courses.count)")
                    .font(.title2.bold())
                Text("Courses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Courses: \(viewModel.courses.count)")

            VStack(spacing: 6) {
                Text("\(viewModel.courses.reduce(0) { $0 + $1.enrolledStudentCount })")
                    .font(.title2.bold())
                Text("Students")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Students: \(viewModel.courses.reduce(0) { $0 + $1.enrolledStudentCount })")
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: colorSchemePreference == "dark" ? "moon.fill" : colorSchemePreference == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                    .foregroundStyle(colorSchemePreference == "dark" ? .indigo : colorSchemePreference == "light" ? .orange : .gray)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text("Appearance")
                    .font(.subheadline)
                Spacer()
                Picker("Appearance", selection: $colorSchemePreference) {
                    Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light", systemImage: "sun.max.fill").tag("light")
                    Label("Dark", systemImage: "moon.fill").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
                .accessibilityLabel("Appearance mode")
                .accessibilityHint("Select system, light, or dark mode")
            }
            .padding(14)
            Divider().padding(.leading, 48)
            NavigationLink {
                NotificationSettingsView(notificationService: viewModel.notificationService)
            } label: {
                settingRow(icon: "bell.fill", title: "Notifications", color: .red)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 48)
            settingRow(icon: "lock.fill", title: "Privacy", color: .blue)
            Divider().padding(.leading, 48)
            settingRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .green)
        }
        .glassCard(cornerRadius: 16)
    }

    private func settingRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }

    private var aboutSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text("About")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                Image(systemName: "w.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("WolfWhale LMS")
                    .font(.headline)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Version")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("1.0.0")
                            .font(.caption.monospaced())
                    }
                    VStack(spacing: 2) {
                        Text("Build")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("2026.2.20")
                            .font(.caption.monospaced())
                    }
                }

                Text("\u{00A9} 2024 WolfWhale. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            hapticTrigger.toggle()
            viewModel.logout()
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
    }
}
