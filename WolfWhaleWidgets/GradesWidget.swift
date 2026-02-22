import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct GradesEntry: TimelineEntry {
    let date: Date
    let gradesSummary: CachedGradesSummary
}

// MARK: - Timeline Provider

struct GradesProvider: TimelineProvider {
    func placeholder(in context: Context) -> GradesEntry {
        GradesEntry(date: .now, gradesSummary: WidgetDataReader.placeholderGradesSummary)
    }

    func getSnapshot(in context: Context, completion: @escaping (GradesEntry) -> Void) {
        let summary = context.isPreview
            ? WidgetDataReader.placeholderGradesSummary
            : WidgetDataReader.loadGradesSummary()
        completion(GradesEntry(date: .now, gradesSummary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GradesEntry>) -> Void) {
        let summary = WidgetDataReader.loadGradesSummary()
        let entry = GradesEntry(date: .now, gradesSummary: summary)
        // Refresh every 30 minutes
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct GradesWidgetEntryView: View {
    var entry: GradesEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallGradesView(summary: entry.gradesSummary)
        case .systemMedium:
            MediumGradesView(summary: entry.gradesSummary)
        case .systemLarge:
            LargeGradesView(summary: entry.gradesSummary)
        default:
            SmallGradesView(summary: entry.gradesSummary)
        }
    }
}

// MARK: - Small View (GPA Circle)

private struct SmallGradesView: View {
    let summary: CachedGradesSummary

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(summary.gpa / 4.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(String(format: "%.1f", summary.gpa))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .privacySensitive(true)
                    Text("GPA")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text("Grades")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.grades)
    }
}

// MARK: - Medium View (GPA + Top 3 Courses)

private struct MediumGradesView: View {
    let summary: CachedGradesSummary

    var body: some View {
        HStack(spacing: 16) {
            // GPA ring
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: min(summary.gpa / 4.0, 1.0))
                        .stroke(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", summary.gpa))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .privacySensitive(true)
                        Text("GPA")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
            }
            .frame(width: 80)

            // Top 3 course grades
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Grades")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                let topCourses = Array(summary.courseGrades.prefix(3))
                ForEach(topCourses) { grade in
                    HStack {
                        Text(grade.courseName)
                            .font(.caption)
                            .lineLimit(1)
                            .privacySensitive(true)
                        Spacer()
                        Text(grade.letterGrade)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(gradeColor(grade.numericGrade))
                            .privacySensitive(true)
                    }
                }

                if summary.courseGrades.count > 3 {
                    Text("+\(summary.courseGrades.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.grades)
    }
}

// MARK: - Large View (GPA + All Courses with Progress Bars)

private struct LargeGradesView: View {
    let summary: CachedGradesSummary

    var body: some View {
        VStack(spacing: 12) {
            // Header with GPA
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Grades")
                        .font(.headline)
                    Text("GPA: \(String(format: "%.2f", summary.gpa))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                        .privacySensitive(true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(summary.gpa / 4.0, 1.0))
                        .stroke(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(String(format: "%.1f", summary.gpa))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .privacySensitive(true)
                }
                .frame(width: 44, height: 44)
            }

            Divider()

            // Course grade rows
            VStack(spacing: 8) {
                ForEach(summary.courseGrades) { grade in
                    VStack(spacing: 4) {
                        HStack {
                            Text(grade.courseName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .privacySensitive(true)
                            Spacer()
                            Text("\(grade.letterGrade) (\(Int(grade.numericGrade))%)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(gradeColor(grade.numericGrade))
                                .privacySensitive(true)
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.15))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: gradeGradient(grade.numericGrade),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * min(grade.numericGrade / 100.0, 1.0))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
                Text("WolfWhale LMS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Updated \(formattedTime(entry: Date()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.06), Color.purple.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.grades)
    }
}

// MARK: - Widget Definition

struct GradesWidget: Widget {
    let kind: String = "GradesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GradesProvider()) { entry in
            GradesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Grades")
        .description("See your current GPA and course grades at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Helpers

private func gradeColor(_ grade: Double) -> Color {
    switch grade {
    case 90...: return .green
    case 80..<90: return .blue
    case 70..<80: return .orange
    default: return .red
    }
}

private func gradeGradient(_ grade: Double) -> [Color] {
    switch grade {
    case 90...: return [.green, .mint]
    case 80..<90: return [.blue, .cyan]
    case 70..<80: return [.orange, .yellow]
    default: return [.red, .orange]
    }
}

private func formattedTime(entry: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: entry)
}

// MARK: - Previews

#Preview("Grades Small", as: .systemSmall) {
    GradesWidget()
} timeline: {
    GradesEntry(date: .now, gradesSummary: WidgetDataReader.placeholderGradesSummary)
}

#Preview("Grades Medium", as: .systemMedium) {
    GradesWidget()
} timeline: {
    GradesEntry(date: .now, gradesSummary: WidgetDataReader.placeholderGradesSummary)
}

#Preview("Grades Large", as: .systemLarge) {
    GradesWidget()
} timeline: {
    GradesEntry(date: .now, gradesSummary: WidgetDataReader.placeholderGradesSummary)
}
