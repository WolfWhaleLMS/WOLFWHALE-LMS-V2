import Foundation

/// Schedules local notifications for upcoming assignments and quizzes
enum NotificationScheduler {

    /// Schedule reminders for all upcoming assignments
    static func scheduleAssignmentReminders(
        _ assignments: [(id: UUID, title: String, dueDate: Date)],
        using service: PushNotificationService
    ) {
        for assignment in assignments {
            guard !assignment.dueDate.timeIntervalSinceNow.isLess(than: 0) else { continue }
            service.scheduleAssignmentReminder(
                assignmentTitle: assignment.title,
                dueDate: assignment.dueDate,
                assignmentId: assignment.id
            )
        }
    }

    /// Schedule reminders for all upcoming quizzes
    static func scheduleQuizReminders(
        _ quizzes: [(id: UUID, title: String, dueDate: Date)],
        using service: PushNotificationService
    ) {
        for quiz in quizzes {
            guard !quiz.dueDate.timeIntervalSinceNow.isLess(than: 0) else { continue }
            service.scheduleQuizReminder(
                quizTitle: quiz.title,
                dueDate: quiz.dueDate,
                quizId: quiz.id
            )
        }
    }
}
