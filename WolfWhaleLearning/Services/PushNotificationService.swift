import Foundation
import Supabase
import UserNotifications
import UIKit

/// Manages remote (APNs) push notification registration, device-token
/// persistence, and incoming push payload routing.
///
/// Local notification scheduling (assignment reminders, streaks, etc.)
/// lives in ``NotificationService`` -- this service handles the *remote*
/// push layer only.
@Observable
@MainActor
final class PushNotificationService {

    // MARK: - Published State

    var isAuthorized = false
    var deviceToken: String?

    // MARK: - Deep-link destinations set from remote payloads

    var deepLinkAssignmentId: UUID?
    var deepLinkConversationId: UUID?
    var deepLinkGradeId: UUID?

    // MARK: - Constants

    private static let tokenDefaultsKey = "wolfwhale_apns_device_token"

    // MARK: - Authorization & Registration

    /// Request notification permissions and, if granted, register for
    /// remote notifications with APNs.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                registerForRemoteNotifications()
            }
        } catch {
            isAuthorized = false
            #if DEBUG
            print("[PushNotificationService] Authorization error: \(error)")
            #endif
        }
    }

    /// Tells iOS to register with APNs.  The resulting token arrives via
    /// `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Device Token Handling

    /// Called by the AppDelegate when APNs provides a device token.
    func handleDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = hex
        UserDefaults.standard.set(hex, forKey: Self.tokenDefaultsKey)
        #if DEBUG
        print("[PushNotificationService] Device token: \(hex)")
        #endif
    }

    /// Called by the AppDelegate when APNs registration fails.
    func handleRegistrationError(_ error: Error) {
        #if DEBUG
        print("[PushNotificationService] Registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Server Token Management

    /// Upload the current device token to the Supabase `device_tokens` table.
    /// Should be called after a successful login.
    func sendTokenToServer(userId: UUID) async {
        guard let token = deviceToken ?? UserDefaults.standard.string(forKey: Self.tokenDefaultsKey) else {
            #if DEBUG
            print("[PushNotificationService] No device token available to send.")
            #endif
            return
        }

        let dto = InsertDeviceTokenDTO(
            userId: userId,
            token: token,
            platform: "ios"
        )

        do {
            // Upsert: if a row with the same user_id + token already exists,
            // Supabase will handle the conflict (or we just insert a fresh row).
            // We delete old tokens for this user first, then insert the new one
            // to avoid stale entries.
            try await supabaseClient
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("platform", value: "ios")
                .execute()

            try await supabaseClient
                .from("device_tokens")
                .insert(dto)
                .execute()

            #if DEBUG
            print("[PushNotificationService] Token uploaded for user \(userId.uuidString)")
            #endif
        } catch {
            #if DEBUG
            print("[PushNotificationService] Failed to upload token: \(error)")
            #endif
        }
    }

    /// Remove the device token from the server on logout so the user no
    /// longer receives push notifications on this device.
    func removeTokenFromServer(userId: UUID) async {
        do {
            try await supabaseClient
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("platform", value: "ios")
                .execute()

            #if DEBUG
            print("[PushNotificationService] Token removed for user \(userId.uuidString)")
            #endif
        } catch {
            #if DEBUG
            print("[PushNotificationService] Failed to remove token: \(error)")
            #endif
        }

        // Clear local cache
        deviceToken = nil
        UserDefaults.standard.removeObject(forKey: Self.tokenDefaultsKey)
    }

    // MARK: - Remote Notification Handling

    /// Parse the push payload and set the appropriate deep-link destination
    /// so the UI can navigate to the correct view.
    ///
    /// Expected payload keys:
    /// - `type`: `"assignment"`, `"message"`, or `"grade"`
    /// - `assignmentId`, `conversationId`, `gradeId`: UUID strings
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String

        switch type {
        case "assignment":
            if let idString = userInfo["assignmentId"] as? String {
                deepLinkAssignmentId = UUID(uuidString: idString)
            }
        case "message":
            if let idString = userInfo["conversationId"] as? String {
                deepLinkConversationId = UUID(uuidString: idString)
            }
        case "grade":
            if let idString = userInfo["gradeId"] as? String {
                deepLinkGradeId = UUID(uuidString: idString)
            } else if let idString = userInfo["assignmentId"] as? String {
                deepLinkGradeId = UUID(uuidString: idString)
            }
        default:
            // Best-effort: try to route based on any IDs present.
            if let idString = userInfo["assignmentId"] as? String {
                deepLinkAssignmentId = UUID(uuidString: idString)
            } else if let idString = userInfo["conversationId"] as? String {
                deepLinkConversationId = UUID(uuidString: idString)
            }
        }
    }

    /// Handle a silent push notification (`content-available: 1`).
    /// Returns `true` if the payload was recognised and a background
    /// data refresh should be triggered by the caller.
    func handleSilentPush(userInfo: [AnyHashable: Any]) -> Bool {
        // Check for the content-available flag that marks silent pushes.
        guard let aps = userInfo["aps"] as? [String: Any],
              let contentAvailable = aps["content-available"] as? Int,
              contentAvailable == 1 else {
            return false
        }

        #if DEBUG
        print("[PushNotificationService] Silent push received -- triggering background refresh.")
        #endif
        return true
    }

    // MARK: - Local Reminder Helpers (kept for backward compatibility)

    /// Schedule local notifications for upcoming assignments.
    func scheduleAssignmentReminder(assignmentTitle: String, dueDate: Date, assignmentId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Assignment Due Soon"
        content.body = "\(assignmentTitle) is due tomorrow!"
        content.sound = .default
        content.categoryIdentifier = "ASSIGNMENT_REMINDER"
        content.userInfo = ["assignmentId": assignmentId.uuidString]

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

    /// Schedule quiz reminder.
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

    /// Daily streak reminder.
    func scheduleDailyStreakReminder(currentStreak: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-streak"])

        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Going!"
        content.body = "You're on a \(currentStreak)-day streak. Log in today to keep it alive!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-streak", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Clear all pending notifications on logout.
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Register notification categories for interactive actions.
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
