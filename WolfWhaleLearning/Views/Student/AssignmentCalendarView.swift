import SwiftUI

struct AssignmentCalendarView: View {
    let viewModel: AppViewModel

    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var selectedCourseFilter: UUID? = nil
    @State private var showAgendaView = false
    @State private var hapticTrigger = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Filtered Data

    private var filteredAssignments: [Assignment] {
        if let courseId = selectedCourseFilter {
            return viewModel.assignments.filter { $0.courseId == courseId }
        }
        return viewModel.assignments
    }

    private var assignmentsByDay: [Date: [Assignment]] {
        let cal = Calendar.current
        var grouped: [Date: [Assignment]] = [:]
        for assignment in filteredAssignments {
            let dayStart = cal.startOfDay(for: assignment.dueDate)
            grouped[dayStart, default: []].append(assignment)
        }
        return grouped
    }

    private var selectedDateAssignments: [Assignment] {
        guard let selected = selectedDate else { return [] }
        let dayStart = calendar.startOfDay(for: selected)
        return (assignmentsByDay[dayStart] ?? []).sorted { $0.dueDate < $1.dueDate }
    }

    private var coursesWithAssignments: [Course] {
        let courseIds = Set(viewModel.assignments.map(\.courseId))
        return viewModel.courses.filter { courseIds.contains($0.id) }
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

        for _ in 0..<leadingBlanks {
            components.append(DateComponents())
        }

        for day in range {
            var dc = calendar.dateComponents([.year, .month], from: displayedMonth)
            dc.day = day
            components.append(dc)
        }

        return components
    }

