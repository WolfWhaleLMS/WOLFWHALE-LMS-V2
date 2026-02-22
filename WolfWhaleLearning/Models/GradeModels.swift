import Foundation

// MARK: - Grade Weights

nonisolated struct GradeWeights: Codable, Hashable, Sendable {
    var assignments: Double
    var quizzes: Double
    var participation: Double
    var midterm: Double
    var finalExam: Double

    static let `default` = GradeWeights(
        assignments: 0.40,
        quizzes: 0.30,
        participation: 0.10,
        midterm: 0.10,
        finalExam: 0.10
    )

    /// All weights must sum to 1.0 (within floating-point tolerance).
    var isValid: Bool {
        let sum = assignments + quizzes + participation + midterm + finalExam
        return abs(sum - 1.0) < 0.001
    }

    /// Returns the weight for the given category.
    func weight(for category: GradeCategory) -> Double {
        switch category {
        case .assignment: return assignments
        case .quiz: return quizzes
        case .participation: return participation
        case .midterm: return midterm
        case .finalExam: return finalExam
        }
    }

    /// Returns a new GradeWeights with the specified category updated.
    func setting(_ category: GradeCategory, to value: Double) -> GradeWeights {
        var copy = self
        switch category {
        case .assignment: copy.assignments = value
        case .quiz: copy.quizzes = value
        case .participation: copy.participation = value
        case .midterm: copy.midterm = value
        case .finalExam: copy.finalExam = value
        }
        return copy
    }
}

// MARK: - Grade Category

nonisolated enum GradeCategory: String, Codable, CaseIterable, Sendable {
    case assignment
    case quiz
    case participation
    case midterm
    case finalExam

    var displayName: String {
        switch self {
        case .assignment: return "Assignments"
        case .quiz: return "Quizzes"
        case .participation: return "Participation"
        case .midterm: return "Midterm"
        case .finalExam: return "Final Exam"
        }
    }

    var iconName: String {
        switch self {
        case .assignment: return "doc.text.fill"
        case .quiz: return "questionmark.circle.fill"
        case .participation: return "hand.raised.fill"
        case .midterm: return "clock.badge.checkmark.fill"
        case .finalExam: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Grade Breakdown

nonisolated struct GradeBreakdown: Sendable {
    let category: GradeCategory
    let weight: Double
    let earnedPoints: Double
    let totalPoints: Double
    let percentage: Double
    let weightedContribution: Double
}

// MARK: - Course Grade Result

nonisolated struct CourseGradeResult: Sendable {
    let courseId: UUID
    let courseName: String
    let overallPercentage: Double
    let letterGrade: String
    let gradePoints: Double
    let breakdowns: [GradeBreakdown]
    let trend: GradeTrend
}

// MARK: - Grade Trend

nonisolated enum GradeTrend: Sendable {
    case improving
    case declining
    case stable

    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: String {
        switch self {
        case .improving: return "green"
        case .declining: return "red"
        case .stable: return "gray"
        }
    }
}
