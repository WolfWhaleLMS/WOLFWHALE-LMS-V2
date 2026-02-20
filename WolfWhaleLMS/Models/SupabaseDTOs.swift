import Foundation

// =============================================================================
// SupabaseDTOs.swift
// All DTOs map exactly to the Supabase database column names via CodingKeys.
// =============================================================================

// MARK: - Courses (courses)
// Columns: id, tenant_id, name, description, subject, grade_level, created_by,
//          semester, start_date, end_date, syllabus_url, credits, status,
//          created_at, updated_at, archived_at

nonisolated struct CourseDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let name: String
    let description: String?
    let subject: String?
    let gradeLevel: String?
    let createdBy: UUID?
    let semester: String?
    let startDate: String?
    let endDate: String?
    let syllabusUrl: String?
    let credits: Double?
    let status: String?
    let createdAt: String?
    let updatedAt: String?
    let archivedAt: String?
    let iconSystemName: String?
    let colorName: String?

    // Convenience aliases: views/service code use `dto.title` and `dto.teacherId`
    var title: String { name }
    var teacherId: UUID? { createdBy }

    enum CodingKeys: String, CodingKey {
        case id, name, description, subject, semester, credits, status
        case tenantId = "tenant_id"
        case gradeLevel = "grade_level"
        case createdBy = "created_by"
        case startDate = "start_date"
        case endDate = "end_date"
        case syllabusUrl = "syllabus_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
        case iconSystemName = "icon_system_name"
        case colorName = "color_name"
    }
}

nonisolated struct InsertCourseDTO: Encodable, Sendable {
    let tenantId: UUID?
    let name: String
    let description: String?
    let subject: String?
    let gradeLevel: String?
    let createdBy: UUID?
    let semester: String?
    let startDate: String?
    let endDate: String?
    let syllabusUrl: String?
    let credits: Double?
    let status: String?
    let iconSystemName: String?
    let colorName: String?

    enum CodingKeys: String, CodingKey {
        case name, description, subject, semester, credits, status
        case tenantId = "tenant_id"
        case gradeLevel = "grade_level"
        case createdBy = "created_by"
        case startDate = "start_date"
        case endDate = "end_date"
        case syllabusUrl = "syllabus_url"
        case iconSystemName = "icon_system_name"
        case colorName = "color_name"
    }
}

nonisolated struct UpdateCourseDTO: Encodable, Sendable {
    let name: String?
    let description: String?
    let subject: String?
    let gradeLevel: String?
    let semester: String?
    let startDate: String?
    let endDate: String?
    let syllabusUrl: String?
    let credits: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case name, description, subject, semester, credits, status
        case gradeLevel = "grade_level"
        case startDate = "start_date"
        case endDate = "end_date"
        case syllabusUrl = "syllabus_url"
    }
}

// MARK: - Modules (modules)
// Columns: id, tenant_id, course_id, created_by, title, description,
//          order_index, status, created_at, updated_at

nonisolated struct ModuleDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID
    let createdBy: UUID?
    let title: String
    let description: String?
    let orderIndex: Int?
    let status: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case orderIndex = "order_index"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertModuleDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let createdBy: UUID?
    let title: String
    let description: String?
    let orderIndex: Int
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, description, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case orderIndex = "order_index"
    }
}

// MARK: - Lessons (lessons)
// Columns: id, tenant_id, course_id, title, description, content, order_index,
//          created_by, status, published_at, created_at, updated_at, module_id

nonisolated struct LessonDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID?
    let title: String
    let description: String?
    let content: String?
    let orderIndex: Int?
    let createdBy: UUID?
    let status: String?
    let publishedAt: String?
    let createdAt: String?
    let updatedAt: String?
    let moduleId: UUID?

    // These properties are not in the DB but the service/views expect them.
    // Provide stubs with defaults so model construction still works.
    var duration: Int? { nil }
    var type: String? { nil }
    var xpReward: Int? { nil }

    enum CodingKeys: String, CodingKey {
        case id, title, description, content, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case orderIndex = "order_index"
        case createdBy = "created_by"
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case moduleId = "module_id"
    }
}

