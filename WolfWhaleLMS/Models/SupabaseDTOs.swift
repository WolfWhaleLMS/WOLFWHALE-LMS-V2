import Foundation

nonisolated struct CourseDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String?
    let teacherId: UUID?
    let iconSystemName: String?
    let colorName: String?
    let classCode: String?
    let createdAt: String?
    let tenantId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case teacherId = "teacher_id"
        case iconSystemName = "icon_system_name"
        case colorName = "color_name"
        case classCode = "class_code"
        case createdAt = "created_at"
        case tenantId = "tenant_id"
    }
}

nonisolated struct InsertCourseDTO: Encodable, Sendable {
    let title: String
    let description: String?
    let teacherId: UUID
    let iconSystemName: String
    let colorName: String
    let classCode: String
    let tenantId: UUID?

    enum CodingKeys: String, CodingKey {
        case title, description
        case teacherId = "teacher_id"
        case iconSystemName = "icon_system_name"
        case colorName = "color_name"
        case classCode = "class_code"
        case tenantId = "tenant_id"
    }
}

nonisolated struct ModuleDTO: Codable, Sendable {
    let id: UUID
    let courseId: UUID
    let title: String
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case courseId = "course_id"
        case orderIndex = "order_index"
    }
}

nonisolated struct InsertModuleDTO: Encodable, Sendable {
    let courseId: UUID
    let title: String
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case title
        case courseId = "course_id"
        case orderIndex = "order_index"
    }
}

nonisolated struct LessonDTO: Codable, Sendable {
    let id: UUID
    let moduleId: UUID
    let title: String
    let content: String?
    let duration: Int?
    let type: String?
    let xpReward: Int?
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, content, duration, type
        case moduleId = "module_id"
        case xpReward = "xp_reward"
        case orderIndex = "order_index"
    }
}

nonisolated struct LessonCompletionDTO: Codable, Sendable {
    let id: UUID?
    let studentId: UUID
    let lessonId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case lessonId = "lesson_id"
    }
}

nonisolated struct InsertLessonCompletionDTO: Encodable, Sendable {
    let studentId: UUID
    let lessonId: UUID

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case lessonId = "lesson_id"
    }
}

nonisolated struct EnrollmentDTO: Codable, Sendable {
    let id: UUID?
    let courseId: UUID
    let studentId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case studentId = "student_id"
    }
}

nonisolated struct AssignmentDTO: Codable, Sendable {
    let id: UUID
    let courseId: UUID
    let title: String
    let instructions: String?
    let dueDate: String?
    let points: Int?
    let xpReward: Int?
    let createdAt: String?
    let studentId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, instructions, points
        case courseId = "course_id"
        case dueDate = "due_date"
        case xpReward = "xp_reward"
        case createdAt = "created_at"
        case studentId = "student_id"
    }
}

nonisolated struct InsertAssignmentDTO: Encodable, Sendable {
    let courseId: UUID
    let title: String
    let instructions: String
    let dueDate: String
    let points: Int
    let xpReward: Int

    enum CodingKeys: String, CodingKey {
        case title, instructions, points
        case courseId = "course_id"
        case dueDate = "due_date"
        case xpReward = "xp_reward"
    }
}

nonisolated struct SubmissionDTO: Codable, Sendable {
    let id: UUID?
    let assignmentId: UUID
    let studentId: UUID
    let content: String?
    let grade: Double?
    let feedback: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content, grade, feedback
        case assignmentId = "assignment_id"
        case studentId = "student_id"
        case submittedAt = "submitted_at"
    }
}

nonisolated struct InsertSubmissionDTO: Encodable, Sendable {
    let assignmentId: UUID
    let studentId: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case content
        case assignmentId = "assignment_id"
        case studentId = "student_id"
    }
}

nonisolated struct QuizDTO: Codable, Sendable {
    let id: UUID
    let courseId: UUID
    let title: String
    let timeLimit: Int?
    let dueDate: String?
    let xpReward: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case courseId = "course_id"
        case timeLimit = "time_limit"
        case dueDate = "due_date"
        case xpReward = "xp_reward"
    }
}

