import AppIntents
import Foundation

/// Siri intent that opens the WolfWhale app to the courses view.
nonisolated struct OpenCourseIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Courses"
    static var description = IntentDescription("Open WolfWhale LMS to your courses.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Opening your WolfWhale courses.")
    }
}
