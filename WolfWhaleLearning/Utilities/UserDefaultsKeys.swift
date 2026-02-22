import Foundation

/// Centralized UserDefaults key constants used throughout the app.
/// Prevents typos and makes key usage discoverable.
nonisolated enum UserDefaultsKeys {
    // MARK: - Settings
    static let biometricEnabled = "biometricEnabled"
    static let colorSchemePreference = "colorSchemePreference"
    static let calendarSyncEnabled = "wolfwhale_calendar_sync_enabled"

    // MARK: - Spotlight
    static let spotlightIndexedCount = "wolfwhale_spotlight_indexed_count"

    // MARK: - Siri / App Intents
    static let upcomingAssignments = "wolfwhale_upcoming_assignments"
    static let gradesSummary = "wolfwhale_grades_summary"
    static let scheduleToday = "wolfwhale_schedule_today"

    // MARK: - Drawing (PencilKit)
    static let drawingTool = "wolfwhale_drawing_tool"
    static let drawingBackground = "wolfwhale_drawing_background"
    static let drawingStrokeColor = "wolfwhale_drawing_stroke_color"

    // MARK: - HealthKit Wellness
    static let hydrationGlasses = "wolfwhale_hydration_glasses"
    static let hydrationDate = "wolfwhale_hydration_date"

    // MARK: - Widgets (App Group)
    static let widgetAppGroup = "group.com.wolfwhale.lms"
}
