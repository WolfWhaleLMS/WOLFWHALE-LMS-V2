import Foundation

nonisolated struct Course: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var description: String
    var teacherName: String
    var iconSystemName: String
    var colorName: String
    var modules: [Module]
    var enrolledStudentCount: Int
    var progress: Double
    var classCode: String

    var totalLessons: Int {
        modules.reduce(0) { $0 + $1.lessons.count }
    }

    var completedLessons: Int {
        modules.reduce(0) { total, module in
            total + module.lessons.filter(\.isCompleted).count
        }
    }
}

nonisolated struct Module: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var lessons: [Lesson]
    var orderIndex: Int
}

nonisolated struct Lesson: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var content: String
    var duration: Int
    var isCompleted: Bool
    var type: LessonType
    var xpReward: Int
    var videoURL: String?
}

// MARK: - Course Schedule

nonisolated enum DayOfWeek: Int, CaseIterable, Sendable, Codable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        }
    }

    var fullName: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        }
    }

    /// Maps Calendar weekday (1=Sunday) to DayOfWeek
    static func from(calendarWeekday: Int) -> DayOfWeek? {
        switch calendarWeekday {
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        default: nil
        }
    }

    nonisolated static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct CourseSchedule: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var courseId: UUID
    var dayOfWeek: DayOfWeek
    /// Minutes from midnight (e.g. 480 = 8:00 AM)
    var startMinute: Int
    /// Minutes from midnight (e.g. 530 = 8:50 AM)
    var endMinute: Int
    var roomNumber: String

    var startTimeString: String {
        formatMinutes(startMinute)
    }

    var endTimeString: String {
        formatMinutes(endMinute)
    }

    var timeRangeString: String {
        "\(startTimeString) - \(endTimeString)"
    }

    var durationMinutes: Int {
        endMinute - startMinute
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

nonisolated enum LessonType: String, Sendable, Codable {
    case reading = "Reading"
    case video = "Video"
    case activity = "Activity"
    case quiz = "Quiz"

    var iconName: String {
        switch self {
        case .reading: "book.fill"
        case .video: "play.rectangle.fill"
        case .activity: "hand.tap.fill"
        case .quiz: "questionmark.circle.fill"
        }
    }
}

// MARK: - Discussion Forum Models

nonisolated struct DiscussionThread: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var courseId: UUID
    var authorId: UUID
    var authorName: String
    var title: String
    var content: String
    var createdDate: Date
    var replyCount: Int
    var isPinned: Bool
}

nonisolated struct DiscussionReply: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var threadId: UUID
    var authorId: UUID
    var authorName: String
    var content: String
    var createdDate: Date
}
