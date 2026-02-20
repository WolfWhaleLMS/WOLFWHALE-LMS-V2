import AppIntents
import Foundation

/// Siri intent that returns a summary of upcoming assignments.
/// Data is read from UserDefaults where the main app caches it after each data refresh.
struct CheckAssignmentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Assignments"
    static var description = IntentDescription("See what assignments are due soon in WolfWhale LMS.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard

        guard let data = defaults.data(forKey: "wolfwhale_upcoming_assignments"),
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

/// Lightweight Codable model stored in UserDefaults for Siri to read.
struct CachedAssignment: Codable {
    let title: String
    let dueDate: String
    let courseName: String
}
