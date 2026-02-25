import Foundation
import UserNotifications
import Observation

// MARK: - DueDateReminderService
//
// Integration layer that orchestrates assignment due-date reminders across
// the app lifecycle. Delegates actual notification scheduling to
// ``ReminderSchedulingService`` and coordinates with
// ``NotificationPreferences`` for user settings.
//
// -----------------------------------------------------------------------
// WHERE TO CALL refreshReminders():
// -----------------------------------------------------------------------
//
// 1. After assignments load in AppViewModel.loadData()
//    - In the Task.detached block that runs after data loads successfully,
//      call: dueDateReminderService.refreshReminders(assignments: assignments)
//
// 2. When app comes to foreground (scenePhase changes to .active)
//    - In AppViewModel.handleForegroundResume(), call:
//      Task { await dueDateReminderService.refreshReminders(assignments: assignments) }
//    - Or let the existing refreshData() -> loadData() path handle it
//      since loadData() already triggers reminder scheduling.
//
// 3. After an assignment is submitted
//    - In AppViewModel.submitAssignment(_:text:), after marking the
//      assignment as submitted, call:
//      Task { await dueDateReminderService.refreshReminders(assignments: assignments) }
//    - This removes the reminder for the now-submitted assignment.
//
// 4. After notification preferences change
//    - In any settings view that modifies NotificationPreferences and
//      calls prefs.save(), follow up with:
//      Task { await dueDateReminderService.refreshReminders(assignments: assignments) }
//    - This re-schedules with the new timing selections.
//
// 5. After enrolling in a new course (enrollByClassCode)
//    - The subsequent loadData() call will pick this up automatically.
//
// 6. On logout
//    - Call dueDateReminderService.cancelAllReminders() to clear pending
//      notifications for the departing user.
// -----------------------------------------------------------------------

@MainActor
@Observable
final class DueDateReminderService {

    // MARK: - Published State

    var error: String?
    var isLoading = false

    /// Number of assignment reminders currently scheduled with the system.
    var scheduledCount: Int = 0

    // MARK: - Dependencies

    /// The underlying service that handles UNNotificationCenter interactions.
    /// Injected so that this class stays focused on lifecycle orchestration.
    private let scheduler: ReminderSchedulingService

    // MARK: - Constants

    /// Prefix shared with ``ReminderSchedulingService`` so we can independently
    /// query pending assignment reminders.
    private static let assignmentReminderPrefix = "assignment-reminder-"

    /// Window of upcoming assignments to consider for reminders.
    private static let lookAheadDays = 7

    /// Maximum assignments to schedule reminders for (budget-aware).
    private static let maxAssignments = 20

    // MARK: - Init

    init(scheduler: ReminderSchedulingService? = nil) {
        self.scheduler = scheduler ?? ReminderSchedulingService()
    }

    // MARK: - Refresh Reminders

    /// Auto-schedule reminders for all upcoming, unsubmitted assignments.
    ///
    /// This is the primary entry point. Call it whenever the assignment list
    /// changes or user preferences are modified.
    ///
    /// - Parameters:
    ///   - assignments: The full list of assignments for the current user.
    ///     Filtering and sorting are handled internally.
    func refreshReminders(assignments: [Assignment]) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // 1. Load user preferences from UserDefaults.
        let prefs = NotificationPreferences.load()

        // 2. If assignment reminders are disabled, cancel everything and bail.
        guard prefs.assignmentReminders else {
            await cancelAllReminders()
            return
        }

        // 3. Check that at least one timing is selected.
        guard !prefs.reminderTiming.isEmpty else {
            await cancelAllReminders()
            return
        }

        // 4. Check notification authorization -- no point scheduling if denied.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            error = "Notifications are not authorized. Enable them in Settings."
            await cancelAllReminders()
            return
        }

        // 5. Filter to eligible assignments:
        //    - Not yet submitted
        //    - Not past due
        //    - Due within the look-ahead window
        let now = Date()
        guard let windowEnd = Calendar.current.date(
            byAdding: .day,
            value: Self.lookAheadDays,
            to: now
        ) else {
            return
        }

        let eligible = assignments
            .filter { !$0.isSubmitted && !$0.isOverdue && $0.dueDate > now && $0.dueDate <= windowEnd }
            .sorted { $0.dueDate < $1.dueDate }

        // 6. Cap to avoid exceeding the iOS 64 pending notification limit.
        //    Each assignment may produce up to timings.count reminders.
        let remindersPerAssignment = prefs.reminderTiming.count
        let budgetCap = min(Self.maxAssignments, 40 / max(remindersPerAssignment, 1))
        let capped = Array(eligible.prefix(budgetCap))

        // 7. Delegate to ReminderSchedulingService for the actual scheduling.
        //    It handles cancelling stale reminders internally before scheduling new ones.
        await scheduler.scheduleAssignmentReminders(capped)

        // 8. Propagate any error from the scheduler.
        if let schedulerError = scheduler.error {
            error = schedulerError
        }

        // 9. Update the scheduled count by querying the notification center.
        scheduledCount = await pendingAssignmentReminderCount()

        #if DEBUG
        print("[DueDateReminderService] Refresh complete. \(scheduledCount) reminders scheduled for \(capped.count) assignments.")
        #endif
    }

    // MARK: - Cancel All Reminders

    /// Remove all assignment reminders from the notification center.
    ///
    /// Call this on logout or when the user disables assignment reminders.
    func cancelAllReminders() async {
        await scheduler.cancelAllAssignmentReminders()
        scheduledCount = 0
        error = nil

        #if DEBUG
        print("[DueDateReminderService] All assignment reminders cancelled.")
        #endif
    }

    // MARK: - Cancel Reminders for a Specific Assignment

    /// Remove all reminders for a single assignment (e.g., after submission).
    ///
    /// - Parameter assignmentId: The UUID of the submitted assignment.
    func cancelReminders(for assignmentId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let idsToRemove = pending
            .map(\.identifier)
            .filter { $0.contains(assignmentId.uuidString) && $0.hasPrefix(Self.assignmentReminderPrefix) }

        guard !idsToRemove.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        scheduledCount = await pendingAssignmentReminderCount()

        #if DEBUG
        print("[DueDateReminderService] Cancelled \(idsToRemove.count) reminders for assignment \(assignmentId).")
        #endif
    }

    // MARK: - Status Queries

    /// Returns the number of pending assignment reminder notifications.
    func pendingAssignmentReminderCount() async -> Int {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix(Self.assignmentReminderPrefix) }.count
    }

    /// Returns whether assignment reminders are currently enabled in user preferences.
    var remindersEnabled: Bool {
        NotificationPreferences.load().assignmentReminders
    }

    /// Synchronizes the ``scheduledCount`` property with the actual pending
    /// notification count from the system. Useful after app launch or
    /// returning to foreground.
    func syncScheduledCount() async {
        scheduledCount = await pendingAssignmentReminderCount()
    }
}
