import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let schedule: [CachedScheduleEntry]
}

// MARK: - Timeline Provider

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: .now, schedule: WidgetDataReader.placeholderSchedule)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let schedule = context.isPreview
            ? WidgetDataReader.placeholderSchedule
            : WidgetDataReader.loadSchedule()
        completion(ScheduleEntry(date: .now, schedule: schedule))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let schedule = WidgetDataReader.loadSchedule()
        let entry = ScheduleEntry(date: .now, schedule: schedule)
        // Refresh every hour
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct ScheduleWidgetEntryView: View {
    var entry: ScheduleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallScheduleView(schedule: entry.schedule)
        case .systemMedium:
            MediumScheduleView(schedule: entry.schedule)
        case .systemLarge:
            LargeScheduleView(schedule: entry.schedule, currentDate: entry.date)
        default:
            SmallScheduleView(schedule: entry.schedule)
        }
    }
}

// MARK: - Small View (Next Class)

private struct SmallScheduleView: View {
    let schedule: [CachedScheduleEntry]

    private var nextClass: CachedScheduleEntry? {
        schedule.first
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.blue)

            if let next = nextClass {
                VStack(spacing: 4) {
                    Text(next.courseName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let time = next.time {
                        Text(time)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Text("No Classes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("Next Class")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.cyan.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.schedule)
    }
}

// MARK: - Medium View (Next 3 Classes)

private struct MediumScheduleView: View {
    let schedule: [CachedScheduleEntry]

    var body: some View {
        HStack(spacing: 12) {
            // Left: icon and title
            VStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Today")
                    .font(.caption.weight(.semibold))

                Text(formattedDate())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64)

            Divider()

            // Right: next 3 classes
            VStack(alignment: .leading, spacing: 6) {
                let upcoming = Array(schedule.prefix(3))

                if upcoming.isEmpty {
                    Spacer()
                    Text("No classes scheduled today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(courseColorForIndex(index))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.courseName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                if let time = entry.time {
                                    Text(time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }

                    if schedule.count > 3 {
                        Text("+\(schedule.count - 3) more classes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.cyan.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.schedule)
    }
}

// MARK: - Large View (Full Day Schedule)

private struct LargeScheduleView: View {
    let schedule: [CachedScheduleEntry]
    let currentDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Schedule")
                        .font(.headline)
                    Text(formattedFullDate())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            Divider()

            if schedule.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue.opacity(0.5))
                        Text("No classes scheduled today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Timeline-style schedule list
                VStack(spacing: 0) {
                    ForEach(Array(schedule.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            // Timeline dot and line
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 2)
                                        .frame(maxHeight: 8)
                                }

                                Circle()
                                    .fill(courseColorForIndex(index))
                                    .frame(width: 10, height: 10)

                                if index < schedule.count - 1 {
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 10)

                            // Time
                            Text(entry.time ?? "--:--")
                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)

                            // Course name
                            Text(entry.courseName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            Spacer()
                        }
                        .frame(minHeight: 32)
                    }
                }
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("WolfWhale LMS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(schedule.count) classes today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.cyan.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(WidgetDeepLink.schedule)
    }

    private func formattedFullDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentDate)
    }
}

// MARK: - Widget Definition

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Schedule")
        .description("View your class schedule for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Helpers

private func courseColorForIndex(_ index: Int) -> Color {
    let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .mint]
    return colors[index % colors.count]
}

private func formattedDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: Date())
}

// MARK: - Previews

#Preview("Schedule Small", as: .systemSmall) {
    ScheduleWidget()
} timeline: {
    ScheduleEntry(date: .now, schedule: WidgetDataReader.placeholderSchedule)
}

#Preview("Schedule Medium", as: .systemMedium) {
    ScheduleWidget()
} timeline: {
    ScheduleEntry(date: .now, schedule: WidgetDataReader.placeholderSchedule)
}

#Preview("Schedule Large", as: .systemLarge) {
    ScheduleWidget()
} timeline: {
    ScheduleEntry(date: .now, schedule: WidgetDataReader.placeholderSchedule)
}
