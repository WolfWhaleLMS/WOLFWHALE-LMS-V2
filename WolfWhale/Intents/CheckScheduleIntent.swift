import AppIntents
import Foundation

nonisolated struct CheckScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Schedule"
    static var description = IntentDescription("See your class schedule for today in WolfWhale LMS.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // FERPA: Require authentication before speaking schedule data aloud
        let defaults = UserDefaults(suiteName: UserDefaultsKeys.widgetAppGroup) ?? .standard
        guard defaults.bool(forKey: "wolfwhale_is_authenticated") else {
            return .result(dialog: "Please open WolfWhale LMS and sign in first.")
        }

        guard let data = defaults.data(forKey: UserDefaultsKeys.scheduleToday),
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

nonisolated struct CachedScheduleEntry: Codable, Sendable {
    let courseName: String
    let time: String?
}
