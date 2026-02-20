import SwiftUI

/// Displays today's class schedule on the Apple Watch with a countdown to the next class.
///
/// - The currently active class is highlighted with a green accent.
/// - The next upcoming class shows a live countdown timer.
/// - Past classes appear dimmed.
struct ScheduleView: View {
    let entries: [WatchScheduleEntry]

    /// Filter to only today's entries and sort by start time.
    private var todayEntries: [WatchScheduleEntry] {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    /// The first class that has not ended yet.
    private var nextOrCurrentEntry: WatchScheduleEntry? {
        let now = Date()
        return todayEntries.first { $0.endTime > now }
    }

    var body: some View {
        NavigationStack {
            Group {
                if todayEntries.isEmpty {
                    emptyState
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Schedule")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
            Text("No Classes Today")
                .font(.headline)
            Text("Enjoy your day off!")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scheduleList: some View {
        ScrollViewReader { proxy in
            List {
                // Countdown section for the next upcoming class
                if let next = nextOrCurrentEntry, next.isUpcoming {
                    countdownSection(for: next)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.15))
                                .padding(.vertical, 2)
                        )
                }

                ForEach(todayEntries) { entry in
                    classRow(entry)
                        .id(entry.id)
                }
            }
            .listStyle(.carousel)
            .onAppear {
                // Scroll to the current or next class on appear.
                if let target = nextOrCurrentEntry {
                    proxy.scrollTo(target.id, anchor: .top)
                }
            }
        }
    }

    private func countdownSection(for entry: WatchScheduleEntry) -> some View {
        VStack(spacing: 4) {
            Text("Next Class")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.courseName)
                .font(.headline)
                .lineLimit(1)

            // Live-updating countdown using TimelineView
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, entry.startTime.timeIntervalSince(context.date))
                let hours = Int(remaining) / 3600
                let minutes = (Int(remaining) % 3600) / 60
                let seconds = Int(remaining) % 60

                if remaining > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        if hours > 0 {
                            Text(String(format: "%dh %02dm %02ds", hours, minutes, seconds))
                                .font(.system(.caption, design: .monospaced))
                                .monospacedDigit()
                        } else {
                            Text(String(format: "%02dm %02ds", minutes, seconds))
                                .font(.system(.caption, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.blue)
                } else {
                    Text("Starting now!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next class: \(entry.courseName)")
    }

    private func classRow(_ entry: WatchScheduleEntry) -> some View {
        let isPast = Date() > entry.endTime
        let isActive = entry.isCurrentlyActive

        return VStack(alignment: .leading, spacing: 4) {
            // Time range
            HStack(spacing: 4) {
                Text(entry.startTime.formatted(.dateTime.hour().minute()))
                Text("-")
                Text(entry.endTime.formatted(.dateTime.hour().minute()))
            }
            .font(.caption2)
            .foregroundStyle(isPast ? .secondary : (isActive ? .green : .primary))

            // Course name
            Text(entry.courseName)
                .font(.headline)
                .foregroundStyle(isPast ? .secondary : .primary)
                .lineLimit(2)

            // Room number
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                Text("Room \(entry.roomNumber)")
                    .font(.caption2)
            }
            .foregroundStyle(isPast ? .tertiary : .secondary)

            // Active indicator
            if isActive {
                Text("IN PROGRESS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .opacity(isPast ? 0.6 : 1.0)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.green.opacity(0.12) : Color.clear)
                .padding(.vertical, 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.courseName), \(entry.startTime.formatted(.dateTime.hour().minute())) to \(entry.endTime.formatted(.dateTime.hour().minute())), Room \(entry.roomNumber)\(isActive ? ", currently in progress" : "")")
    }
}
