import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    var notificationService: NotificationService

    @AppStorage("notificationsAssignmentReminders") private var assignmentReminders = true
    @AppStorage("notificationsMessageAlerts") private var messageAlerts = true
    @AppStorage("notificationsGradeNotifications") private var gradeNotifications = true
    @AppStorage("notificationsAnnouncementAlerts") private var announcementAlerts = true

    @State private var systemPermission: UNAuthorizationStatus = .notDetermined
    @State private var pendingCount = 0
    @State private var hapticTrigger = false

    var body: some View {
        List {
            permissionStatusSection
            togglesSection
            pendingSection
            previewSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await refreshStatus()
        }
    }

    // MARK: - Permission Status

    private var permissionStatusSection: some View {
        Section {
            HStack {
                Label {
                    Text("System Permission")
                } icon: {
                    Image(systemName: permissionIcon)
                        .foregroundStyle(permissionColor)
                }
                Spacer()
                Text(permissionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if systemPermission == .denied {
                Button {
                    hapticTrigger.toggle()
                    openAppSettings()
                } label: {
                    Label {
                        Text("Open Settings")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "gear")
                            .foregroundStyle(.blue)
                    }
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            if systemPermission == .notDetermined {
                Button {
                    hapticTrigger.toggle()
                    Task {
                        await notificationService.requestAuthorization()
                        await refreshStatus()
                    }
                } label: {
                    Label {
                        Text("Enable Notifications")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.blue)
                    }
                }
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
        } header: {
            sectionHeader(title: "Status", icon: "checkmark.shield.fill")
        } footer: {
            if systemPermission == .denied {
                Text("Notifications are disabled at the system level. Tap \"Open Settings\" to enable them in iOS Settings.")
            }
        }
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        Section {
            toggleRow(
                title: "Assignment Reminders",
                subtitle: "24h and 1h before due dates",
                icon: "doc.text.fill",
                color: .orange,
                isOn: $assignmentReminders
            )

            toggleRow(
                title: "Message Alerts",
                subtitle: "New messages in conversations",
                icon: "message.fill",
                color: .blue,
                isOn: $messageAlerts
            )

            toggleRow(
                title: "Grade Notifications",
                subtitle: "When grades are posted",
                icon: "graduationcap.fill",
                color: .green,
                isOn: $gradeNotifications
            )

            toggleRow(
                title: "Announcements",
                subtitle: "School-wide announcements",
                icon: "megaphone.fill",
                color: .purple,
                isOn: $announcementAlerts
            )
        } header: {
            sectionHeader(title: "Notification Types", icon: "bell.fill")
        } footer: {
            Text("Choose which types of notifications you want to receive.")
        }
    }

    // MARK: - Pending Notifications

    private var pendingSection: some View {
        Section {
            HStack {
                Label {
                    Text("Scheduled Notifications")
                } icon: {
                    Image(systemName: "clock.badge")
                        .foregroundStyle(.purple)
                }
                Spacer()
                Text("\(pendingCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if pendingCount > 0 {
                Button(role: .destructive) {
                    hapticTrigger.toggle()
                    notificationService.cancelAllNotifications()
                    pendingCount = 0
                } label: {
                    Label("Clear All Scheduled", systemImage: "trash")
                }
                .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            }
        } header: {
            sectionHeader(title: "Scheduled", icon: "calendar.badge.clock")
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                notificationPreview(
                    icon: "doc.text.fill",
                    color: .orange,
                    title: "Assignment Due Tomorrow",
                    body: "\"Chapter 5 Report\" for Biology 101 is due tomorrow."
                )

                Divider()

                notificationPreview(
                    icon: "message.fill",
                    color: .blue,
                    title: "New Message from Ms. Smith",
                    body: "Great work on the project!"
                )

                Divider()

                notificationPreview(
                    icon: "graduationcap.fill",
                    color: .green,
                    title: "Grade Posted",
                    body: "You received 92% on \"Midterm Exam\"."
                )

                Divider()

                notificationPreview(
                    icon: "megaphone.fill",
                    color: .purple,
                    title: "School Closure",
                    body: "Due to weather, all classes are cancelled tomorrow."
                )
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(title: "Preview", icon: "eye.fill")
        } footer: {
            Text("Examples of what notifications will look like.")
        }
    }

    // MARK: - Subviews

    private func toggleRow(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .hapticFeedback(.selection, trigger: isOn.wrappedValue)
        }
    }

    private func notificationPreview(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("WolfWhale LMS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(title)
                    .font(.subheadline.bold())
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
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

    // MARK: - Helpers

    private var permissionIcon: String {
        switch systemPermission {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        @unknown default: return "questionmark.circle.fill"
        }
    }

    private var permissionColor: Color {
        switch systemPermission {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }

    private var permissionLabel: String {
        switch systemPermission {
        case .authorized: return "Allowed"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemPermission = settings.authorizationStatus

        await notificationService.refreshPendingNotifications()
        pendingCount = notificationService.pendingNotifications.count
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
