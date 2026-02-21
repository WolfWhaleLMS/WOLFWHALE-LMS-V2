import Foundation

/// Centralized UserDefaults key constants used throughout the app.
/// Prevents typos and makes key usage discoverable.
nonisolated enum UserDefaultsKeys {
    // MARK: - Settings
    static let biometricEnabled = "biometricEnabled"
    static let colorSchemePreference = "colorSchemePreference"
    static let calendarSyncEnabled = "wolfwhale_calendar_sync_enabled"

    // MARK: - Siri / App Intents
    static let upcomingAssignments = "wolfwhale_upcoming_assignments"
    static let gradesSummary = "wolfwhale_grades_summary"
    static let scheduleToday = "wolfwhale_schedule_today"
}
