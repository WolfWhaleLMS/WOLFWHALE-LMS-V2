import AppIntents
import Foundation

nonisolated struct CheckAssignmentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Assignments"
    static var description = IntentDescription("See what assignments are due soon in WolfWhale LMS.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // FERPA: Require authentication before speaking assignment data aloud
        let defaults = UserDefaults(suiteName: UserDefaultsKeys.widgetAppGroup) ?? .standard
        guard defaults.bool(forKey: "wolfwhale_is_authenticated") else {
            return .result(dialog: "Please open WolfWhale LMS and sign in first.")
        }

        guard let data = defaults.data(forKey: UserDefaultsKeys.upcomingAssignments),
              let assignments = try? JSONDecoder().decode([CachedAssignment].self, from: data),
              !assignments.isEmpty else {
            return .result(dialog: "You have no upcoming assignments right now. Open WolfWhale to refresh your data.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let limit = min(assignments.count, 5)
        var lines: [String] = []
        for assignment in assignments.prefix(limit) {
            let dateString: String
            if let date = ISO8601DateFormatter().date(from: assignment.dueDate) {
                dateString = formatter.string(from: date)
            } else {
                dateString = assignment.dueDate
            }
            lines.append("\(assignment.title) (\(assignment.courseName)) — due \(dateString)")
        }

        let header = assignments.count == 1
            ? "You have 1 upcoming assignment:"
            : "You have \(assignments.count) upcoming assignment\(assignments.count > 1 ? "s" : ""):"

        let summary = ([header] + lines).joined(separator: "\n")
        return .result(dialog: "\(summary)")
    }
}

// MARK: - Cached Model

nonisolated struct CachedAssignment: Codable, Sendable {
    let title: String
    let dueDate: String
    let courseName: String
}
