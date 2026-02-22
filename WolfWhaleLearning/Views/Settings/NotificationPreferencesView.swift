import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {

    // MARK: - Dependencies

    var reminderService: ReminderSchedulingService

    // MARK: - State

    @State private var prefs = NotificationPreferences.load()
    @State private var pendingCount = 0
    @State private var systemPermission: UNAuthorizationStatus = .notDetermined
    @State private var showTestConfirmation = false
    @State private var hapticTrigger = false

    // MARK: - Body

    var body: some View {
        List {
            systemStatusSection
            assignmentRemindersSection
            reminderTimingSection
            otherNotificationsSection
            scheduledSection
            testSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.large)
        .task { await refreshStatus() }
        .onChange(of: prefs.assignmentReminders) { _, _ in prefs.save() }
        .onChange(of: prefs.gradeNotifications) { _, _ in prefs.save() }
        .onChange(of: prefs.messageNotifications) { _, _ in prefs.save() }
        .onChange(of: prefs.announcementNotifications) { _, _ in prefs.save() }
        .onChange(of: prefs.reminderTiming) { _, _ in prefs.save() }
    }

    // MARK: - System Status

    private var systemStatusSection: some View {
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
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        } header: {
            sectionHeader(title: "Status", icon: "checkmark.shield.fill")
        } footer: {
            if systemPermission == .denied {
                Text("Notifications are disabled at the system level. Tap \"Open Settings\" to enable them.")
            }
        }
    }

    // MARK: - Assignment Reminders Toggle

    private var assignmentRemindersSection: some View {
        Section {
            toggleRow(
                title: "Assignment Reminders",
                subtitle: "Get reminded before assignments are due",
                icon: "doc.text.fill",
                color: .orange,
                isOn: $prefs.assignmentReminders
            )
        } header: {
            sectionHeader(title: "Assignments", icon: "doc.text.fill")
        } footer: {
            Text("When enabled, local reminders are scheduled for upcoming assignments based on your timing preferences below.")
        }
    }

    // MARK: - Reminder Timing Multi-Select

    private var reminderTimingSection: some View {
        Section {
            ForEach(NotificationPreferences.ReminderTiming.allCases, id: \.self) { timing in
                Button {
                    hapticTrigger.toggle()
                    toggleTiming(timing)
                } label: {
                    HStack {
                        Label {
                            Text(timing.displayName)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: timingIcon(for: timing))
                                .foregroundStyle(prefs.reminderTiming.contains(timing) ? .indigo : .secondary)
                        }
                        Spacer()
                        if prefs.reminderTiming.contains(timing) {
                            Image(systemName: "checkmark")
                                .font(.subheadline.bold())
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: hapticTrigger)
            }
        } header: {
            sectionHeader(title: "Reminder Timing", icon: "clock.fill")
        } footer: {
            Text("Select when you want to be reminded before an assignment is due. You can choose multiple options.")
        }
        .disabled(!prefs.assignmentReminders)
        .opacity(prefs.assignmentReminders ? 1.0 : 0.5)
    }

    // MARK: - Other Notification Toggles

    private var otherNotificationsSection: some View {
        Section {
            toggleRow(
                title: "Grade Notifications",
                subtitle: "When grades are posted",
                icon: "graduationcap.fill",
                color: .green,
                isOn: $prefs.gradeNotifications
            )

            toggleRow(
                title: "Message Notifications",
                subtitle: "New messages in conversations",
                icon: "message.fill",
                color: .blue,
                isOn: $prefs.messageNotifications
            )

            toggleRow(
                title: "Announcement Notifications",
                subtitle: "School-wide announcements",
                icon: "megaphone.fill",
                color: .purple,
                isOn: $prefs.announcementNotifications
            )
        } header: {
            sectionHeader(title: "Other Notifications", icon: "bell.fill")
        }
    }

    // MARK: - Scheduled / Pending

    private var scheduledSection: some View {
        Section {
            HStack {
                Label {
                    Text("Pending Reminders")
                } icon: {
                    Image(systemName: "clock.badge")
                        .foregroundStyle(.purple)
                }
                Spacer()
                Text("\(pendingCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if pendingCount > 0 {
                Button(role: .destructive) {
                    hapticTrigger.toggle()
                    Task {
                        await reminderService.cancelAllAssignmentReminders()
                        await refreshPendingCount()
                    }
                } label: {
                    Label("Clear Assignment Reminders", systemImage: "trash")
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            }

            Button {
                hapticTrigger.toggle()
                Task { await refreshPendingCount() }
            } label: {
                Label {
                    Text("Refresh Count")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.indigo)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        } header: {
            sectionHeader(title: "Scheduled", icon: "calendar.badge.clock")
        }
    }

    // MARK: - Test Notification

    private var testSection: some View {
        Section {
            Button {
                hapticTrigger.toggle()
                sendTestNotification()
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Test Notification")
                                .foregroundStyle(.primary)
                            Text("Delivers in 5 seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Spacer()
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .overlay {
                if showTestConfirmation {
                    HStack {
                        Spacer()
                        Text("Scheduled!")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.indigo, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.trailing, 4)
                }
            }
        } header: {
            sectionHeader(title: "Test", icon: "flask.fill")
        } footer: {
            Text("Send a test notification to verify that notifications are working correctly on this device.")
        }
    }

    // MARK: - Subviews

    private func toggleRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
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
                .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
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

    private func toggleTiming(_ timing: NotificationPreferences.ReminderTiming) {
        if prefs.reminderTiming.contains(timing) {
            // Don't allow removing the last timing
            if prefs.reminderTiming.count > 1 {
                prefs.reminderTiming.remove(timing)
            }
        } else {
            prefs.reminderTiming.insert(timing)
        }
    }

    private func timingIcon(for timing: NotificationPreferences.ReminderTiming) -> String {
        switch timing {
        case .twentyFourHours: return "clock.fill"
        case .twelveHours:     return "clock.badge.checkmark.fill"
        case .sixHours:        return "clock.arrow.circlepath"
        case .oneHour:         return "clock.badge.exclamationmark.fill"
        }
    }

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
        await refreshPendingCount()
    }

    private func refreshPendingCount() async {
        pendingCount = await reminderService.pendingReminderCount()
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "WolfWhale LMS"
        content.body = "This is a test notification. Notifications are working correctly!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showTestConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showTestConfirmation = false }
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
