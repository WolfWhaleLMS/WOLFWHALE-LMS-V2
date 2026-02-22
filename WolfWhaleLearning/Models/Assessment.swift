import Foundation

// MARK: - Rubric

/// A performance level within a rubric criterion (e.g. "Excellent", "Good", "Needs Work").
nonisolated struct RubricLevel: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var label: String          // e.g. "Excellent"
    var description: String    // what earning this level looks like
    var points: Int            // points awarded for this level
}

/// A single criterion row in a rubric (e.g. "Thesis Clarity", "Code Quality").
nonisolated struct RubricCriterion: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var description: String
    var maxPoints: Int
    var levels: [RubricLevel]
}

/// A reusable grading rubric that can be attached to assignments.
nonisolated struct Rubric: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var courseId: UUID
    var criteria: [RubricCriterion]
    var createdAt: Date

    /// Total points across all criteria (sum of each criterion's maxPoints).
    var totalPoints: Int {
        criteria.reduce(0) { $0 + $1.maxPoints }
    }
}

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

// MARK: - Quiz Question Type (View-facing)

nonisolated enum QuizQuestionType: String, Codable, CaseIterable, Sendable, Hashable {
    case multipleChoice = "multiple_choice"
    case trueFalse      = "true_false"
    case fillInBlank    = "fill_in_blank"
    case matching       = "matching"
    case essay          = "essay"

    var displayName: String {
        switch self {
        case .multipleChoice: "Multiple Choice"
        case .trueFalse:      "True / False"
        case .fillInBlank:    "Fill in the Blank"
        case .matching:       "Matching"
        case .essay:          "Essay"
        }
    }

    var iconName: String {
        switch self {
        case .multipleChoice: "list.bullet.circle.fill"
        case .trueFalse:      "checkmark.circle.fill"
        case .fillInBlank:    "rectangle.and.pencil.and.ellipsis"
        case .matching:       "arrow.left.arrow.right"
        case .essay:          "doc.text.fill"
        }
    }

    /// Whether this question type can be auto-graded.
    var isAutoGradable: Bool {
        switch self {
        case .multipleChoice, .trueFalse, .fillInBlank: true
        case .matching, .essay: false
        }
    }
}

// MARK: - Matching Pair

nonisolated struct MatchingPair: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var prompt: String      // left-hand side
    var answer: String      // right-hand side (correct match)

    init(id: UUID = UUID(), prompt: String = "", answer: String = "") {
        self.id = id
        self.prompt = prompt
        self.answer = answer
    }
}

nonisolated struct QuizQuestion: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var text: String                         // from QuizQuestionDTO.questionText
    var questionType: QuizQuestionType       // type of question
    var options: [String]                    // MC / T-F option texts
    var correctIndex: Int                    // MC / T-F correct option index
    var acceptedAnswers: [String]            // fill-in-blank accepted answers (case-insensitive match)
    var matchingPairs: [MatchingPair]        // matching question pairs
    var essayPrompt: String                  // additional essay instructions
    var essayMinWords: Int                   // minimum word count for essay
    var needsManualReview: Bool              // flagged for teacher grading (essay, matching)
    var explanation: String                  // shown after answering

    /// Backwards-compatible init that defaults to multipleChoice when no type is specified.
    init(
        id: UUID,
        text: String,
        options: [String],
        correctIndex: Int
    ) {
        self.id = id
        self.text = text
        self.questionType = .multipleChoice
        self.options = options
        self.correctIndex = correctIndex
        self.acceptedAnswers = []
        self.matchingPairs = []
        self.essayPrompt = ""
        self.essayMinWords = 0
        self.needsManualReview = false
        self.explanation = ""
    }

    /// Full init for all question types.
    init(
        id: UUID,
        text: String,
        questionType: QuizQuestionType,
        options: [String] = [],
        correctIndex: Int = 0,
        acceptedAnswers: [String] = [],
        matchingPairs: [MatchingPair] = [],
        essayPrompt: String = "",
        essayMinWords: Int = 0,
        needsManualReview: Bool = false,
        explanation: String = ""
    ) {
        self.id = id
        self.text = text
        self.questionType = questionType
        self.options = options
        self.correctIndex = correctIndex
        self.acceptedAnswers = acceptedAnswers
        self.matchingPairs = matchingPairs
        self.essayPrompt = essayPrompt
        self.essayMinWords = essayMinWords
        self.needsManualReview = needsManualReview
        self.explanation = explanation
    }
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
    var attachmentURLs: [String]? = nil  // file URLs from submission [Attachments] section
    var rubricId: UUID? = nil        // optional rubric attached to this assignment
    var studentId: UUID? = nil      // from submissions, for teacher view
    var studentName: String? = nil  // resolved from student_id -> profiles

    /// Extracts attachment URLs from a submission text that uses the `[Attachments]` convention.
    static func extractAttachmentURLs(from text: String?) -> [String] {
        guard let text, text.contains("[Attachments]") else { return [] }
        let lines = text.components(separatedBy: "\n")
        guard let startIdx = lines.firstIndex(where: { $0.contains("[Attachments]") }) else { return [] }
        return lines[(startIdx + 1)...].compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return trimmed
            }
            return nil
        }
    }

    /// Returns the submission text with the `[Attachments]` section stripped out.
    static func cleanSubmissionText(_ text: String?) -> String? {
        guard let text else { return nil }
        if let range = text.range(of: "\n\n[Attachments]") {
            let cleaned = String(text[text.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        if let range = text.range(of: "[Attachments]") {
            let cleaned = String(text[text.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        return text
    }

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
