import Foundation

nonisolated struct Announcement: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var content: String
    var authorName: String
    var date: Date
    var isPinned: Bool
}

nonisolated struct AttendanceRecord: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var date: Date
    var status: AttendanceStatus
    var courseName: String
    var studentName: String?
    var notes: String?
}

nonisolated enum AttendanceStatus: String, CaseIterable, Sendable, Codable {
    case present = "Present"
    case absent = "Absent"
    case tardy = "Tardy"
    case excused = "Excused"

    var iconName: String {
        switch self {
        case .present: "checkmark.circle.fill"
        case .absent: "xmark.circle.fill"
        case .tardy: "clock.fill"
        case .excused: "doc.text.fill"
        }
    }

    var colorName: String {
        switch self {
        case .present: "green"
        case .absent: "red"
        case .tardy: "orange"
        case .excused: "blue"
        }
    }

    static func from(_ string: String) -> AttendanceStatus? {
        let lowered = string.lowercased()
        return Self.allCases.first { $0.rawValue.lowercased() == lowered }
    }
}

nonisolated struct GradeEntry: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var courseId: UUID
    var courseName: String
    var courseIcon: String
    var courseColor: String
    var letterGrade: String
    var numericGrade: Double
    var assignmentGrades: [AssignmentGrade]
}

nonisolated struct AssignmentGrade: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var score: Double
    var maxScore: Double
    var date: Date
    var type: String
}

nonisolated struct ChildInfo: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var grade: String
    var avatarSystemName: String
    var gpa: Double
    var attendanceRate: Double
    var courses: [GradeEntry]
    var recentAssignments: [Assignment]
}

// MARK: - Parent Alerts

nonisolated enum ParentAlertType: String, Sendable, Codable, CaseIterable {
    case lowGrade = "Low Grade"
    case absence = "Absence"
    case upcomingDueDate = "Upcoming Due Date"

    var iconName: String {
        switch self {
        case .lowGrade: "exclamationmark.triangle.fill"
        case .absence: "xmark.circle.fill"
        case .upcomingDueDate: "calendar.badge.exclamationmark"
        }
    }

    var colorName: String {
        switch self {
        case .lowGrade: "red"
        case .absence: "orange"
        case .upcomingDueDate: "blue"
        }
    }
}

nonisolated struct ParentAlert: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var type: ParentAlertType
    var childId: UUID
    var childName: String
    var title: String
    var message: String
    var courseName: String
    var date: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        type: ParentAlertType,
        childId: UUID,
        childName: String,
        title: String,
        message: String,
        courseName: String,
        date: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.childId = childId
        self.childName = childName
        self.title = title
        self.message = message
        self.courseName = courseName
        self.date = date
        self.isRead = isRead
    }
}

nonisolated struct SchoolMetrics: Sendable, Codable {
    var totalStudents: Int
    var totalTeachers: Int
    var totalCourses: Int
    var averageAttendance: Double
    var averageGPA: Double
    var activeUsers: Int
}
