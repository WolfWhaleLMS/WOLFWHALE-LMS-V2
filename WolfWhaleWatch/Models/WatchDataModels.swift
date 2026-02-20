import Foundation

/// Lightweight assignment model transferred from the iPhone app via WatchConnectivity.
/// Mirrors the essential fields of the main app's `Assignment` struct.
struct WatchAssignment: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let courseName: String
    let dueDate: Date
    let points: Int
    let isSubmitted: Bool
    let grade: Double?

    /// Calendar-aware check for whether the assignment is due today.
    var isDueToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }

    /// Calendar-aware check for whether the assignment is due tomorrow.
    var isDueTomorrow: Bool {
        Calendar.current.isDateInTomorrow(dueDate)
    }

    /// True when the due date has already passed and the assignment is not submitted.
    var isOverdue: Bool {
        !isSubmitted && dueDate < Date()
    }

    /// Number of full days remaining until the due date.
    /// Returns 0 for today, negative values for overdue assignments.
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }
}

/// Lightweight schedule entry transferred from the iPhone app via WatchConnectivity.
struct WatchScheduleEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let courseName: String
    let startTime: Date
    let endTime: Date
    let roomNumber: String

    /// True if the current time falls within this class period.
    var isCurrentlyActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }

    /// True if this class has not yet started today.
    var isUpcoming: Bool {
        Date() < startTime
    }

    /// Seconds remaining until this class starts. Returns 0 if already started or passed.
    var secondsUntilStart: TimeInterval {
        max(0, startTime.timeIntervalSince(Date()))
    }
}

/// Lightweight grade entry transferred from the iPhone app via WatchConnectivity.
/// Mirrors the essential fields of the main app's `GradeEntry` struct.
struct WatchGrade: Identifiable, Codable, Hashable {
    let id: UUID
    let courseName: String
    let letterGrade: String
    let numericGrade: Double
    let courseColor: String
    let courseIcon: String
}
