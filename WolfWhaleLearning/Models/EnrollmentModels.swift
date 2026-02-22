import Foundation

// MARK: - Enrollment Status

nonisolated enum EnrollmentStatus: String, Codable, CaseIterable, Sendable {
    case enrolled
    case pending      // Awaiting teacher/admin approval
    case waitlisted   // Course is full
    case dropped
    case denied

    var displayName: String {
        switch self {
        case .enrolled: "Enrolled"
        case .pending: "Pending Approval"
        case .waitlisted: "Waitlisted"
        case .dropped: "Dropped"
        case .denied: "Denied"
        }
    }

    var iconName: String {
        switch self {
        case .enrolled: "checkmark.circle.fill"
        case .pending: "clock.fill"
        case .waitlisted: "hourglass"
        case .dropped: "xmark.circle.fill"
        case .denied: "nosign"
        }
    }

    var color: String {
        switch self {
        case .enrolled: "green"
        case .pending: "orange"
        case .waitlisted: "yellow"
        case .dropped: "gray"
        case .denied: "red"
        }
    }
}

// MARK: - Enrollment Request

nonisolated struct EnrollmentRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    let studentId: UUID
    let studentName: String
    let courseId: UUID
    let courseName: String
    let requestDate: Date
    var status: EnrollmentStatus
    var reviewedBy: UUID?
    var reviewDate: Date?
    var note: String?
}

// MARK: - Course Catalog Entry

nonisolated struct CourseCatalogEntry: Identifiable, Hashable, Sendable {
    let id: UUID  // course ID
    let name: String
    let description: String
    let teacherName: String
    let schedule: String?
    let subject: String?
    let gradeLevel: String?
    let currentEnrollment: Int
    let maxEnrollment: Int
    let enrollmentStatus: EnrollmentStatus?  // nil = not enrolled

    var isFull: Bool { currentEnrollment >= maxEnrollment }
    var spotsRemaining: Int { max(0, maxEnrollment - currentEnrollment) }
}
