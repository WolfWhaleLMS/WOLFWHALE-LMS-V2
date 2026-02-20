import Foundation
import UserNotifications
import UIKit

@Observable
@MainActor
final class PushNotificationService {
    var isAuthorized = false
    var deviceToken: String?

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            isAuthorized = false
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        // In production: send token to Supabase edge function for storage
    }

    // Schedule local notifications for upcoming assignments
    func scheduleAssignmentReminder(assignmentTitle: String, dueDate: Date, assignmentId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Assignment Due Soon"
        content.body = "\(assignmentTitle) is due tomorrow!"
        content.sound = .default
        content.categoryIdentifier = "ASSIGNMENT_REMINDER"
        content.userInfo = ["assignmentId": assignmentId.uuidString]

        // Schedule for 24 hours before due date
        let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: dueDate) ?? dueDate
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "assignment-\(assignmentId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Schedule quiz reminder
    func scheduleQuizReminder(quizTitle: String, dueDate: Date, quizId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Quiz Coming Up"
        content.body = "\(quizTitle) is due tomorrow. Don't forget to study!"
        content.sound = .default
        content.categoryIdentifier = "QUIZ_REMINDER"
        content.userInfo = ["quizId": quizId.uuidString]

        let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: dueDate) ?? dueDate
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "quiz-\(quizId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Daily streak reminder
    func scheduleDailyStreakReminder(currentStreak: Int) {
        // Remove existing streak reminder
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-streak"])

        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Going!"
        content.body = "You're on a \(currentStreak)-day streak. Log in today to keep it alive!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"

        // Schedule for 6 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-streak", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // Clear all pending notifications on logout
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // Register notification categories for actions
    func registerNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: [.destructive]
        )

        let assignmentCategory = UNNotificationCategory(
            identifier: "ASSIGNMENT_REMINDER",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let quizCategory = UNNotificationCategory(
            identifier: "QUIZ_REMINDER",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            assignmentCategory, quizCategory, streakCategory
        ])
    }
}
