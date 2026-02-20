import AppIntents
import Foundation

/// Siri intent that returns a summary of the student's current grades and GPA.
/// Data is read from UserDefaults where the main app caches it after each data refresh.
nonisolated struct CheckGradesIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Grades"
    static var description = IntentDescription("See your current grades and GPA in WolfWhale LMS.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard

        guard let data = defaults.data(forKey: "wolfwhale_grades_summary"),
              let gradesSummary = try? JSONDecoder().decode(CachedGradesSummary.self, from: data) else {
            return .result(dialog: "I don't have your grades yet. Open WolfWhale to load your data.")
        }

        if gradesSummary.courseGrades.isEmpty {
            return .result(dialog: "You don't have any grades recorded yet.")
        }

        let gpaString = String(format: "%.1f", gradesSummary.gpa)
        var lines: [String] = ["Your GPA is \(gpaString)%."]

        let limit = min(gradesSummary.courseGrades.count, 6)
        for grade in gradesSummary.courseGrades.prefix(limit) {
            let pctString = String(format: "%.0f", grade.numericGrade)
            lines.append("\(grade.courseName): \(grade.letterGrade) (\(pctString)%)")
        }

        let summary = lines.joined(separator: "\n")
        return .result(dialog: "\(summary)")
    }
}

// MARK: - Cached Models

nonisolated struct CachedGradesSummary: Codable {
    let gpa: Double
    let courseGrades: [CachedCourseGrade]
}

nonisolated struct CachedCourseGrade: Codable {
    let courseName: String
    let letterGrade: String
    let numericGrade: Double
}