nonisolated struct QuizQuestionDTO: Codable, Sendable {
    let id: UUID
    let quizId: UUID
    let text: String
    let options: [String]?
    let correctIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id, text, options
        case quizId = "quiz_id"
        case correctIndex = "correct_index"
    }
}

nonisolated struct QuizAttemptDTO: Codable, Sendable {
    let id: UUID?
    let quizId: UUID
    let studentId: UUID
    let score: Double?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, score
        case quizId = "quiz_id"
        case studentId = "student_id"
        case completedAt = "completed_at"
    }
}

nonisolated struct InsertQuizAttemptDTO: Encodable, Sendable {
    let quizId: UUID
    let studentId: UUID
    let score: Double

    enum CodingKeys: String, CodingKey {
        case score
        case quizId = "quiz_id"
        case studentId = "student_id"
    }
}

nonisolated struct GradeDTO: Codable, Sendable {
    let id: UUID
    let studentId: UUID
    let courseId: UUID
    let assignmentId: UUID?
    let score: Double?
    let maxScore: Double?
    let letterGrade: String?
    let type: String?
    let title: String?
    let gradedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, score, type, title
        case studentId = "student_id"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case maxScore = "max_score"
        case letterGrade = "letter_grade"
        case gradedAt = "graded_at"
    }
}

nonisolated struct AnnouncementDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let content: String?
    let authorId: UUID?
    let authorName: String?
    let isPinned: Bool?
    let createdAt: String?
    let tenantId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case authorId = "author_id"
        case authorName = "author_name"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case tenantId = "tenant_id"
    }
}

nonisolated struct InsertAnnouncementDTO: Encodable, Sendable {
    let title: String
    let content: String
    let authorId: UUID
    let authorName: String
    let isPinned: Bool
    let tenantId: UUID?

    enum CodingKeys: String, CodingKey {
        case title, content
        case authorId = "author_id"
        case authorName = "author_name"
        case isPinned = "is_pinned"
        case tenantId = "tenant_id"
    }
}

nonisolated struct ConversationDTO: Codable, Sendable {
    let id: UUID
    let title: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
    }
}

nonisolated struct ConversationParticipantDTO: Codable, Sendable {
    let id: UUID?
    let conversationId: UUID
    let userId: UUID
    let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case unreadCount = "unread_count"
    }
}

nonisolated struct MessageDTO: Codable, Sendable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let senderName: String?
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertMessageDTO: Encodable, Sendable {
    let conversationId: UUID
    let senderId: UUID
    let senderName: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case content
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
    }
}

nonisolated struct AchievementDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String?
    let iconSystemName: String?
    let xpReward: Int?
    let rarity: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, rarity
        case iconSystemName = "icon_system_name"
        case xpReward = "xp_reward"
    }
}

nonisolated struct StudentAchievementDTO: Codable, Sendable {
    let id: UUID?
    let studentId: UUID
    let achievementId: UUID
    let unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

nonisolated struct LeaderboardEntryDTO: Codable, Sendable {
    let userId: UUID?
    let userName: String?
    let xp: Int?
    let level: Int?
    let rank: Int?

    enum CodingKeys: String, CodingKey {
        case xp, level, rank
        case userId = "user_id"
        case userName = "user_name"
    }
}

nonisolated struct AttendanceDTO: Codable, Sendable {
    let id: UUID
    let studentId: UUID
    let courseId: UUID?
    let status: String
    let date: String?
    let courseName: String?

    enum CodingKeys: String, CodingKey {
        case id, status, date
        case studentId = "student_id"
        case courseId = "course_id"
        case courseName = "course_name"
    }
}

nonisolated struct ParentChildDTO: Codable, Sendable {
    let id: UUID?
    let parentId: UUID
    let childId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case childId = "child_id"
    }
}

