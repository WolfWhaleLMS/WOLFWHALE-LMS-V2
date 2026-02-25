import Foundation

// MARK: - Teacher Note Category

nonisolated enum NoteCategory: String, CaseIterable, Sendable, Identifiable, Codable, Hashable {
    case academic    = "Academic"
    case behavioral  = "Behavioral"
    case attendance  = "Attendance"
    case parent      = "Parent Communication"
    case general     = "General"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .academic:   "book.fill"
        case .behavioral: "exclamationmark.triangle.fill"
        case .attendance: "clock.fill"
        case .parent:     "figure.2.and.child.holdinghands"
        case .general:    "note.text"
        }
    }

    var color: String {
        switch self {
        case .academic:   "blue"
        case .behavioral: "orange"
        case .attendance: "purple"
        case .parent:     "green"
        case .general:    "gray"
        }
    }
}

// MARK: - Teacher Note

nonisolated struct TeacherNote: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var teacherId: UUID
    var studentId: UUID
    var courseId: UUID
    var content: String
    var category: NoteCategory
    var isPrivate: Bool
    var createdDate: Date
    var updatedDate: Date?

    init(
        id: UUID = UUID(),
        teacherId: UUID,
        studentId: UUID,
        courseId: UUID,
        content: String,
        category: NoteCategory = .general,
        isPrivate: Bool = true,
        createdDate: Date = Date(),
        updatedDate: Date? = nil
    ) {
        self.id = id
        self.teacherId = teacherId
        self.studentId = studentId
        self.courseId = courseId
        self.content = content
        self.category = category
        self.isPrivate = isPrivate
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