nonisolated struct InsertLessonDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID?
    let title: String
    let description: String?
    let content: String?
    let orderIndex: Int
    let createdBy: UUID?
    let status: String?
    let moduleId: UUID?

    enum CodingKeys: String, CodingKey {
        case title, description, content, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case orderIndex = "order_index"
        case createdBy = "created_by"
        case moduleId = "module_id"
    }
}

// MARK: - Course Enrollments (course_enrollments)
// Columns: id, tenant_id, course_id, student_id, teacher_id, status,
//          grade_letter, grade_numeric, enrolled_at, completed_at

nonisolated struct EnrollmentDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let courseId: UUID
    let studentId: UUID
    let teacherId: UUID?
    let status: String?
    let gradeLetter: String?
    let gradeNumeric: Double?
    let enrolledAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case studentId = "student_id"
        case teacherId = "teacher_id"
        case gradeLetter = "grade_letter"
        case gradeNumeric = "grade_numeric"
        case enrolledAt = "enrolled_at"
        case completedAt = "completed_at"
    }
}

nonisolated struct InsertEnrollmentDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let studentId: UUID
    let teacherId: UUID?
    let status: String?
    let enrolledAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case studentId = "student_id"
        case teacherId = "teacher_id"
        case enrolledAt = "enrolled_at"
    }
}

// MARK: - Assignments (assignments)
// Columns: id, tenant_id, course_id, title, description, instructions, type,
//          created_by, due_date, available_date, max_points, submission_type,
//          allow_late_submission, late_submission_days, status, created_at,
//          updated_at, attachments, questions

nonisolated struct AssignmentDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID
    let title: String
    let description: String?
    let instructions: String?
    let type: String?
    let createdBy: UUID?
    let dueDate: String?
    let availableDate: String?
    let maxPoints: Int?
    let submissionType: String?
    let allowLateSubmission: Bool?
    let lateSubmissionDays: Int?
    let status: String?
    let createdAt: String?
    let updatedAt: String?
    let attachments: String?
    let questions: String?

    // Convenience aliases: service code references `dto.points` and `dto.xpReward`
    var points: Int? { maxPoints }
    // xpReward is NOT a DB column; stub for compatibility
    var xpReward: Int? { nil }

    enum CodingKeys: String, CodingKey {
        case id, title, description, instructions, type, status, attachments, questions
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case dueDate = "due_date"
        case availableDate = "available_date"
        case maxPoints = "max_points"
        case submissionType = "submission_type"
        case allowLateSubmission = "allow_late_submission"
        case lateSubmissionDays = "late_submission_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertAssignmentDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let title: String
    let description: String?
    let instructions: String?
    let type: String?
    let createdBy: UUID?
    let dueDate: String?
    let availableDate: String?
    let maxPoints: Int
    let submissionType: String?
    let allowLateSubmission: Bool?
    let lateSubmissionDays: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, description, instructions, type, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case dueDate = "due_date"
        case availableDate = "available_date"
        case maxPoints = "max_points"
        case submissionType = "submission_type"
        case allowLateSubmission = "allow_late_submission"
        case lateSubmissionDays = "late_submission_days"
    }
}

nonisolated struct UpdateAssignmentDTO: Encodable, Sendable {
    let title: String?
    let description: String?
    let instructions: String?
    let type: String?
    let dueDate: String?
    let availableDate: String?
    let maxPoints: Int?
    let submissionType: String?
    let allowLateSubmission: Bool?
    let lateSubmissionDays: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, description, instructions, type, status
        case dueDate = "due_date"
        case availableDate = "available_date"
        case maxPoints = "max_points"
        case submissionType = "submission_type"
        case allowLateSubmission = "allow_late_submission"
        case lateSubmissionDays = "late_submission_days"
    }
}

