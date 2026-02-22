import Foundation

/// User-facing notification preference model persisted in ``UserDefaults``.
///
/// The struct is `Sendable` and `nonisolated` so it can be read/written
/// from any isolation context without hopping to the main actor.
nonisolated struct NotificationPreferences: Codable, Sendable {

    // MARK: - Properties

    /// Whether local assignment-due reminders are enabled.
    var assignmentReminders: Bool = true

    /// Whether the user wants to receive grade-posted notifications.
    var gradeNotifications: Bool = true

    /// Whether the user wants to receive new-message notifications.
    var messageNotifications: Bool = true

    /// Whether the user wants to receive school announcement notifications.
    var announcementNotifications: Bool = true

    /// Which reminder windows the user has opted into.
    var reminderTiming: Set<ReminderTiming> = [.twentyFourHours, .oneHour]

    // MARK: - ReminderTiming

    nonisolated enum ReminderTiming: String, Codable, CaseIterable, Sendable, Hashable {
        case twentyFourHours = "24h"
        case twelveHours     = "12h"
        case sixHours        = "6h"
        case oneHour         = "1h"

        /// Human-readable label for UI display.
        var displayName: String {
            switch self {
            case .twentyFourHours: return "24 Hours Before"
            case .twelveHours:     return "12 Hours Before"
            case .sixHours:        return "6 Hours Before"
            case .oneHour:         return "1 Hour Before"
            }
        }

        /// The number of seconds before the due date that the reminder
        /// should fire.
        var timeInterval: TimeInterval {
            switch self {
            case .twentyFourHours: return 24 * 60 * 60   // 86 400
            case .twelveHours:     return 12 * 60 * 60   // 43 200
            case .sixHours:        return  6 * 60 * 60   // 21 600
            case .oneHour:         return  1 * 60 * 60   //  3 600
            }
        }
    }

    // MARK: - Persistence

    private static let defaultsKey = "wolfwhale_notification_preferences"

    /// Load the stored preferences, falling back to sensible defaults
    /// if nothing has been saved yet (or the data is malformed).
    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return NotificationPreferences()
        }
        do {
            return try JSONDecoder().decode(NotificationPreferences.self, from: data)
        } catch {
            #if DEBUG
            print("[NotificationPreferences] Failed to decode: \(error). Returning defaults.")
            #endif
            return NotificationPreferences()
        }
    }

    /// Persist the current preferences to ``UserDefaults``.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            #if DEBUG
            print("[NotificationPreferences] Failed to encode: \(error)")
            #endif
        }
    }
}
