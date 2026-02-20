import AppIntents
import Foundation

/// Siri intent that returns today's class schedule.
/// Data is read from UserDefaults where the main app caches it after each data refresh.
struct CheckScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Schedule"
    static var description = IntentDescription("See your class schedule for today in WolfWhale LMS.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard

        guard let data = defaults.data(forKey: "wolfwhale_schedule_today"),
              let classes = try? JSONDecoder().decode([CachedScheduleEntry].self, from: data),
              !classes.isEmpty else {
            return .result(dialog: "You don't have any classes scheduled for today. Open WolfWhale to refresh your schedule.")
        }

        var lines: [String] = ["Here's your schedule for today:"]
        for entry in classes {
            if let time = entry.time {
                lines.append("\(entry.courseName) at \(time)")
            } else {
                lines.append(entry.courseName)
            }
        }

        let summary = lines.joined(separator: "\n")
        return .result(dialog: "\(summary)")
    }
}

// MARK: - Cached Model

struct CachedScheduleEntry: Codable {
    let courseName: String
    let time: String?
}