// MARK: - Submissions (submissions)
// Columns: id, tenant_id, assignment_id, student_id, submission_text, file_path,
//          submission_url, status, submitted_at, submitted_late, graded_at,
//          graded_by, updated_at

nonisolated struct SubmissionDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let assignmentId: UUID
    let studentId: UUID
    let submissionText: String?
    let filePath: String?
    let submissionUrl: String?
    let status: String?
    let submittedAt: String?
    let submittedLate: Bool?
    let gradedAt: String?
    let gradedBy: UUID?
    let updatedAt: String?

    // Convenience alias: service code references `sub.content`
    var content: String? { submissionText }
    // grade and feedback live in the "grades" table, not submissions.
    // Provide nil stubs so existing callers still compile.
    var grade: Double? { nil }
    var feedback: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, status
        case tenantId = "tenant_id"
        case assignmentId = "assignment_id"
        case studentId = "student_id"
        case submissionText = "submission_text"
        case filePath = "file_path"
        case submissionUrl = "submission_url"
        case submittedAt = "submitted_at"
        case submittedLate = "submitted_late"
        case gradedAt = "graded_at"
        case gradedBy = "graded_by"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertSubmissionDTO: Encodable, Sendable {
    let tenantId: UUID?
    let assignmentId: UUID
    let studentId: UUID
    let submissionText: String?
    let filePath: String?
    let submissionUrl: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case status
        case tenantId = "tenant_id"
        case assignmentId = "assignment_id"
        case studentId = "student_id"
        case submissionText = "submission_text"
        case filePath = "file_path"
        case submissionUrl = "submission_url"
    }
}

// MARK: - Grades (grades)
// Columns: id, tenant_id, submission_id, assignment_id, student_id, course_id,
//          points_earned, percentage, letter_grade, feedback, graded_by,
//          graded_at, updated_at

nonisolated struct GradeDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let submissionId: UUID?
    let assignmentId: UUID?
    let studentId: UUID
    let courseId: UUID
    let pointsEarned: Double?
    let percentage: Double?
    let letterGrade: String?
    let feedback: String?
    let gradedBy: UUID?
    let gradedAt: String?
    let updatedAt: String?

    // Convenience aliases for service code that used old property names
    var score: Double? { pointsEarned }
    var maxScore: Double? { nil }       // not in grades table; stub for compatibility
    var type: String? { nil }           // not in grades table; stub for compatibility
    var title: String? { nil }          // not in grades table; stub for compatibility

    enum CodingKeys: String, CodingKey {
        case id, feedback
        case tenantId = "tenant_id"
        case submissionId = "submission_id"
        case assignmentId = "assignment_id"
        case studentId = "student_id"
        case courseId = "course_id"
        case pointsEarned = "points_earned"
        case percentage = "percentage"
        case letterGrade = "letter_grade"
        case gradedBy = "graded_by"
        case gradedAt = "graded_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertGradeDTO: Encodable, Sendable {
    let tenantId: UUID?
    let submissionId: UUID?
    let assignmentId: UUID?
    let studentId: UUID
    let courseId: UUID
    let pointsEarned: Double?
    let percentage: Double?
    let letterGrade: String?
    let feedback: String?
    let gradedBy: UUID?
    let gradedAt: String?

    enum CodingKeys: String, CodingKey {
        case feedback
        case tenantId = "tenant_id"
        case submissionId = "submission_id"
        case assignmentId = "assignment_id"
        case studentId = "student_id"
        case courseId = "course_id"
        case pointsEarned = "points_earned"
        case percentage = "percentage"
        case letterGrade = "letter_grade"
        case gradedBy = "graded_by"
        case gradedAt = "graded_at"
    }
}

nonisolated struct UpdateGradeDTO: Encodable, Sendable {
    let pointsEarned: Double?
    let percentage: Double?
    let letterGrade: String?
    let feedback: String?
    let gradedBy: UUID?
    let gradedAt: String?

    enum CodingKeys: String, CodingKey {
        case feedback
        case pointsEarned = "points_earned"
        case percentage = "percentage"
        case letterGrade = "letter_grade"
        case gradedBy = "graded_by"
        case gradedAt = "graded_at"
    }
}

