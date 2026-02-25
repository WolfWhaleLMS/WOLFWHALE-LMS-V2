import SwiftUI

/// School calendar widget showing upcoming classes and events.
struct CalendarWidget: View {
    let events: [CalendarEvent]
    let currentDate: Date

    struct CalendarEvent: Identifiable {
        let id: UUID
        let title: String
        let time: Date
        let type: EventType
        let courseName: String?
        let color: Color

        enum EventType: String {
            case classSession = "Class"
            case assignment = "Assignment Due"
            case quiz = "Quiz"
            case event = "Event"

            var iconName: String {
                switch self {
                case .classSession: return "book.fill"
                case .assignment: return "doc.fill"
                case .quiz: return "questionmark.circle.fill"
                case .event: return "calendar.badge.clock"
                }
            }
        }

        static let sampleEvents: [CalendarEvent] = [
            CalendarEvent(id: UUID(), title: "Math 101", time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(), type: .classSession, courseName: "Mathematics", color: .blue),
            CalendarEvent(id: UUID(), title: "Essay Due", time: Calendar.current.date(bySettingHour: 11, minute: 30, second: 0, of: Date()) ?? Date(), type: .assignment, courseName: "English", color: .orange),
            CalendarEvent(id: UUID(), title: "Science Lab", time: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date(), type: .classSession, courseName: "Science", color: .green),
            CalendarEvent(id: UUID(), title: "History Quiz", time: Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date()) ?? Date(), type: .quiz, courseName: "History", color: .red),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with date
            HStack {
                VStack(alignment: .leading) {
                    Text("Today's Schedule")
                        .font(.headline)
                    Text(currentDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }

            Divider()

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("No events today!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Timeline of events
                ForEach(events) { event in
                    HStack(spacing: 12) {
                        // Time
                        Text(event.time, style: .time)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        // Color bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 3, height: 32)

                        // Event info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline.bold())
                            if let course = event.courseName {
                                Text(course)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: event.type.iconName)
                            .font(.caption)
                            .foregroundStyle(event.color)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular.tint(.purple), in: RoundedRectangle(cornerRadius: 20))
    }
}
