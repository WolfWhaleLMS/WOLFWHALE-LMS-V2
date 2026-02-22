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