// MARK: - Quizzes (quizzes)
// Columns: id, tenant_id, course_id, assignment_id, title, description,
//          time_limit_minutes, shuffle_questions, shuffle_answers, show_results,
//          max_attempts, passing_score, status, created_by, created_at, updated_at

nonisolated struct QuizDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID
    let assignmentId: UUID?
    let title: String
    let description: String?
    let timeLimitMinutes: Int?
    let shuffleQuestions: Bool?
    let shuffleAnswers: Bool?
    let showResults: Bool?
    let maxAttempts: Int?
    let passingScore: Double?
    let status: String?
    let createdBy: UUID?
    let createdAt: String?
    let updatedAt: String?

    // Convenience aliases for service code
    var timeLimit: Int? { timeLimitMinutes }
    var dueDate: String? { nil }    // quizzes don't have due_date; stub for compatibility
    var xpReward: Int? { nil }      // not in quizzes table; stub for compatibility

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case timeLimitMinutes = "time_limit_minutes"
        case shuffleQuestions = "shuffle_questions"
        case shuffleAnswers = "shuffle_answers"
        case showResults = "show_results"
        case maxAttempts = "max_attempts"
        case passingScore = "passing_score"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertQuizDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let assignmentId: UUID?
    let title: String
    let description: String?
    let timeLimitMinutes: Int?
    let shuffleQuestions: Bool?
    let shuffleAnswers: Bool?
    let showResults: Bool?
    let maxAttempts: Int?
    let passingScore: Double?
    let status: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case title, description, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case timeLimitMinutes = "time_limit_minutes"
        case shuffleQuestions = "shuffle_questions"
        case shuffleAnswers = "shuffle_answers"
        case showResults = "show_results"
        case maxAttempts = "max_attempts"
        case passingScore = "passing_score"
        case createdBy = "created_by"
    }
}

// MARK: - Quiz Questions (quiz_questions)
// Columns: id, quiz_id, type, question_text, points, order_index,
//          explanation, created_at

nonisolated struct QuizQuestionDTO: Codable, Sendable {
    let id: UUID
    let quizId: UUID
    let type: String?
    let questionText: String
    let points: Double?
    let orderIndex: Int?
    let explanation: String?
    let createdAt: String?

    // Convenience alias: service code references `dto.text`
    var text: String { questionText }

    enum CodingKeys: String, CodingKey {
        case id, type, points, explanation
        case quizId = "quiz_id"
        case questionText = "question_text"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertQuizQuestionDTO: Encodable, Sendable {
    let quizId: UUID
    let type: String?
    let questionText: String
    let points: Double?
    let orderIndex: Int?
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case type, points, explanation
        case quizId = "quiz_id"
        case questionText = "question_text"
        case orderIndex = "order_index"
    }
}

// MARK: - Quiz Options (quiz_options)
// Columns: id, question_id, option_text, is_correct, order_index

nonisolated struct QuizOptionDTO: Codable, Sendable {
    let id: UUID
    let questionId: UUID
    let optionText: String
    let isCorrect: Bool?
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case optionText = "option_text"
        case isCorrect = "is_correct"
        case orderIndex = "order_index"
    }
}

nonisolated struct InsertQuizOptionDTO: Encodable, Sendable {
    let questionId: UUID
    let optionText: String
    let isCorrect: Bool
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case optionText = "option_text"
        case isCorrect = "is_correct"
        case orderIndex = "order_index"
    }
}

// MARK: - Quiz Attempts (quiz_attempts)
// Columns: id, quiz_id, student_id, tenant_id, started_at, completed_at,
//          score, total_points, percentage, passed, attempt_number

