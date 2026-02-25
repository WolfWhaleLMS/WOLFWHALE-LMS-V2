import Foundation
import UserNotifications
import Observation

/// Schedules and manages local notification reminders for upcoming
/// assignments. Works alongside ``NotificationService`` (which handles
/// notification delegate callbacks & deep-linking) and
/// ``PushNotificationService`` (which handles remote APNs).
///
/// This service is the single owner of *assignment reminder* scheduling
/// -- callers should prefer it over the older helpers on
/// ``PushNotificationService``.
@MainActor
@Observable
final class ReminderSchedulingService {

    // MARK: - Published State

    var error: String?
    var isLoading = false

    // MARK: - Constants

    /// Prefix used for all assignment reminder notification identifiers so
    /// they can be bulk-removed without touching other local notifications.
    private static let assignmentReminderPrefix = "assignment-reminder-"

    /// Maximum number of assignments to schedule reminders for.
    /// Each assignment may produce up to 4 reminders (one per selected
    /// ``ReminderTiming``), but the most common configuration yields 2
    /// (24h + 1h).  We cap at 20 assignments so that in the worst case
    /// we produce 80 notifications, but that is still well within the
    /// iOS 64-pending-notification limit when using the default 2 timings
    /// (20 * 2 = 40).  If more timings are selected the cap may need
    /// lowering -- we handle that dynamically below.
    private static let maxAssignments = 20

    /// Hard ceiling -- iOS silently drops pending requests beyond 64.
    private static let iosNotificationLimit = 64

    /// We leave some headroom for non-assignment notifications
    /// (streaks, quizzes, messages, etc.).
    private static let assignmentBudget = 40

    private let center = UNUserNotificationCenter.current()

    // MARK: - Schedule Assignment Reminders

    /// Remove all previously scheduled assignment reminders, then schedule
    /// fresh reminders for assignments due within the next 7 days that
    /// have not yet been submitted.
    ///
    /// Reminders are scheduled according to the timings stored in
    /// ``NotificationPreferences``.
    func scheduleAssignmentReminders(_ assignments: [Assignment]) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // 1. Remove stale assignment reminders.
        await cancelAllAssignmentReminders()

        // 2. Load user preferences.
        let prefs = NotificationPreferences.load()
        guard prefs.assignmentReminders else { return }
        let timings = prefs.reminderTiming
        guard !timings.isEmpty else { return }

        // 3. Compute the scheduling window.
        let now = Date()
        guard let windowEnd = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }

        // 4. Filter & sort.
        let upcoming = assignments
            .filter { !$0.isSubmitted && !$0.isOverdue && $0.dueDate > now && $0.dueDate <= windowEnd }
            .sorted { $0.dueDate < $1.dueDate }

        // 5. Determine how many assignments we can cover without exceeding
        //    the budget.
        let remindersPerAssignment = timings.count
        let maxAllowed = min(Self.maxAssignments, Self.assignmentBudget / max(remindersPerAssignment, 1))
        let capped = upcoming.prefix(maxAllowed)

        // 6. Build and schedule requests.
        for assignment in capped {
            for timing in timings {
                guard let triggerDate = Calendar.current.date(
                    byAdding: .second,
                    value: -Int(timing.timeInterval),
                    to: assignment.dueDate
                ), triggerDate > now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = assignment.courseName
                content.body = "\(assignment.title) is due \(displayTimeframe(timing))"
                content.sound = .default
                content.categoryIdentifier = "ASSIGNMENT_REMINDER"
                content.userInfo = [
                    "assignmentId": assignment.id.uuidString,
                    "courseId": assignment.courseId.uuidString,
                    "type": "assignment"
                ]

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let identifier = "\(Self.assignmentReminderPrefix)\(timing.rawValue)-\(assignment.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    self.error = "Failed to schedule reminder: \(error.localizedDescription)"
                    #if DEBUG
                    print("[ReminderSchedulingService] Failed to add request \(identifier): \(error)")
                    #endif
                }
            }
        }

        #if DEBUG
        let pending = await center.pendingNotificationRequests()
        print("[ReminderSchedulingService] Scheduled reminders. Total pending: \(pending.count)")
        #endif
    }

    // MARK: - Schedule a Single Custom Reminder

    /// Schedule a one-off local notification at the given date.
    func scheduleReminder(title: String, body: String, date: Date, identifier: String) async {
        guard date > Date() else {
            error = "Cannot schedule a reminder in the past."
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            self.error = "Failed to schedule reminder: \(error.localizedDescription)"
            #if DEBUG
            print("[ReminderSchedulingService] Failed to schedule custom reminder \(identifier): \(error)")
            #endif
        }
    }

    // MARK: - Cancel All Assignment Reminders

    /// Remove every pending notification whose identifier starts with the
    /// assignment-reminder prefix.  Other notifications (streak, quiz,
    /// message, etc.) are left untouched.
    func cancelAllAssignmentReminders() async {
        let pending = await center.pendingNotificationRequests()
        let idsToRemove = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.assignmentReminderPrefix) }

        guard !idsToRemove.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        #if DEBUG
        print("[ReminderSchedulingService] Cancelled \(idsToRemove.count) assignment reminders.")
        #endif
    }

    // MARK: - Cancel a Specific Reminder

    /// Remove a single pending notification by its identifier.
    func cancelReminder(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Pending Reminder Count

    /// Returns the total number of pending notification requests currently
    /// registered with the system (not limited to assignment reminders).
    func pendingReminderCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.count
    }

    // MARK: - Helpers

    private func displayTimeframe(_ timing: NotificationPreferences.ReminderTiming) -> String {
        switch timing {
        case .twentyFourHours: return "in 24 hours"
        case .twelveHours:     return "in 12 hours"
        case .sixHours:        return "in 6 hours"
        case .oneHour:         return "in 1 hour"
        }
    }
}
