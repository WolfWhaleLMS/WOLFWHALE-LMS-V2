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

// MARK: - Late Penalty Type

/// Determines how late submission penalties are calculated for an assignment.
nonisolated enum LatePenaltyType: String, Codable, CaseIterable, Sendable, Hashable {
    case none            = "none"
    case percentPerDay   = "percent_per_day"
    case flatDeduction   = "flat_deduction"
    case noCredit        = "no_credit"

    var displayName: String {
        switch self {
        case .none:           "No Penalty"
        case .percentPerDay:  "% Per Day Late"
        case .flatDeduction:  "Flat Point Deduction"
        case .noCredit:       "No Credit If Late"
        }
    }

    var iconName: String {
        switch self {
        case .none:           "checkmark.shield.fill"
        case .percentPerDay:  "percent"
        case .flatDeduction:  "minus.circle.fill"
        case .noCredit:       "xmark.octagon.fill"
        }
    }
}

// MARK: - Resubmission History Entry

/// Records a previous submission attempt with its grade, for resubmission tracking.
nonisolated struct ResubmissionHistoryEntry: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var submissionText: String?
    var grade: Double?
    var feedback: String?
    var submittedAt: Date
    var gradedAt: Date?

    init(id: UUID = UUID(), submissionText: String? = nil, grade: Double? = nil, feedback: String? = nil, submittedAt: Date = Date(), gradedAt: Date? = nil) {
        self.id = id
        self.submissionText = submissionText
        self.grade = grade
        self.feedback = feedback
        self.submittedAt = submittedAt
        self.gradedAt = gradedAt
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

    // MARK: - Learning Standards Alignment
    var standardIds: [UUID] = []    // IDs of LearningStandard tagged to this assignment

    // MARK: - Late Submission Penalty Fields
    var latePenaltyType: LatePenaltyType = .none
    var latePenaltyPerDay: Double = 0      // penalty amount per day (% or flat points depending on type)
    var maxLateDays: Int = 7               // after this many days late, no submission accepted

    // MARK: - Resubmission Fields
    var allowResubmission: Bool = false
    var maxResubmissions: Int = 1
    var resubmissionCount: Int = 0
    var resubmissionDeadline: Date? = nil
    var resubmissionHistory: [ResubmissionHistoryEntry] = []

    // MARK: - Peer Review Fields
    var peerReviewEnabled: Bool = false
    var peerReviewsPerSubmission: Int = 2

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

    // MARK: - Late Submission Computed Properties

    /// Number of calendar days late based on the current date (or 0 if not overdue).
    var daysLate: Int {
        let now = Date()
        guard now > dueDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dueDate, to: now)
        return max(components.day ?? 0, 0)
    }

    /// Whether this assignment can still accept a late submission based on maxLateDays.
    var canSubmitLate: Bool {
        guard latePenaltyType != .none else { return true }
        if latePenaltyType == .noCredit { return daysLate <= maxLateDays }
        return daysLate <= maxLateDays
    }

    /// The calculated late penalty percentage (0-100) that should be deducted from the grade.
    var latePenaltyPercent: Double {
        guard daysLate > 0, latePenaltyType != .none else { return 0 }
        switch latePenaltyType {
        case .none:
            return 0
        case .percentPerDay:
            return min(Double(daysLate) * latePenaltyPerDay, 100)
        case .flatDeduction:
            let maxPts = Double(points)
            guard maxPts > 0 else { return 0 }
            let deduction = Double(daysLate) * latePenaltyPerDay
            return min((deduction / maxPts) * 100, 100)
        case .noCredit:
            return 100
        }
    }

    /// Descriptive text for the late penalty badge (e.g., "2 days late, -20%").
    var latePenaltyBadgeText: String? {
        guard daysLate > 0, latePenaltyType != .none else { return nil }
        let dayLabel = daysLate == 1 ? "day" : "days"
        switch latePenaltyType {
        case .none:
            return nil
        case .percentPerDay:
            let penalty = Int(min(Double(daysLate) * latePenaltyPerDay, 100))
            return "\(daysLate) \(dayLabel) late, -\(penalty)%"
        case .flatDeduction:
            let deduction = Int(Double(daysLate) * latePenaltyPerDay)
            return "\(daysLate) \(dayLabel) late, -\(deduction) pts"
        case .noCredit:
            return "\(daysLate) \(dayLabel) late, no credit"
        }
    }

    // MARK: - Resubmission Computed Properties

    /// Whether a resubmission is currently allowed for this assignment.
    var canResubmit: Bool {
        guard allowResubmission else { return false }
        guard isSubmitted, grade != nil else { return false }
        guard resubmissionCount < maxResubmissions else { return false }
        if let deadline = resubmissionDeadline {
            return Date() <= deadline
        }
        return true
    }

    /// Remaining number of resubmissions available.
    var remainingResubmissions: Int {
        max(maxResubmissions - resubmissionCount, 0)
    }

    var statusText: String {
        if isSubmitted {
            if let grade {
                let gradeText = "Graded: \(Int(grade))%"
                if let lateBadge = latePenaltyBadgeText {
                    return "\(gradeText) (\(lateBadge))"
                }
                return gradeText
            }
            return "Submitted"
        }
        if isOverdue {
            if let lateBadge = latePenaltyBadgeText {
                return lateBadge
            }
            return "Overdue"
        }
        return "Pending"
    }
}
