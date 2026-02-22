import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AssignmentsEntry: TimelineEntry {
    let date: Date
    let assignments: [CachedAssignment]
}

// MARK: - Timeline Provider

struct AssignmentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssignmentsEntry {
        AssignmentsEntry(date: .now, assignments: WidgetDataReader.placeholderAssignments)
    }

    func getSnapshot(in context: Context, completion: @escaping (AssignmentsEntry) -> Void) {
        let assignments = context.isPreview
            ? WidgetDataReader.placeholderAssignments
            : WidgetDataReader.loadAssignments()
        completion(AssignmentsEntry(date: .now, assignments: assignments))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AssignmentsEntry>) -> Void) {
        let assignments = WidgetDataReader.loadAssignments()
        let entry = AssignmentsEntry(date: .now, assignments: assignments)
        // Refresh every 15 minutes for timely due-date countdowns
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct AssignmentsWidgetEntryView: View {
    var entry: AssignmentsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallAssignmentsView(assignments: entry.assignments)
        case .systemMedium:
            MediumAssignmentsView(assignments: entry.assignments)
        case .systemLarge:
            LargeAssignmentsView(assignments: entry.assignments, currentDate: entry.date)
        default:
            SmallAssignmentsView(assignments: entry.assignments)
        }
    }
}

// MARK: - Small View (Next Due Assignment with Countdown)

private struct SmallAssignmentsView: View {
    let assignments: [CachedAssignment]

    private var nextAssignment: CachedAssignment? {
        assignments.first
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(urgencyColor(for: nextAssignment))

            if let assignment = nextAssignment {
                VStack(spacing: 4) {
                    Text(assignment.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .privacySensitive(true)

                    Text(assignment.courseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .privacySensitive(true)

                    // Countdown
                    Text(countdownText(for: assignment))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(urgencyColor(for: assignment))
                }
            } else {
                VStack(spacing: 4) {
                    Text("All Clear!")
                        .font(.caption.weight(.semibold))
                    Text("No upcoming work")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    urgencyBackgroundColor(for: nextAssignment).opacity(0.08),
                    urgencyBackgroundColor(for: nextAssignment).opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.assignments)
    }
}

// MARK: - Medium View (Next 3 Assignments)

private struct MediumAssignmentsView: View {
    let assignments: [CachedAssignment]

    var body: some View {
        HStack(spacing: 12) {
            // Left: summary
            VStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("\(assignments.count)")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("Due Soon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64)

            Divider()

            // Right: next 3 assignments
            VStack(alignment: .leading, spacing: 6) {
                let upcoming = Array(assignments.prefix(3))

                if upcoming.isEmpty {
                    Spacer()
                    Text("No upcoming assignments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(upcoming) { assignment in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(urgencyColor(for: assignment))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(assignment.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .privacySensitive(true)

                                HStack(spacing: 4) {
                                    Text(assignment.courseName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .privacySensitive(true)

                                    Text("--")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)

                                    Text(countdownText(for: assignment))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(urgencyColor(for: assignment))
                                }
                            }

                            Spacer()
                        }
                    }

                    if assignments.count > 3 {
                        Text("+\(assignments.count - 3) more assignments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.red.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.assignments)
    }
}

// MARK: - Large View (Up to 6 Assignments)

private struct LargeAssignmentsView: View {
    let assignments: [CachedAssignment]
    let currentDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upcoming Assignments")
                        .font(.headline)
                    Text("\(assignments.count) assignment\(assignments.count == 1 ? "" : "s") due")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            Divider()

            if assignments.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green.opacity(0.6))
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Assignment rows (up to 6)
                let displayAssignments = Array(assignments.prefix(6))
                VStack(spacing: 8) {
                    ForEach(displayAssignments) { assignment in
                        HStack(spacing: 10) {
                            // Urgency indicator
                            RoundedRectangle(cornerRadius: 2)
                                .fill(urgencyColor(for: assignment))
                                .frame(width: 4)
                                .frame(maxHeight: .infinity)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .privacySensitive(true)
                                Text(assignment.courseName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .privacySensitive(true)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(countdownText(for: assignment))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(urgencyColor(for: assignment))
                                Text(formattedDueDate(for: assignment))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(minHeight: 36)
                    }
                }

                if assignments.count > 6 {
                    HStack {
                        Spacer()
                        Text("+\(assignments.count - 6) more assignments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("WolfWhale LMS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Updated \(formattedTime())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.red.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.assignments)
    }
}

// MARK: - Widget Definition

struct AssignmentsWidget: Widget {
    let kind: String = "AssignmentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AssignmentsProvider()) { entry in
            AssignmentsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Assignments")
        .description("Track upcoming assignments and due dates.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Urgency Helpers

/// Returns a color based on how soon the assignment is due.
/// - Red: less than 24 hours (urgent)
/// - Orange: less than 3 days (approaching)
/// - Primary/default: everything else
private func urgencyColor(for assignment: CachedAssignment?) -> Color {
    guard let assignment, let hours = assignment.hoursUntilDue else { return .orange }
    if hours < 0 { return .red }         // Overdue
    if hours < 24 { return .red }        // Less than 24h
    if hours < 72 { return .orange }     // Less than 3 days
    return .blue                         // Normal
}

private func urgencyBackgroundColor(for assignment: CachedAssignment?) -> Color {
    guard let assignment, let hours = assignment.hoursUntilDue else { return .orange }
    if hours < 24 { return .red }
    if hours < 72 { return .orange }
    return .blue
}

/// Returns a human-readable countdown string.
private func countdownText(for assignment: CachedAssignment) -> String {
    guard let hours = assignment.hoursUntilDue else { return "No date" }

    if hours < 0 {
        let overdueHours = abs(hours)
        if overdueHours < 1 { return "Just passed" }
        if overdueHours < 24 { return "Overdue \(Int(overdueHours))h" }
        return "Overdue \(Int(overdueHours / 24))d"
    }

    if hours < 1 { return "< 1 hour" }
    if hours < 24 { return "\(Int(hours))h left" }
    let days = Int(hours / 24)
    if days == 1 { return "Tomorrow" }
    if days < 7 { return "\(days) days" }
    return "\(days / 7)w \(days % 7)d"
}

/// Formats the due date into a short date string.
private func formattedDueDate(for assignment: CachedAssignment) -> String {
    guard let date = assignment.dueDateParsed else { return assignment.dueDate }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, h:mm a"
    return formatter.string(from: date)
}

private func formattedTime() -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: Date())
}

// MARK: - Previews

#Preview("Assignments Small", as: .systemSmall) {
    AssignmentsWidget()
} timeline: {
    AssignmentsEntry(date: .now, assignments: WidgetDataReader.placeholderAssignments)
}

#Preview("Assignments Medium", as: .systemMedium) {
    AssignmentsWidget()
} timeline: {
    AssignmentsEntry(date: .now, assignments: WidgetDataReader.placeholderAssignments)
}

#Preview("Assignments Large", as: .systemLarge) {
    AssignmentsWidget()
} timeline: {
    AssignmentsEntry(date: .now, assignments: WidgetDataReader.placeholderAssignments)
}
