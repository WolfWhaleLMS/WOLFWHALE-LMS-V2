import Foundation

// MARK: - Conference Status

nonisolated enum ConferenceStatus: String, CaseIterable, Sendable, Codable, Identifiable {
    case requested = "Requested"
    case confirmed = "Confirmed"
    case cancelled = "Cancelled"
    case completed = "Completed"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .requested: "clock.fill"
        case .confirmed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        case .completed: "flag.checkered"
        }
    }

    var colorName: String {
        switch self {
        case .requested: "orange"
        case .confirmed: "green"
        case .cancelled: "red"
        case .completed: "blue"
        }
    }
}

// MARK: - Conference

nonisolated struct Conference: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var parentId: UUID
    var teacherId: UUID
    var teacherName: String
    var parentName: String
    var childName: String
    var date: Date
    var duration: Int
    var status: ConferenceStatus
    var notes: String?
    var location: String?

    init(
        id: UUID = UUID(),
        parentId: UUID,
        teacherId: UUID,
        teacherName: String,
        parentName: String,
        childName: String,
        date: Date,
        duration: Int = 15,
        status: ConferenceStatus = .requested,
        notes: String? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.teacherId = teacherId
        self.teacherName = teacherName
        self.parentName = parentName
        self.childName = childName
        self.date = date
        self.duration = duration
        self.status = status
        self.notes = notes
        self.location = location
    }

    /// Human-readable time slot label.
    var timeSlotLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Whether this conference is in the future.
    var isUpcoming: Bool {
        date > Date() && status != .cancelled
    }
}

// MARK: - Teacher Available Slot

nonisolated struct TeacherAvailableSlot: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var teacherId: UUID
    var date: Date
    var durationMinutes: Int
    var isBooked: Bool

    init(
        id: UUID = UUID(),
        teacherId: UUID,
        date: Date,
        durationMinutes: Int = 15,
        isBooked: Bool = false
    ) {
        self.id = id
        self.teacherId = teacherId
        self.date = date
        self.durationMinutes = durationMinutes
        self.isBooked = isBooked
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Weekly Digest

nonisolated struct WeeklyDigest: Sendable {
    var childName: String
    var weekStartDate: Date
    var weekEndDate: Date
    var gradeChanges: [WeeklyGradeChange]
    var assignmentsCompleted: Int
    var assignmentsDueNextWeek: [DigestAssignment]
    var attendanceSummary: DigestAttendanceSummary
    var teacherComments: [DigestTeacherComment]
}

nonisolated struct WeeklyGradeChange: Identifiable, Sendable {
    let id: UUID
    var courseName: String
    var previousGrade: Double
    var currentGrade: Double
    var letterGrade: String

    init(
        id: UUID = UUID(),
        courseName: String,
        previousGrade: Double,
        currentGrade: Double,
        letterGrade: String
    ) {
        self.id = id
        self.courseName = courseName
        self.previousGrade = previousGrade
        self.currentGrade = currentGrade
        self.letterGrade = letterGrade
    }

    var changeAmount: Double {
        currentGrade - previousGrade
    }

    var isImproving: Bool {
        changeAmount > 0
    }
}

nonisolated struct DigestAssignment: Identifiable, Sendable {
    let id: UUID
    var title: String
    var courseName: String
    var dueDate: Date

    init(id: UUID = UUID(), title: String, courseName: String, dueDate: Date) {
        self.id = id
        self.title = title
        self.courseName = courseName
        self.dueDate = dueDate
    }
}

nonisolated struct DigestAttendanceSummary: Sendable {
    var totalDays: Int
    var presentDays: Int
    var absentDays: Int
    var tardyDays: Int

    var attendanceRate: Double {
        guard totalDays > 0 else { return 1.0 }
        return Double(presentDays) / Double(totalDays)
    }
}

nonisolated struct DigestTeacherComment: Identifiable, Sendable {
    let id: UUID
    var teacherName: String
    var courseName: String
    var comment: String
    var date: Date

    init(
        id: UUID = UUID(),
        teacherName: String,
        courseName: String,
        comment: String,
        date: Date = Date()
    ) {
        self.id = id
        self.teacherName = teacherName
        self.courseName = courseName
        self.comment = comment
        self.date = date
    }
}