nonisolated struct SchoolMetricsDTO: Codable, Sendable {
    let totalStudents: Int?
    let totalTeachers: Int?
    let totalCourses: Int?
    let averageAttendance: Double?
    let averageGpa: Double?
    let activeUsers: Int?

    enum CodingKeys: String, CodingKey {
        case totalStudents = "total_students"
        case totalTeachers = "total_teachers"
        case totalCourses = "total_courses"
        case averageAttendance = "average_attendance"
        case averageGpa = "average_gpa"
        case activeUsers = "active_users"
    }
}

// MARK: - Insert DTOs

nonisolated struct InsertLessonDTO: Encodable, Sendable {
    let moduleId: UUID
    let title: String
    let content: String
    let duration: Int
    let type: String
    let xpReward: Int
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case title, content, duration, type
        case moduleId = "module_id"
        case xpReward = "xp_reward"
        case orderIndex = "order_index"
    }
}

nonisolated struct InsertQuizDTO: Encodable, Sendable {
    let courseId: UUID
    let title: String
    let timeLimit: Int
    let dueDate: String?
    let xpReward: Int

    enum CodingKeys: String, CodingKey {
        case title
        case courseId = "course_id"
        case timeLimit = "time_limit"
        case dueDate = "due_date"
        case xpReward = "xp_reward"
    }
}

nonisolated struct InsertQuizQuestionDTO: Encodable, Sendable {
    let quizId: UUID
    let text: String
    let options: [String]
    let correctIndex: Int

    enum CodingKeys: String, CodingKey {
        case text, options
        case quizId = "quiz_id"
        case correctIndex = "correct_index"
    }
}

nonisolated struct InsertGradeDTO: Encodable, Sendable {
    let studentId: UUID
    let courseId: UUID
    let assignmentId: UUID
    let score: Double
    let maxScore: Double
    let letterGrade: String
    let feedback: String
    let gradedAt: String?

    enum CodingKeys: String, CodingKey {
        case score, feedback
        case studentId = "student_id"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case maxScore = "max_score"
        case letterGrade = "letter_grade"
        case gradedAt = "graded_at"
    }
}

nonisolated struct InsertAttendanceDTO: Encodable, Sendable {
    let studentId: UUID
    let courseId: UUID
    let courseName: String
    let date: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case date, status
        case studentId = "student_id"
        case courseId = "course_id"
        case courseName = "course_name"
    }
}

nonisolated struct InsertConversationDTO: Encodable, Sendable {
    let title: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case title
        case createdAt = "created_at"
    }
}

nonisolated struct InsertConversationParticipantDTO: Encodable, Sendable {
    let conversationId: UUID
    let userId: UUID
    let userName: String
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case userName = "user_name"
        case unreadCount = "unread_count"
    }
}

nonisolated struct InsertEnrollmentDTO: Encodable, Sendable {
    let studentId: UUID
    let courseId: UUID
    let enrolledAt: String?

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
    }
}

nonisolated struct InsertStudentAchievementDTO: Encodable, Sendable {
    let studentId: UUID
    let achievementId: UUID
    let unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

// MARK: - Update DTOs

nonisolated struct UpdateCourseDTO: Encodable, Sendable {
    let title: String?
    let description: String?
    let colorName: String?
    let iconSystemName: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case colorName = "color_name"
        case iconSystemName = "icon_system_name"
    }
}

nonisolated struct UpdateAssignmentDTO: Encodable, Sendable {
    let title: String?
    let instructions: String?
    let dueDate: String?
    let points: Int?

    enum CodingKeys: String, CodingKey {
        case title, instructions, points
        case dueDate = "due_date"
    }
}

nonisolated struct UpdateGradeDTO: Encodable, Sendable {
    let score: Double?
    let letterGrade: String?
    let feedback: String?
    let gradedAt: String?

    enum CodingKeys: String, CodingKey {
        case score, feedback
        case letterGrade = "letter_grade"
        case gradedAt = "graded_at"
    }
}

nonisolated struct UpdateAnnouncementDTO: Encodable, Sendable {
    let title: String?
    let content: String?
    let isPinned: Bool?

    enum CodingKeys: String, CodingKey {
        case title, content
        case isPinned = "is_pinned"
    }
}
