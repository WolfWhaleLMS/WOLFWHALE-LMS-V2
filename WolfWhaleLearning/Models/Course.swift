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

    // MARK: - Prerequisites
    /// IDs of courses that must be completed before enrolling in this course.
    var prerequisiteIds: [UUID]
    /// Human-readable description of prerequisites (e.g., "Algebra I required").
    var prerequisitesDescription: String?

    // MARK: - Section Management
    /// Section number for multi-section courses (e.g., 1, 2, 3).
    var sectionNumber: Int?
    /// Human-readable section label (e.g., "Period 1", "Section A").
    var sectionLabel: String?
    /// Maximum number of students allowed in this course/section.
    var maxCapacity: Int

    /// Number of students currently enrolled (derived from enrolledStudentCount).
    var currentEnrollment: Int {
        enrolledStudentCount
    }

    /// Whether the course/section is at full capacity.
    var isFull: Bool {
        currentEnrollment >= maxCapacity
    }

    /// Remaining spots available.
    var spotsRemaining: Int {
        max(0, maxCapacity - currentEnrollment)
    }

    var totalLessons: Int {
        modules.reduce(0) { $0 + $1.lessons.count }
    }

    var completedLessons: Int {
        modules.reduce(0) { total, module in
            total + module.lessons.filter(\.isCompleted).count
        }
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id, title, description, teacherName, iconSystemName, colorName
        case modules, enrolledStudentCount, progress, classCode
        case prerequisiteIds, prerequisitesDescription
        case sectionNumber, sectionLabel, maxCapacity
    }

    // MARK: - Init

    init(
        id: UUID,
        title: String,
        description: String,
        teacherName: String,
        iconSystemName: String,
        colorName: String,
        modules: [Module],
        enrolledStudentCount: Int,
        progress: Double,
        classCode: String,
        prerequisiteIds: [UUID] = [],
        prerequisitesDescription: String? = nil,
        sectionNumber: Int? = nil,
        sectionLabel: String? = nil,
        maxCapacity: Int = 30
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.teacherName = teacherName
        self.iconSystemName = iconSystemName
        self.colorName = colorName
        self.modules = modules
        self.enrolledStudentCount = enrolledStudentCount
        self.progress = progress
        self.classCode = classCode
        self.prerequisiteIds = prerequisiteIds
        self.prerequisitesDescription = prerequisitesDescription
        self.sectionNumber = sectionNumber
        self.sectionLabel = sectionLabel
        self.maxCapacity = maxCapacity
    }

    // MARK: - Decodable (backward-compatible with JSON missing new keys)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        teacherName = try container.decode(String.self, forKey: .teacherName)
        iconSystemName = try container.decode(String.self, forKey: .iconSystemName)
        colorName = try container.decode(String.self, forKey: .colorName)
        modules = try container.decode([Module].self, forKey: .modules)
        enrolledStudentCount = try container.decode(Int.self, forKey: .enrolledStudentCount)
        progress = try container.decode(Double.self, forKey: .progress)
        classCode = try container.decode(String.self, forKey: .classCode)
        // New fields: decode with defaults if missing
        prerequisiteIds = try container.decodeIfPresent([UUID].self, forKey: .prerequisiteIds) ?? []
        prerequisitesDescription = try container.decodeIfPresent(String.self, forKey: .prerequisitesDescription)
        sectionNumber = try container.decodeIfPresent(Int.self, forKey: .sectionNumber)
        sectionLabel = try container.decodeIfPresent(String.self, forKey: .sectionLabel)
        maxCapacity = try container.decodeIfPresent(Int.self, forKey: .maxCapacity) ?? 30
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
