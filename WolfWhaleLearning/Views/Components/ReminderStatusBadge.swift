import SwiftUI

/// A compact inline badge showing the number of active assignment reminders.
///
/// Displays a bell icon with a count label. Green when reminders are active,
/// gray when disabled or zero. Tappable to navigate to notification settings.
///
/// Usage:
/// ```swift
/// ReminderStatusBadge(
///     scheduledCount: dueDateReminderService.scheduledCount,
///     remindersEnabled: dueDateReminderService.remindersEnabled,
///     onTap: { showNotificationSettings = true }
/// )
/// ```
struct ReminderStatusBadge: View {

    /// Number of currently scheduled assignment reminders.
    let scheduledCount: Int

    /// Whether assignment reminders are enabled in user preferences.
    let remindersEnabled: Bool

    /// Action invoked when the badge is tapped (e.g., navigate to settings).
    var onTap: (() -> Void)?

    // MARK: - Derived State

    private var isActive: Bool {
        remindersEnabled && scheduledCount > 0
    }

    private var tintColor: Color {
        isActive ? .green : .secondary
    }

    private var iconName: String {
        if !remindersEnabled {
            return "bell.slash.fill"
        }
        return scheduledCount > 0 ? "bell.badge.fill" : "bell.fill"
    }

    private var labelText: String {
        if !remindersEnabled {
            return "Reminders off"
        }
        if scheduledCount == 0 {
            return "No reminders"
        }
        return "\(scheduledCount) reminder\(scheduledCount == 1 ? "" : "s") active"
    }

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(tintColor)

                Text(labelText)
                    .font(.caption)
                    .foregroundStyle(tintColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(tintColor.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(labelText)
        .accessibilityHint(onTap != nil ? "Tap to open notification settings" : "")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Active Reminders") {
    VStack(spacing: 16) {
        ReminderStatusBadge(
            scheduledCount: 5,
            remindersEnabled: true
        )

        ReminderStatusBadge(
            scheduledCount: 1,
            remindersEnabled: true
        )

        ReminderStatusBadge(
            scheduledCount: 0,
            remindersEnabled: true
        )

        ReminderStatusBadge(
            scheduledCount: 0,
            remindersEnabled: false
        )
    }
    .padding()
}
#endif
