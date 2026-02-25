import AppIntents

/// Registers WolfWhale LMS shortcuts so they appear in Siri and the Shortcuts app.
nonisolated struct WolfWhaleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckAssignmentsIntent(),
            phrases: [
                "What assignments are due in \(.applicationName)?",
                "Check my \(.applicationName) assignments",
                "Show upcoming assignments in \(.applicationName)"
            ],
            shortTitle: "Check Assignments",
            systemImageName: "doc.text.fill"
        )

        AppShortcut(
            intent: CheckGradesIntent(),
            phrases: [
                "Check my \(.applicationName) grades",
                "What are my grades in \(.applicationName)?",
                "Show my \(.applicationName) GPA"
            ],
            shortTitle: "Check Grades",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: OpenCourseIntent(),
            phrases: [
                "Open \(.applicationName) courses",
                "Show my \(.applicationName) courses",
                "Open \(.applicationName)"
            ],
            shortTitle: "Open Courses",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: CheckScheduleIntent(),
            phrases: [
                "What's my \(.applicationName) schedule?",
                "Show today's \(.applicationName) classes",
                "What classes do I have in \(.applicationName)?"
            ],
            shortTitle: "Today's Schedule",
            systemImageName: "calendar"
        )
    }
}
