import SwiftUI

struct TeacherProfileView: View {
    let viewModel: AppViewModel
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsSection
                    settingsSection
                    logoutButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
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
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
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
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))

            VStack(spacing: 6) {
                Text("\(viewModel.courses.reduce(0) { $0 + $1.enrolledStudentCount })")
                    .font(.title2.bold())
                Text("Students")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(isDarkMode ? .indigo : .orange)
                    .frame(width: 28)
                Text("Dark Mode")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $isDarkMode)
                    .labelsHidden()
            }
            .padding(14)
            Divider().padding(.leading, 48)
            settingRow(icon: "bell.fill", title: "Notifications", color: .red)
            Divider().padding(.leading, 48)
            settingRow(icon: "lock.fill", title: "Privacy", color: .blue)
            Divider().padding(.leading, 48)
            settingRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .green)
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
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

    private var logoutButton: some View {
        Button(role: .destructive) {
            viewModel.logout()
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
    }
}