    /// Agenda-style list of all upcoming assignments sorted by date.
    private var agendaAssignments: [Assignment] {
        filteredAssignments
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                viewToggle
                courseFilterBar

                if showAgendaView {
                    agendaList
                } else {
                    calendarCard
                    legendRow
                    selectedDayList
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Assignment Calendar")
        .navigationBarTitleDisplayMode(.large)
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
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Jump to today")
            }
        }
    }

    // MARK: - View Toggle

    private var viewToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "Month", icon: "calendar", isSelected: !showAgendaView) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAgendaView = false
                }
            }
            toggleButton(title: "Agenda", icon: "list.bullet", isSelected: showAgendaView) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAgendaView = true
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.indigo : Color.clear)
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(title) view")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Course Filter

    private var courseFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseFilterChip(title: "All Courses", colorName: nil, courseId: nil)

                ForEach(coursesWithAssignments) { course in
                    courseFilterChip(title: course.title, colorName: course.colorName, courseId: course.id)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func courseFilterChip(title: String, colorName: String?, courseId: UUID?) -> some View {
        let isSelected = selectedCourseFilter == courseId
        let chipColor: Color = colorName.map { Theme.courseColor($0) } ?? .indigo

        return Button {
            hapticTrigger.toggle()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCourseFilter = isSelected ? nil : courseId
            }
        } label: {
            HStack(spacing: 6) {
                if let colorName {
                    Circle()
                        .fill(Theme.courseColor(colorName))
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? chipColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? chipColor : Color(.label))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? chipColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("Filter: \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Previous month")

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
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Next month")
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

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, dateComponents in
                    if let day = dateComponents.day {
                        AssignmentCalendarDayCell(
                            day: day,
                            isToday: isToday(dateComponents),
                            isSelected: isSelected(dateComponents),
                            courseColors: courseColorsFor(dateComponents: dateComponents),
                            hasOverdue: hasOverdueFor(dateComponents: dateComponents)
                        ) {
                            hapticTrigger.toggle()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if let date = calendar.date(from: dateComponents) {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 52)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(color: .red, label: "Overdue")
            ForEach(coursesWithAssignments.prefix(4)) { course in
                legendItem(color: Theme.courseColor(course.colorName), label: course.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Selected Day Assignment List

    private var selectedDayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedDate {
                HStack {
                    Text(selected, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.headline)
                    Spacer()
                    Text("\(selectedDateAssignments.count) assignment\(selectedDateAssignments.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if selectedDateAssignments.isEmpty {
                    emptyDayView
                } else {
                    ForEach(selectedDateAssignments) { assignment in
                        assignmentRow(assignment)
                    }
                }
            } else {
                selectDatePrompt
            }
        }
    }

    private var emptyDayView: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Assignments Due")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("Nothing due on this day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No assignments due on this day")
    }

    private var selectDatePrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Select a Date")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("Tap any day to see assignments due")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        let course = viewModel.courses.first(where: { $0.id == assignment.courseId })
        let courseColor = course.map { Theme.courseColor($0.colorName) } ?? .orange

        return HStack(spacing: 12) {
            Circle()
                .fill(assignment.isOverdue ? Color.red.gradient : courseColor.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: assignment.isOverdue ? "exclamationmark.triangle.fill" : "doc.text.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text(assignment.courseName)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if assignment.isOverdue {
                    Text("OVERDUE")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                } else if assignment.isSubmitted {
                    Text("Submitted")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                } else {
                    Text(assignment.dueDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(courseColor)
                }
                Text("\(assignment.points) pts")
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(12)
        .background(
            assignment.isOverdue
                ? Color.red.opacity(0.08)
                : Color(.secondarySystemGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(assignment.isOverdue ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title) for \(assignment.courseName), \(assignment.points) points\(assignment.isOverdue ? ", overdue" : "")")
    }

    // MARK: - Agenda View

    private var agendaList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overdue section
            let overdueItems = agendaAssignments.filter { $0.isOverdue }
            if !overdueItems.isEmpty {
                Text("Overdue")
                    .font(.headline)
                    .foregroundStyle(.red)

                ForEach(overdueItems) { assignment in
                    agendaRow(assignment)
                }
            }

            // Upcoming grouped by day
            let upcoming = agendaAssignments.filter { !$0.isOverdue }
            let groupedByDay = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.dueDate) }
            let sortedDays = groupedByDay.keys.sorted()

            ForEach(sortedDays, id: \.self) { day in
                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.headline)
                    .padding(.top, sortedDays.first == day ? 0 : 4)

                ForEach(groupedByDay[day] ?? []) { assignment in
                    agendaRow(assignment)
                }
            }

            if agendaAssignments.isEmpty {
                ContentUnavailableView(
                    "No Assignments",
                    systemImage: "doc.text",
                    description: Text("No assignments match the current filter")
                )
            }
        }
    }

    private func agendaRow(_ assignment: Assignment) -> some View {
        let course = viewModel.courses.first(where: { $0.id == assignment.courseId })
        let courseColor = course.map { Theme.courseColor($0.colorName) } ?? .orange

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(assignment.isOverdue ? Color.red : courseColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundStyle(courseColor)

                    Text("\(assignment.points) pts")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if assignment.isOverdue {
                    Text("OVERDUE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                } else if assignment.isSubmitted {
                    Text("Done")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green, in: Capsule())
                } else {
                    Text(assignment.dueDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(minHeight: 52)
        .background(
            assignment.isOverdue
                ? Color.red.opacity(0.08)
                : Color(.secondarySystemGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title), \(assignment.courseName), \(assignment.points) points\(assignment.isOverdue ? ", overdue" : "")")
    }

    // MARK: - Helpers

    private func courseColorsFor(dateComponents: DateComponents) -> [Color] {
        guard let date = calendar.date(from: dateComponents) else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        guard let dayAssignments = assignmentsByDay[dayStart] else { return [] }

        var seen = Set<UUID>()
        var colors: [Color] = []
        for assignment in dayAssignments {
            if seen.insert(assignment.courseId).inserted {
                let course = viewModel.courses.first(where: { $0.id == assignment.courseId })
                let color = course.map { Theme.courseColor($0.colorName) } ?? .orange
                colors.append(color)
            }
        }
        return colors
    }

    private func hasOverdueFor(dateComponents: DateComponents) -> Bool {
        guard let date = calendar.date(from: dateComponents) else { return false }
        let dayStart = calendar.startOfDay(for: date)
        return (assignmentsByDay[dayStart] ?? []).contains { $0.isOverdue }
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

    private func navigateMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }
}

// MARK: - Calendar Day Cell

private struct AssignmentCalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let courseColors: [Color]
    let hasOverdue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.system(.callout, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 32, height: 32)
                    .background(backgroundView)

                // Course-colored dots
                HStack(spacing: 2) {
                    if hasOverdue {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                    }
                    ForEach(Array(courseColors.prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(day)\(courseColors.isEmpty ? "" : ", \(courseColors.count) assignment\(courseColors.count == 1 ? "" : "s")")\(hasOverdue ? ", has overdue" : "")")
        .accessibilityHint("Double tap to view assignments")
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
    NavigationStack {
        AssignmentCalendarView(viewModel: {
            let vm = AppViewModel()
            vm.loginAsDemo(role: .student)
            return vm
        }())
    }
}
