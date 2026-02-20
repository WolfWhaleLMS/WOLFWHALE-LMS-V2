import SwiftUI

// MARK: - Calendar Event Model

private enum CalendarEventType: Hashable {
    case assignment
    case quiz
    case announcement

    var icon: String {
        switch self {
        case .assignment: "doc.text.fill"
        case .quiz: "questionmark.circle.fill"
        case .announcement: "megaphone.fill"
        }
    }

    var color: Color {
        switch self {
        case .assignment: .orange
        case .quiz: .orange
        case .announcement: .blue
        }
    }

    var label: String {
        switch self {
        case .assignment: "Assignment"
        case .quiz: "Quiz"
        case .announcement: "Event"
        }
    }
}

private struct CalendarEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let courseName: String
    let date: Date
    let type: CalendarEventType

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CalendarView

struct CalendarView: View {
    let viewModel: AppViewModel

    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var animateDirection: Int = 0
    @State private var hapticTrigger = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Computed Properties

    private var allEvents: [CalendarEvent] {
        var events: [CalendarEvent] = []

        for assignment in viewModel.assignments {
            events.append(CalendarEvent(
                id: assignment.id,
                title: assignment.title,
                courseName: assignment.courseName,
                date: assignment.dueDate,
                type: .assignment
            ))
        }

        for quiz in viewModel.quizzes {
            events.append(CalendarEvent(
                id: quiz.id,
                title: quiz.title,
                courseName: quiz.courseName,
                date: quiz.dueDate,
                type: .quiz
            ))
        }

        for announcement in viewModel.announcements {
            events.append(CalendarEvent(
                id: announcement.id,
                title: announcement.title,
                courseName: announcement.authorName,
                date: announcement.date,
                type: .announcement
            ))
        }

        return events
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [DateComponents] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = firstWeekday - 1

        var components: [DateComponents] = []

        // Leading blank cells
        for _ in 0..<leadingBlanks {
            components.append(DateComponents())
        }

        // Actual days
        for day in range {
            var dc = calendar.dateComponents([.year, .month], from: displayedMonth)
            dc.day = day
            components.append(dc)
        }

        return components
    }

    private var selectedDateEvents: [CalendarEvent] {
        guard let selected = selectedDate else { return [] }
        return allEvents.filter { calendar.isDate($0.date, inSameDayAs: selected) }
            .sorted { $0.date < $1.date }
    }

    private func eventsFor(dateComponents: DateComponents) -> Set<CalendarEventType> {
        guard let date = calendar.date(from: dateComponents) else { return [] }
        var types: Set<CalendarEventType> = []
        for event in allEvents {
            if calendar.isDate(event.date, inSameDayAs: date) {
                types.insert(event.type)
            }
        }
        return types
    }

    private func isToday(_ dateComponents: DateComponents) -> Bool {
        guard let date = calendar.date(from: dateComponents) else { return false }
        return calendar.isDateInToday(date)
    }

    private func isSelected(_ dateComponents: DateComponents) -> Bool {
        guard let date = calendar.date(from: dateComponents),
              let selected = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selected)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calendarCard
                    legendRow
                    eventsList
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            displayedMonth = Date()
                            selectedDate = Date()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                            Text("Today")
                                .font(.subheadline.bold())
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 16) {
            // Month navigation header
            HStack {
                Button {
                    hapticTrigger.toggle()
                    navigateMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.quaternary, in: Circle())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Previous month")
                .accessibilityHint("Double tap to go to the previous month")

                Spacer()

                Text(monthYearString)
                    .font(.title3.bold())
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    navigateMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.quaternary, in: Circle())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Next month")
                .accessibilityHint("Double tap to go to the next month")
            }

            // Day of week headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }

            // Calendar day grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, dateComponents in
                    if let day = dateComponents.day {
                        CalendarDayView(
                            day: day,
                            isToday: isToday(dateComponents),
                            isSelected: isSelected(dateComponents),
                            eventTypes: eventsFor(dateComponents: dateComponents)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if let date = calendar.date(from: dateComponents) {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Legend Row

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(color: .orange, label: "Assignment")
            legendItem(color: .orange, label: "Quiz")
            legendItem(color: .blue, label: "Event")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Events List

    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedDate {
                HStack {
                    Text(selected, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.headline)
                    Spacer()
                    Text("\(selectedDateEvents.count) event\(selectedDateEvents.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if selectedDateEvents.isEmpty {
                    emptyEventsView
                } else {
                    ForEach(selectedDateEvents) { event in
                        eventRow(event)
                    }
                }
            } else {
                selectDatePrompt
            }
        }
    }

    private var emptyEventsView: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Events")
                    .font(.subheadline.bold())
                Text("Nothing scheduled for this day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var selectDatePrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Select a Date")
                    .font(.subheadline.bold())
                Text("Tap any day to see scheduled events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.type.color.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: event.type.icon)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(event.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.type.label)
                    .font(.caption2.bold())
                    .foregroundStyle(event.type.color)
                Text(event.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.type.label): \(event.title), \(event.courseName), at \(event.timeString)")
    }

    // MARK: - Helpers

    private func navigateMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }
}

// MARK: - CalendarDayView

private struct CalendarDayView: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let eventTypes: Set<CalendarEventType>
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(.callout, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 32, height: 32)
                    .background(backgroundView)

                // Event dots
                HStack(spacing: 3) {
                    if eventTypes.contains(.assignment) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
                    if eventTypes.contains(.quiz) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
                    if eventTypes.contains(.announcement) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .indigo
        } else {
            return .primary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Circle()
                .fill(Color.indigo.gradient)
        } else if isToday {
            Circle()
                .strokeBorder(Color.indigo, lineWidth: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView(viewModel: {
        let vm = AppViewModel()
        vm.loginAsDemo(role: .student)
        return vm
    }())
}
