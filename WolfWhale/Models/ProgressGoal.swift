import Foundation

nonisolated struct ProgressGoal: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var courseId: UUID
    var targetGrade: Double          // percentage (e.g. 87.0)
    var targetLetterGrade: String    // e.g. "B+"
    var createdDate: Date

    init(
        id: UUID = UUID(),
        courseId: UUID,
        targetGrade: Double,
        targetLetterGrade: String = "",
        createdDate: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.targetGrade = targetGrade
        self.targetLetterGrade = targetLetterGrade.isEmpty
            ? Self.letterGrade(for: targetGrade)
            : targetLetterGrade
        self.createdDate = createdDate
    }

    // MARK: - Letter Grade Conversion

    static func letterGrade(for score: Double) -> String {
        switch score {
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

    static func gradePercentage(for letter: String) -> Double {
        switch letter {
        case "A":  return 95
        case "A-": return 91
        case "B+": return 88
        case "B":  return 85
        case "B-": return 81
        case "C+": return 78
        case "C":  return 75
        case "C-": return 71
        case "D+": return 68
        case "D":  return 63
        default:   return 55
        }
    }

    static let allLetterGrades = ["A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D"]
}
