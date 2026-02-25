import Foundation

// MARK: - Term Type

nonisolated enum TermType: String, CaseIterable, Sendable, Codable, Identifiable {
    case semester = "Semester"
    case quarter = "Quarter"
    case trimester = "Trimester"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .semester: "calendar.badge.clock"
        case .quarter: "calendar"
        case .trimester: "calendar.badge.plus"
        }
    }
}

// MARK: - Academic Term

nonisolated struct AcademicTerm: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var type: TermType

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        type: TermType
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - Event Type

nonisolated enum EventType: String, CaseIterable, Sendable, Codable, Identifiable {
    case holiday = "Holiday"
    case examPeriod = "Exam Period"
    case gradeDeadline = "Grade Deadline"
    case parentConference = "Parent Conference"
    case schoolEvent = "School Event"
    case noSchool = "No School"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .holiday: "gift.fill"
        case .examPeriod: "doc.text.fill"
        case .gradeDeadline: "exclamationmark.circle.fill"
        case .parentConference: "person.2.fill"
        case .schoolEvent: "star.fill"
        case .noSchool: "house.fill"
        }
    }

    var colorName: String {
        switch self {
        case .holiday: "red"
        case .examPeriod: "orange"
        case .gradeDeadline: "purple"
        case .parentConference: "blue"
        case .schoolEvent: "green"
        case .noSchool: "gray"
        }
    }
}

// MARK: - Academic Event

nonisolated struct AcademicEvent: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var endDate: Date?
    var type: EventType
    var description: String?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        type: EventType,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.type = type
        self.description = description
    }

    var isMultiDay: Bool {
        endDate != nil
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let end = endDate {
            return "\(formatter.string(from: date)) - \(formatter.string(from: end))"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Grading Period

nonisolated struct GradingPeriod: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var termId: UUID
    var startDate: Date
    var endDate: Date
    var gradeSubmissionDeadline: Date

    init(
        id: UUID = UUID(),
        name: String,
        termId: UUID,
        startDate: Date,
        endDate: Date,
        gradeSubmissionDeadline: Date
    ) {
        self.id = id
        self.name = name
        self.termId = termId
        self.startDate = startDate
        self.endDate = endDate
        self.gradeSubmissionDeadline = gradeSubmissionDeadline
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var deadlinePassed: Bool {
        Date() > gradeSubmissionDeadline
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - Academic Calendar Config

nonisolated struct AcademicCalendarConfig: Sendable, Codable {
    var terms: [AcademicTerm]
    var events: [AcademicEvent]
    var gradingPeriods: [GradingPeriod]

    init(
        terms: [AcademicTerm] = [],
        events: [AcademicEvent] = [],
        gradingPeriods: [GradingPeriod] = []
    ) {
        self.terms = terms
        self.events = events
        self.gradingPeriods = gradingPeriods
    }

    var activeTerm: AcademicTerm? {
        terms.first(where: \.isActive)
    }

    var activeGradingPeriod: GradingPeriod? {
        gradingPeriods.first(where: \.isActive)
    }

    var upcomingEvents: [AcademicEvent] {
        let now = Date()
        return events.filter { $0.date >= now }.sorted { $0.date < $1.date }
    }

    func events(for date: Date) -> [AcademicEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            if calendar.isDate(event.date, inSameDayAs: date) {
                return true
            }
            if let endDate = event.endDate {
                return date >= event.date && date <= endDate
            }
            return false
        }
    }

    func term(for date: Date) -> AcademicTerm? {
        terms.first { date >= $0.startDate && date <= $0.endDate }
    }

    func gradingPeriods(for termId: UUID) -> [GradingPeriod] {
        gradingPeriods.filter { $0.termId == termId }.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Report Card Models

nonisolated struct ReportCardComment: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var studentId: UUID
    var courseId: UUID
    var termId: UUID
    var teacherId: UUID
    var comment: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        studentId: UUID,
        courseId: UUID,
        termId: UUID,
        teacherId: UUID,
        comment: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.studentId = studentId
        self.courseId = courseId
        self.termId = termId
        self.teacherId = teacherId
        self.comment = comment
        self.createdAt = createdAt
    }
}

nonisolated struct ReportCardEntry: Identifiable, Sendable {
    let id: UUID
    var studentId: UUID
    var studentName: String
    var termName: String
    var courseEntries: [ReportCardCourseEntry]
    var gpa: Double
    var attendanceSummary: ReportCardAttendance
    var overallComments: String?

    init(
        id: UUID = UUID(),
        studentId: UUID,
        studentName: String,
        termName: String,
        courseEntries: [ReportCardCourseEntry],
        gpa: Double,
        attendanceSummary: ReportCardAttendance,
        overallComments: String? = nil
    ) {
        self.id = id
        self.studentId = studentId
        self.studentName = studentName
        self.termName = termName
        self.courseEntries = courseEntries
        self.gpa = gpa
        self.attendanceSummary = attendanceSummary
        self.overallComments = overallComments
    }

    var letterGrade: String {
        switch gpa {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 60..<67: return "D"
        default: return "F"
        }
    }

    var standing: String {
        switch gpa {
        case 90...: return "Honor Roll"
        case 80..<90: return "Good Standing"
        case 70..<80: return "Satisfactory"
        default: return "Needs Improvement"
        }
    }
}

nonisolated struct ReportCardCourseEntry: Identifiable, Sendable {
    let id: UUID
    var courseId: UUID
    var courseName: String
    var teacherName: String
    var numericGrade: Double
    var letterGrade: String
    var teacherComment: String?

    init(
        id: UUID = UUID(),
        courseId: UUID,
        courseName: String,
        teacherName: String,
        numericGrade: Double,
        letterGrade: String,
        teacherComment: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.courseName = courseName
        self.teacherName = teacherName
        self.numericGrade = numericGrade
        self.letterGrade = letterGrade
        self.teacherComment = teacherComment
    }
}

nonisolated struct ReportCardAttendance: Sendable {
    var presentCount: Int
    var absentCount: Int
    var tardyCount: Int
    var excusedCount: Int

    var totalDays: Int {
        presentCount + absentCount + tardyCount + excusedCount
    }

    var attendanceRate: Double {
        guard totalDays > 0 else { return 100 }
        return Double(presentCount + excusedCount) / Double(totalDays) * 100
    }
}

// MARK: - Comment Template

nonisolated struct CommentTemplate: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var category: CommentCategory

    init(id: UUID = UUID(), text: String, category: CommentCategory) {
        self.id = id
        self.text = text
        self.category = category
    }
}

nonisolated enum CommentCategory: String, CaseIterable, Sendable, Identifiable {
    case positive = "Positive"
    case improvement = "Needs Improvement"
    case general = "General"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .positive: "hand.thumbsup.fill"
        case .improvement: "arrow.up.circle.fill"
        case .general: "text.bubble.fill"
        }
    }

    var colorName: String {
        switch self {
        case .positive: "green"
        case .improvement: "orange"
        case .general: "blue"
        }
    }
}