nonisolated struct QuizAttemptDTO: Codable, Sendable {
    let id: UUID?
    let quizId: UUID
    let studentId: UUID
    let tenantId: UUID?
    let startedAt: String?
    let completedAt: String?
    let score: Double?
    let totalPoints: Double?
    let percentage: Double?
    let passed: Bool?
    let attemptNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, score, passed, percentage
        case quizId = "quiz_id"
        case studentId = "student_id"
        case tenantId = "tenant_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case totalPoints = "total_points"
        case attemptNumber = "attempt_number"
    }
}

nonisolated struct InsertQuizAttemptDTO: Encodable, Sendable {
    let quizId: UUID
    let studentId: UUID
    let tenantId: UUID?
    let score: Double?
    let totalPoints: Double?
    let percentage: Double?
    let passed: Bool?
    let attemptNumber: Int?

    enum CodingKeys: String, CodingKey {
        case score, passed, percentage
        case quizId = "quiz_id"
        case studentId = "student_id"
        case tenantId = "tenant_id"
        case totalPoints = "total_points"
        case attemptNumber = "attempt_number"
    }
}

// MARK: - Quiz Answers (quiz_answers)
// Columns: id, attempt_id, question_id, selected_option_id, answer_text,
//          is_correct, points_earned

nonisolated struct QuizAnswerDTO: Codable, Sendable {
    let id: UUID
    let attemptId: UUID
    let questionId: UUID
    let selectedOptionId: UUID?
    let answerText: String?
    let isCorrect: Bool?
    let pointsEarned: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case attemptId = "attempt_id"
        case questionId = "question_id"
        case selectedOptionId = "selected_option_id"
        case answerText = "answer_text"
        case isCorrect = "is_correct"
        case pointsEarned = "points_earned"
    }
}

nonisolated struct InsertQuizAnswerDTO: Encodable, Sendable {
    let attemptId: UUID
    let questionId: UUID
    let selectedOptionId: UUID?
    let answerText: String?
    let isCorrect: Bool?
    let pointsEarned: Double?

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case questionId = "question_id"
        case selectedOptionId = "selected_option_id"
        case answerText = "answer_text"
        case isCorrect = "is_correct"
        case pointsEarned = "points_earned"
    }
}

// MARK: - Attendance Records (attendance_records)
// Columns: id, tenant_id, course_id, student_id, attendance_date, status,
//          notes, marked_by, created_at

nonisolated struct AttendanceDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID?
    let studentId: UUID
    let attendanceDate: String?
    let status: String
    let notes: String?
    let markedBy: UUID?
    let createdAt: String?

    // Convenience alias: service code references `dto.date`
    var date: String? { attendanceDate }
    // courseName is not in DB; resolved from course_id -> courses.name by service
    var courseName: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, status, notes
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case studentId = "student_id"
        case attendanceDate = "attendance_date"
        case markedBy = "marked_by"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertAttendanceDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let studentId: UUID
    let attendanceDate: String?
    let status: String
    let notes: String?
    let markedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case status, notes
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case studentId = "student_id"
        case attendanceDate = "attendance_date"
        case markedBy = "marked_by"
    }
}

// MARK: - Announcements (announcements)
// Columns: id, tenant_id, course_id, title, content, created_by,
//          published_at, expires_at, status, created_at

nonisolated struct AnnouncementDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let courseId: UUID?
    let title: String
    let content: String?
    let createdBy: UUID?
    let publishedAt: String?
    let expiresAt: String?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case publishedAt = "published_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertAnnouncementDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID?
    let title: String
    let content: String
    let createdBy: UUID?
    let publishedAt: String?
    let expiresAt: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, content, status
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case createdBy = "created_by"
        case publishedAt = "published_at"
        case expiresAt = "expires_at"
    }
}

nonisolated struct UpdateAnnouncementDTO: Encodable, Sendable {
    let title: String?
    let content: String?
    let status: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case title, content, status
        case expiresAt = "expires_at"
    }
}

// MARK: - Conversations (conversations)
// Columns: id, tenant_id, type, subject, created_by, course_id,
//          created_at, updated_at

