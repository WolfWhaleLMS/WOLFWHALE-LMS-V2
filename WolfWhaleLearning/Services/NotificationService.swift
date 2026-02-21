import Foundation
import UserNotifications
import Observation

// MARK: - Notification Categories

nonisolated enum NotificationCategory: String, Sendable {
    case assignmentDue = "ASSIGNMENT_DUE"
    case newMessage = "NEW_MESSAGE"
    case gradePosted = "GRADE_POSTED"
}

nonisolated enum NotificationAction: String, Sendable {
    case viewAssignment = "VIEW_ASSIGNMENT"
    case markAsRead = "MARK_AS_READ"
    case viewMessage = "VIEW_MESSAGE"
    case viewGrade = "VIEW_GRADE"
    case dismiss = "DISMISS"
}

// MARK: - NotificationService

@MainActor
@Observable
final class NotificationService: NSObject {

    var isAuthorized = false
    var pendingNotifications: [UNNotificationRequest] = []

    var deepLinkAssignmentId: UUID?
    var deepLinkConversationId: UUID?
    var deepLinkGradeId: UUID?

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
            #if DEBUG
            print("[NotificationService] Authorization error: \(error)")
            #endif
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Register Categories

    func registerCategories() {
        let viewAssignmentAction = UNNotificationAction(
            identifier: NotificationAction.viewAssignment.rawValue,
            title: "View Assignment",
            options: [.foreground]
        )

        let viewMessageAction = UNNotificationAction(
            identifier: NotificationAction.viewMessage.rawValue,
            title: "View Message",
            options: [.foreground]
        )

        let markAsReadAction = UNNotificationAction(
            identifier: NotificationAction.markAsRead.rawValue,
            title: "Mark as Read",
            options: []
        )

        let viewGradeAction = UNNotificationAction(
            identifier: NotificationAction.viewGrade.rawValue,
            title: "View Grade",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: [.destructive]
        )

        let assignmentCategory = UNNotificationCategory(
            identifier: NotificationCategory.assignmentDue.rawValue,
            actions: [viewAssignmentAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let messageCategory = UNNotificationCategory(
            identifier: NotificationCategory.newMessage.rawValue,
            actions: [viewMessageAction, markAsReadAction],
            intentIdentifiers: [],
            options: []
        )

        let gradeCategory = UNNotificationCategory(
            identifier: NotificationCategory.gradePosted.rawValue,
            actions: [viewGradeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([assignmentCategory, messageCategory, gradeCategory])
    }

    // MARK: - Schedule Assignment Reminders

    func scheduleAssignmentReminder(assignment: Assignment, reminderDate: Date? = nil) {
        guard !assignment.isSubmitted else { return }

        let dueDate = assignment.dueDate
        let assignmentIdString = assignment.id.uuidString

        if let trigger24h = calendarTrigger(for: dueDate, hoursBeforeDue: 24) {
            let content = makeAssignmentContent(
                title: "Assignment Due Tomorrow",
                body: "\"\(assignment.title)\" for \(assignment.courseName) is due tomorrow.",
                assignmentId: assignmentIdString
            )
            let request = UNNotificationRequest(
                identifier: "assignment-24h-\(assignmentIdString)",
                content: content,
                trigger: trigger24h
            )
            center.add(request)
        }

        if let trigger1h = calendarTrigger(for: dueDate, hoursBeforeDue: 1) {
            let content = makeAssignmentContent(
                title: "Assignment Due in 1 Hour",
                body: "\"\(assignment.title)\" for \(assignment.courseName) is due in 1 hour!",
                assignmentId: assignmentIdString
            )
            let request = UNNotificationRequest(
                identifier: "assignment-1h-\(assignmentIdString)",
                content: content,
                trigger: trigger1h
            )
            center.add(request)
        }
    }

    func scheduleAllAssignmentReminders(assignments: [Assignment]) {
        let upcoming = assignments.filter { !$0.isSubmitted && !$0.isOverdue }
        for assignment in upcoming {
            scheduleAssignmentReminder(assignment: assignment)
        }
        Task { await refreshPendingNotifications() }
    }

    // MARK: - Message Notification

    func postNewMessageNotification(senderName: String, preview: String, conversationId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "New Message from \(senderName)"
        content.body = preview
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newMessage.rawValue
        content.userInfo = ["conversationId": conversationId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "message-\(conversationId.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Grade Posted Notification

    func postGradePostedNotification(assignmentTitle: String, grade: String, assignmentId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Grade Posted"
        content.body = "You received \(grade) on \"\(assignmentTitle)\"."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.gradePosted.rawValue
        content.userInfo = ["assignmentId": assignmentId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "grade-\(assignmentId.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Cancel

    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task { await refreshPendingNotifications() }
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        pendingNotifications = []
    }

    /// Clear deep-link destinations after navigation has consumed them.
    func clearDeepLinks() {
        deepLinkAssignmentId = nil
        deepLinkConversationId = nil
        deepLinkGradeId = nil
    }

    // MARK: - Handle Tap Actions

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case NotificationAction.viewAssignment.rawValue,
             UNNotificationDefaultActionIdentifier:
            if let idString = userInfo["assignmentId"] as? String {
                deepLinkAssignmentId = UUID(uuidString: idString)
            }
            if let idString = userInfo["conversationId"] as? String {
                deepLinkConversationId = UUID(uuidString: idString)
            }

        case NotificationAction.viewMessage.rawValue:
            if let idString = userInfo["conversationId"] as? String {
                deepLinkConversationId = UUID(uuidString: idString)
            }

        case NotificationAction.viewGrade.rawValue:
            if let idString = userInfo["assignmentId"] as? String {
                deepLinkGradeId = UUID(uuidString: idString)
            }

        case NotificationAction.markAsRead.rawValue:
            break

        case NotificationAction.dismiss.rawValue:
            break

        default:
            if let idString = userInfo["assignmentId"] as? String {
                deepLinkAssignmentId = UUID(uuidString: idString)
            } else if let idString = userInfo["conversationId"] as? String {
                deepLinkConversationId = UUID(uuidString: idString)
            }
        }
    }

    // MARK: - Refresh Pending

    func refreshPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        pendingNotifications = requests
    }

    // MARK: - Helpers

    private func makeAssignmentContent(title: String, body: String, assignmentId: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.assignmentDue.rawValue
        content.userInfo = ["assignmentId": assignmentId]
        return content
    }

    private func calendarTrigger(for dueDate: Date, hoursBeforeDue: Int) -> UNCalendarNotificationTrigger? {
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -hoursBeforeDue, to: dueDate),
              triggerDate > Date() else {
            return nil
        }
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            handleNotificationResponse(response)
            completionHandler()
        }
    }
}
