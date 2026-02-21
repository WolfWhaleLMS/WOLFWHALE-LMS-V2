import Foundation

nonisolated struct Quiz: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var courseId: UUID
    var courseName: String
    var questions: [QuizQuestion]
    var timeLimit: Int            // from QuizDTO.timeLimitMinutes
    var dueDate: Date
    var isCompleted: Bool
    var score: Double?
    var xpReward: Int             // not directly in quizzes table; may come from app logic
}

nonisolated struct QuizQuestion: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var text: String              // from QuizQuestionDTO.questionText
    var options: [String]         // from quiz_options table, not directly on quiz_questions
    var correctIndex: Int         // derived from quiz_options.is_correct
}

/// View-facing Assignment model.
/// DB table `assignments` has `max_points` (not `points`) and `created_by` (not `teacher_id`).
/// The service layer bridges: `dto.maxPoints` -> `assignment.points`.
/// `xpReward` is not a direct DB column on assignments; populated by app logic.
/// `courseName`, `isSubmitted`, `submission`, `grade`, `feedback`, `studentName`
/// are all resolved by the service from joins/lookups.
nonisolated struct Assignment: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var courseId: UUID
    var courseName: String          // resolved from course_id -> courses.name
    var instructions: String
    var dueDate: Date               // from AssignmentDTO.dueDate
    var points: Int                 // from AssignmentDTO.maxPoints (DB: max_points)
    var isSubmitted: Bool           // derived from submissions table
    var submission: String?         // from SubmissionDTO.submissionText
    var grade: Double?              // from grades table (GradeDTO.pointsEarned or percentage)
    var feedback: String?           // from grades table
    var xpReward: Int               // app logic, not directly in assignments table
    var studentId: UUID? = nil      // from submissions, for teacher view
    var studentName: String? = nil  // resolved from student_id -> profiles

    var isOverdue: Bool {
        !isSubmitted && dueDate < Date()
    }

    var statusText: String {
        if isSubmitted {
            if let grade {
                return "Graded: \(Int(grade))%"
            }
            return "Submitted"
        }
        if isOverdue { return "Overdue" }
        return "Pending"
    }
}