nonisolated struct ConversationDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let type: String?
    let subject: String?
    let createdBy: UUID?
    let courseId: UUID?
    let createdAt: String?
    let updatedAt: String?

    // Convenience alias: service code references `dto.title`
    var title: String? { subject }

    enum CodingKeys: String, CodingKey {
        case id, type, subject
        case tenantId = "tenant_id"
        case createdBy = "created_by"
        case courseId = "course_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct InsertConversationDTO: Encodable, Sendable {
    let tenantId: UUID?
    let type: String?
    let subject: String?
    let createdBy: UUID?
    let courseId: UUID?

    enum CodingKeys: String, CodingKey {
        case type, subject
        case tenantId = "tenant_id"
        case createdBy = "created_by"
        case courseId = "course_id"
    }
}

// MARK: - Conversation Members (conversation_members)
// Columns: id, conversation_id, user_id, joined_at

nonisolated struct ConversationMemberDTO: Codable, Sendable {
    let id: UUID?
    let conversationId: UUID
    let userId: UUID
    let joinedAt: String?

    // unread_count does not exist on conversation_members; use message_read_receipts instead.
    // Stub so existing service callers still compile.
    var unreadCount: Int? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

// Backward compatibility alias for service code that references the old name
typealias ConversationParticipantDTO = ConversationMemberDTO

nonisolated struct InsertConversationMemberDTO: Encodable, Sendable {
    let conversationId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
    }
}

// Backward compatibility alias for service code that references the old name
typealias InsertConversationParticipantDTO = InsertConversationMemberDTO

// MARK: - Messages (messages)
// Columns: id, tenant_id, conversation_id, sender_id, content, attachments,
//          edited_at, deleted_at, created_at

nonisolated struct MessageDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let conversationId: UUID
    let senderId: UUID
    let content: String
    let attachments: String?
    let editedAt: String?
    let deletedAt: String?
    let createdAt: String?

    // sender_name is not a DB column; must be resolved from sender_id -> profiles.
    // Stub so existing service code that reads `dto.senderName` still compiles.
    var senderName: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, content, attachments
        case tenantId = "tenant_id"
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case editedAt = "edited_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertMessageDTO: Encodable, Sendable {
    let tenantId: UUID?
    let conversationId: UUID
    let senderId: UUID
    let content: String
    let attachments: String?

    enum CodingKeys: String, CodingKey {
        case content, attachments
        case tenantId = "tenant_id"
        case conversationId = "conversation_id"
        case senderId = "sender_id"
    }
}

// MARK: - Student Achievements (student_achievements)
// Columns: id, tenant_id, student_id, achievement_id, unlocked_at, displayed

nonisolated struct StudentAchievementDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let studentId: UUID
    let achievementId: UUID
    let unlockedAt: String?
    let displayed: Bool?

    enum CodingKeys: String, CodingKey {
        case id, displayed
        case tenantId = "tenant_id"
        case studentId = "student_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

nonisolated struct InsertStudentAchievementDTO: Encodable, Sendable {
    let tenantId: UUID?
    let studentId: UUID
    let achievementId: UUID
    let displayed: Bool?

    enum CodingKeys: String, CodingKey {
        case displayed
        case tenantId = "tenant_id"
        case studentId = "student_id"
        case achievementId = "achievement_id"
    }
}

// MARK: - Achievements (achievements)
// Columns: id, tenant_id, name, description, icon, category, tier, criteria,
//          xp_reward, coin_reward, is_global, created_by, created_at

nonisolated struct AchievementDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let name: String
    let description: String?
    let icon: String?
    let category: String?
    let tier: String?
    let criteria: String?
    let xpReward: Int?
    let coinReward: Int?
    let isGlobal: Bool?
    let createdBy: UUID?
    let createdAt: String?

    // Convenience aliases for service code that used the old property names
    var title: String { name }
    var iconSystemName: String? { icon }
    var rarity: String? { tier }

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, category, tier, criteria
        case tenantId = "tenant_id"
        case xpReward = "xp_reward"
        case coinReward = "coin_reward"
        case isGlobal = "is_global"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

// MARK: - Student Parents (student_parents)
// Columns: id, tenant_id, student_id, parent_id, relationship, status,
//          created_at, consent_given, consent_date, consent_method

nonisolated struct StudentParentDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let studentId: UUID
    let parentId: UUID
    let relationship: String?
    let status: String?
    let createdAt: String?
    let consentGiven: Bool?
    let consentDate: String?
    let consentMethod: String?

    // Convenience alias: old code used `childId`
    var childId: UUID { studentId }

    enum CodingKeys: String, CodingKey {
        case id, relationship, status
        case tenantId = "tenant_id"
        case studentId = "student_id"
        case parentId = "parent_id"
        case createdAt = "created_at"
        case consentGiven = "consent_given"
        case consentDate = "consent_date"
        case consentMethod = "consent_method"
    }
}

