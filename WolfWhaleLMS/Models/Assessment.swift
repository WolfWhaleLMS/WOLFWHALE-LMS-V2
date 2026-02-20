import Foundation

nonisolated struct Quiz: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var courseId: UUID
    var courseName: String
    var questions: [QuizQuestion]
    var timeLimit: Int
    var dueDate: Date
    var isCompleted: Bool
    var score: Double?
    var xpReward: Int
}

nonisolated struct QuizQuestion: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var options: [String]
    var correctIndex: Int
}

nonisolated struct Assignment: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var courseId: UUID
    var courseName: String
    var instructions: String
    var dueDate: Date
    var points: Int
    var isSubmitted: Bool
    var submission: String?
    var grade: Double?
    var feedback: String?
    var xpReward: Int

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
