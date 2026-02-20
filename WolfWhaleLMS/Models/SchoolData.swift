import Foundation

/// View-facing Announcement model.
/// DB table `announcements` has: id, tenant_id, course_id, title, content, created_by, published_at, expires_at, status.
/// The service layer resolves `created_by` UUID to `authorName` by looking up profiles.
/// `date` is populated from `published_at` (or creation timestamp).
/// `isPinned` has no DB column; defaults to false.
nonisolated struct Announcement: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var authorName: String       // resolved from created_by -> profiles.first_name + last_name
    var date: Date               // from published_at or created_at
    var isPinned: Bool           // no DB column; always false unless app logic sets it
}

/// View-facing AttendanceRecord model.
/// DB table `attendance_records` has: id, tenant_id, course_id, student_id, attendance_date, status, notes, marked_by.
/// `date` is populated from `attendance_date`.
/// `courseName` is resolved from course_id -> courses.name.
/// `studentName` is resolved from student_id -> profiles.
nonisolated struct AttendanceRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date               // from attendance_date
    var status: AttendanceStatus
    var courseName: String       // resolved from course_id -> courses.name
    var studentName: String?     // resolved from student_id -> profiles
    var notes: String?           // from notes column
}

nonisolated enum AttendanceStatus: String, CaseIterable, Sendable {
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

    /// Case-insensitive matching for DB values (e.g. "present", "Present", "PRESENT").
    static func from(_ string: String) -> AttendanceStatus? {
        let lowered = string.lowercased()
        return Self.allCases.first { $0.rawValue.lowercased() == lowered }
    }
}

nonisolated struct GradeEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var courseId: UUID
    var courseName: String
    var courseIcon: String
    var courseColor: String
    var letterGrade: String
    var numericGrade: Double
    var assignmentGrades: [AssignmentGrade]
}

nonisolated struct AssignmentGrade: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var score: Double
    var maxScore: Double
    var date: Date
    var type: String
}

nonisolated struct ChildInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var grade: String
    var avatarSystemName: String
    var gpa: Double
    var attendanceRate: Double
    var courses: [GradeEntry]
    var recentAssignments: [Assignment]
}

nonisolated struct SchoolMetrics: Sendable {
    var totalStudents: Int
    var totalTeachers: Int
    var totalCourses: Int
    var averageAttendance: Double
    var averageGPA: Double
    var activeUsers: Int
}