// Backward compatibility alias for service code
typealias ParentChildDTO = StudentParentDTO

// MARK: - Leaderboard Entries (leaderboard_entries)
// Columns: id, tenant_id, user_id, scope, scope_id, period, period_start,
//          xp_total, rank, updated_at

nonisolated struct LeaderboardEntryDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let userId: UUID?
    let scope: String?
    let scopeId: UUID?
    let period: String?
    let periodStart: String?
    let xpTotal: Int?
    let rank: Int?
    let updatedAt: String?

    // Convenience aliases for service code that used the old property names
    var xp: Int? { xpTotal }
    // userName and level must be resolved from profiles/student_xp; stub for compilation
    var userName: String? { nil }
    var level: Int? { nil }

    enum CodingKeys: String, CodingKey {
        case id, scope, period, rank
        case tenantId = "tenant_id"
        case userId = "user_id"
        case scopeId = "scope_id"
        case periodStart = "period_start"
        case xpTotal = "xp_total"
        case updatedAt = "updated_at"
    }
}

// MARK: - Notifications (notifications)
// Columns: id, tenant_id, user_id, type, title, message, action_url,
//          course_id, assignment_id, message_id, read, read_at, created_at

nonisolated struct NotificationDTO: Codable, Sendable {
    let id: UUID
    let tenantId: UUID?
    let userId: UUID
    let type: String?
    let title: String?
    let message: String?
    let actionUrl: String?
    let courseId: UUID?
    let assignmentId: UUID?
    let messageId: UUID?
    let read: Bool?
    let readAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, read
        case tenantId = "tenant_id"
        case userId = "user_id"
        case actionUrl = "action_url"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case messageId = "message_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertNotificationDTO: Encodable, Sendable {
    let tenantId: UUID?
    let userId: UUID
    let type: String?
    let title: String?
    let message: String?
    let actionUrl: String?
    let courseId: UUID?
    let assignmentId: UUID?
    let messageId: UUID?

    enum CodingKeys: String, CodingKey {
        case type, title, message
        case tenantId = "tenant_id"
        case userId = "user_id"
        case actionUrl = "action_url"
        case courseId = "course_id"
        case assignmentId = "assignment_id"
        case messageId = "message_id"
    }
}

// MARK: - Legacy / Computed DTOs

// MARK: - Lesson Completions (lesson_completions)
// Columns: id, student_id, lesson_id, course_id, tenant_id, completed_at, created_at

nonisolated struct LessonCompletionDTO: Codable, Sendable {
    let id: UUID
    let studentId: UUID
    let lessonId: UUID
    let courseId: UUID
    let tenantId: UUID
    let completedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case lessonId = "lesson_id"
        case courseId = "course_id"
        case tenantId = "tenant_id"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertLessonCompletionDTO: Encodable, Sendable {
    let studentId: UUID
    let lessonId: UUID
    let courseId: UUID
    let tenantId: UUID

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case lessonId = "lesson_id"
        case courseId = "course_id"
        case tenantId = "tenant_id"
    }
}

/// SchoolMetricsDTO is used for computed/aggregate data, not a direct table mapping.
/// Kept for view compatibility.
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
