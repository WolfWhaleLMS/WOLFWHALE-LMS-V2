import SwiftUI

// MARK: - Accessibility View Extensions

extension View {
    /// Apply standard course card accessibility
    func courseCardAccessibility(title: String, teacherName: String, studentCount: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), taught by \(teacherName), \(studentCount) students enrolled")
            .accessibilityAddTraits(.isButton)
    }

    /// Apply standard stat card accessibility
    func statCardAccessibility(label: String, value: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
    }

    /// Apply grade display accessibility
    func gradeAccessibility(courseName: String, grade: String, percentage: Double) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(courseName): Grade \(grade), \(Int(percentage)) percent")
    }

    /// Apply assignment row accessibility
    func assignmentAccessibility(title: String, courseName: String, dueDate: Date, points: Int, status: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) for \(courseName), due \(dueDate.formatted(.dateTime.month(.abbreviated).day())), \(points) points, status: \(status)")
    }

    /// Apply attendance cell accessibility
    func attendanceAccessibility(date: Date, status: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())): \(status)")
    }

    /// Apply leaderboard entry accessibility
    func leaderboardAccessibility(rank: Int, name: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rank \(rank): \(name)")
    }

    /// Apply message bubble accessibility
    func messageBubbleAccessibility(senderName: String, content: String, timestamp: Date) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(senderName) said: \(content), at \(timestamp.formatted(.dateTime.hour().minute()))")
    }
}
