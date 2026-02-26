import Foundation
import WidgetKit

// MARK: - App Group Configuration

/// Shared App Group identifier used by both the main app and widget extension
/// to exchange data through UserDefaults.
enum WidgetConstants {
    static let appGroupIdentifier = "group.com.wolfwhale.lms"
    static let deepLinkScheme = "wolfwhale"
}

// MARK: - Shared UserDefaults Keys

/// Mirrors the keys from the main app's `UserDefaultsKeys` so the widget
/// extension can read cached data without importing the main target.
enum WidgetUserDefaultsKeys {
    static let upcomingAssignments = "wolfwhale_upcoming_assignments"
    static let gradesSummary = "wolfwhale_grades_summary"
    static let scheduleToday = "wolfwhale_schedule_today"
}

// MARK: - Cached Data Models
// These mirror the Codable structs used by the main app's `cacheDataForExtensions()`.
// They MUST stay in sync with the main app definitions.

struct CachedAssignment: Codable, Sendable, Identifiable {
    let title: String
    let dueDate: String
    let courseName: String

    var id: String { "\(title)-\(dueDate)" }

    /// Parses the ISO 8601 date string into a `Date`.
    var dueDateParsed: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dueDate) { return date }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dueDate)
    }

    /// Hours remaining until the assignment is due. Negative means overdue.
    var hoursUntilDue: Double? {
        guard let date = dueDateParsed else { return nil }
        return date.timeIntervalSince(Date()) / 3600
    }
}

struct CachedCourseGrade: Codable, Sendable, Identifiable {
    let courseName: String
    let letterGrade: String
    let numericGrade: Double

    var id: String { courseName }
}

struct CachedGradesSummary: Codable, Sendable {
    let gpa: Double
    let courseGrades: [CachedCourseGrade]
}

struct CachedScheduleEntry: Codable, Sendable, Identifiable {
    let courseName: String
    let time: String?

    var id: String { "\(courseName)-\(time ?? "none")" }
}

// MARK: - Shared Data Reader

/// Reads cached LMS data from the shared App Group `UserDefaults`.
/// Falls back to placeholder data when nothing is cached so widgets always
/// render meaningful content.
enum WidgetDataReader {

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }

    // MARK: Assignments

    static func loadAssignments() -> [CachedAssignment] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetUserDefaultsKeys.upcomingAssignments),
              let assignments = try? JSONDecoder().decode([CachedAssignment].self, from: data),
              !assignments.isEmpty else {
            return placeholderAssignments
        }
        return assignments
    }

    // MARK: Grades

    static func loadGradesSummary() -> CachedGradesSummary {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetUserDefaultsKeys.gradesSummary),
              let summary = try? JSONDecoder().decode(CachedGradesSummary.self, from: data) else {
            return placeholderGradesSummary
        }
        return summary
    }

    // MARK: Schedule

    static func loadSchedule() -> [CachedScheduleEntry] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetUserDefaultsKeys.scheduleToday),
              let schedule = try? JSONDecoder().decode([CachedScheduleEntry].self, from: data),
              !schedule.isEmpty else {
            return placeholderSchedule
        }
        return schedule
    }

    // MARK: - Placeholder Data

    static let placeholderAssignments: [CachedAssignment] = [
        CachedAssignment(title: "Essay Draft", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 8)), courseName: "English 10"),
        CachedAssignment(title: "Math Problem Set", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 26)), courseName: "Algebra II"),
        CachedAssignment(title: "Lab Report", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 72)), courseName: "Biology"),
        CachedAssignment(title: "History Reading", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 96)), courseName: "World History"),
        CachedAssignment(title: "French Exercises", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 120)), courseName: "French II"),
        CachedAssignment(title: "Art Portfolio", dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 168)), courseName: "Visual Arts"),
    ]

    static let placeholderGradesSummary = CachedGradesSummary(
        gpa: 3.7,
        courseGrades: [
            CachedCourseGrade(courseName: "English 10", letterGrade: "A-", numericGrade: 91),
            CachedCourseGrade(courseName: "Algebra II", letterGrade: "B+", numericGrade: 88),
            CachedCourseGrade(courseName: "Biology", letterGrade: "A", numericGrade: 95),
            CachedCourseGrade(courseName: "World History", letterGrade: "B", numericGrade: 84),
            CachedCourseGrade(courseName: "French II", letterGrade: "A-", numericGrade: 90),
            CachedCourseGrade(courseName: "Visual Arts", letterGrade: "A", numericGrade: 97),
        ]
    )

    static let placeholderSchedule: [CachedScheduleEntry] = [
        CachedScheduleEntry(courseName: "English 10", time: "8:00 AM"),
        CachedScheduleEntry(courseName: "Algebra II", time: "9:15 AM"),
        CachedScheduleEntry(courseName: "Biology", time: "10:30 AM"),
        CachedScheduleEntry(courseName: "World History", time: "12:00 PM"),
        CachedScheduleEntry(courseName: "French II", time: "1:15 PM"),
        CachedScheduleEntry(courseName: "Visual Arts", time: "2:30 PM"),
    ]
}

// MARK: - Deep Link URLs

enum WidgetDeepLink {
    static let grades = URL(string: "\(WidgetConstants.deepLinkScheme)://grades")!
    static let schedule = URL(string: "\(WidgetConstants.deepLinkScheme)://schedule")!
    static let assignments = URL(string: "\(WidgetConstants.deepLinkScheme)://assignments")!
}
