import SwiftUI

/// Displays a scrollable list of upcoming assignments on the Apple Watch.
///
/// Color coding:
///   - Red: due today or overdue
///   - Orange: due tomorrow
///   - Default accent: due later
struct AssignmentListView: View {
    let assignments: [WatchAssignment]

    /// Sorted with the most urgent assignments at the top.
    private var sorted: [WatchAssignment] {
        assignments
            .filter { !$0.isSubmitted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sorted.isEmpty {
                    emptyState
                } else {
                    assignmentList
                }
            }
            .navigationTitle("Assignments")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("All caught up!")
                .font(.headline)
            Text("No pending assignments")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var assignmentList: some View {
        List {
            ForEach(sorted) { assignment in
                assignmentRow(assignment)
            }
        }
        .listStyle(.carousel)
    }

    private func assignmentRow(_ assignment: WatchAssignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Course name label
            Text(assignment.courseName)
                .font(.caption2)
                .foregroundStyle(urgencyColor(for: assignment).opacity(0.9))
                .lineLimit(1)

            // Assignment title
            Text(assignment.title)
                .font(.headline)
                .lineLimit(2)

            // Due date and points
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(formattedDueDate(assignment))
                    .font(.caption2)

                Spacer()

                Text("\(assignment.points) pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(urgencyColor(for: assignment))

            // Urgency indicator
            if assignment.isOverdue {
                urgencyBadge("OVERDUE", color: .red)
            } else if assignment.isDueToday {
                urgencyBadge("DUE TODAY", color: .red)
            } else if assignment.isDueTomorrow {
                urgencyBadge("DUE TOMORROW", color: .orange)
            } else {
                let days = assignment.daysUntilDue
                if days <= 7 {
                    urgencyBadge("In \(days) days", color: .secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(urgencyColor(for: assignment).opacity(0.12))
                .padding(.vertical, 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(formattedDueDate(assignment)), \(assignment.points) points")
    }

    private func urgencyBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
    }

    // MARK: - Helpers

    private func urgencyColor(for assignment: WatchAssignment) -> Color {
        if assignment.isOverdue || assignment.isDueToday {
            return .red
        } else if assignment.isDueTomorrow {
            return .orange
        }
        return .accentColor
    }

    private func formattedDueDate(_ assignment: WatchAssignment) -> String {
        if assignment.isDueToday {
            return "Today, \(assignment.dueDate.formatted(.dateTime.hour().minute()))"
        } else if assignment.isDueTomorrow {
            return "Tomorrow, \(assignment.dueDate.formatted(.dateTime.hour().minute()))"
        } else {
            return assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}
