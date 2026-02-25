import SwiftUI

struct AcademicCalendarView: View {
    let viewModel: AppViewModel
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showAddTerm = false
    @State private var showAddEvent = false
    @State private var showAddGradingPeriod = false
    @State private var selectedTab = 0
    @State private var editingTerm: AcademicTerm?
    @State private var editingEvent: AcademicEvent?
    @State private var hapticTrigger = false
    @State private var eventToDelete: AcademicEvent?
    @State private var termToDelete: AcademicTerm?
    @State private var gradingPeriodToDelete: GradingPeriod?
    @State private var showDeleteEventConfirmation = false
    @State private var showDeleteTermConfirmation = false
    @State private var showDeleteGradingPeriodConfirmation = false

    private var isAdmin: Bool {
        viewModel.currentUser?.role == .admin || viewModel.currentUser?.role == .superAdmin
    }

    private var config: AcademicCalendarConfig {
        viewModel.academicCalendarConfig
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    calendarSection
                    selectedDateEventsSection

                    Picker("View", selection: $selectedTab) {
                        Text("Terms").tag(0)
                        Text("Events").tag(1)
                        Text("Grading").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    switch selectedTab {
                    case 0: termsListSection
                    case 1: eventsListSection
                    case 2: gradingPeriodsSection
                    default: EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Academic Calendar")
            .toolbar {
                if isAdmin {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                hapticTrigger.toggle()
                                showAddTerm = true
                            } label: {
                                Label("Add Term", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                hapticTrigger.toggle()
                                showAddEvent = true
                            } label: {
                                Label("Add Event", systemImage: "star.circle")
                            }
                            Button {
                                hapticTrigger.toggle()
                                showAddGradingPeriod = true
                            } label: {
                                Label("Add Grading Period", systemImage: "chart.bar.doc.horizontal")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("Add calendar item")
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .sheet(isPresented: $showAddTerm) {
                AddTermSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddGradingPeriod) {
                AddGradingPeriodSheet(viewModel: viewModel)
            }
            .sheet(item: $editingTerm) { term in
                AddTermSheet(viewModel: viewModel, editingTerm: term)
            }
            .sheet(item: $editingEvent) { event in
                AddEventSheet(viewModel: viewModel, editingEvent: event)
            }
            .task {
                await viewModel.loadAcademicCalendar()
            }
            .confirmationDialog("Delete Event?", isPresented: $showDeleteEventConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let event = eventToDelete {
                        viewModel.deleteEvent(event.id)
                        eventToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    eventToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \"\(eventToDelete?.title ?? "this event")\"? This cannot be undone.")
            }
            .confirmationDialog("Delete Term?", isPresented: $showDeleteTermConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let term = termToDelete {
                        viewModel.deleteTerm(term.id)
                        termToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    termToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \"\(termToDelete?.name ?? "this term")\"? This cannot be undone.")
            }
            .confirmationDialog("Delete Grading Period?", isPresented: $showDeleteGradingPeriodConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let period = gradingPeriodToDelete {
                        viewModel.deleteGradingPeriod(period.id)
                        gradingPeriodToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    gradingPeriodToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \"\(gradingPeriodToDelete?.name ?? "this grading period")\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    hapticTrigger.toggle()
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .foregroundStyle(Color(.label))

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next month")
            }

            // Day of week headers
            let daySymbols = Calendar.current.veryShortWeekdaySymbols
            HStack(spacing: 0) {
                ForEach(daySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = calendarDays(for: displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    if let day = day {
                        calendarDayCell(day)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Academic calendar for \(displayedMonth, format: .dateTime.month(.wide).year())")
    }

    private func calendarDayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayEvents = config.events(for: date)
        let isExamDay = dayEvents.contains { $0.type == .examPeriod }
        let isHoliday = dayEvents.contains { $0.type == .holiday || $0.type == .noSchool }
        let isGradeDeadline = dayEvents.contains { $0.type == .gradeDeadline }
        let hasEvents = !dayEvents.isEmpty

        return Button {
            hapticTrigger.toggle()
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isHoliday ? .red :
                        isExamDay ? .orange :
                        isGradeDeadline ? .purple :
                        Color(.label)
                    )

                if hasEvents {
                    HStack(spacing: 2) {
                        ForEach(Array(Set(dayEvents.map(\.type))).prefix(3), id: \.self) { type in
                            Circle()
                                .fill(eventColor(type))
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Color.clear.frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.indigo :
                        isToday ? Color.indigo.opacity(0.15) :
                        isExamDay ? Color.orange.opacity(0.1) :
                        Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelForDay(date, events: dayEvents, isToday: isToday))
    }

    // MARK: - Selected Date Events

    private var selectedDateEventsSection: some View {
        let events = config.events(for: selectedDate)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                if let term = config.term(for: selectedDate) {
                    Text(term.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.indigo)
                }
            }

            if events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color(.secondaryLabel))
                    Text("No events on this day")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func eventRow(_ event: AcademicEvent) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor(event.type))
                .frame(width: 4, height: 36)

            Image(systemName: event.type.iconName)
                .font(.subheadline)
                .foregroundStyle(eventColor(event.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                if let desc = event.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(2)
                }
                if event.isMultiDay {
                    Text(event.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer()

            Text(event.type.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(eventColor(event.type).opacity(0.12))
                .clipShape(Capsule())
                .foregroundStyle(eventColor(event.type))
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if isAdmin {
                Button {
                    editingEvent = event
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    eventToDelete = event
                    showDeleteEventConfirmation = true
                } label: {
                    Label("Delete Event", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.type.rawValue)")
    }

    // MARK: - Terms List

    private var termsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Academic Terms")
                .font(.headline)

            if config.terms.isEmpty {
                emptyStateCard(icon: "calendar.badge.clock", message: "No terms configured")
            } else {
                ForEach(config.terms) { term in
                    termCard(term)
                }
            }
        }
    }

    private func termCard(_ term: AcademicTerm) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: term.type.iconName)
                    .font(.title3)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(term.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text(term.formattedDateRange)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                if term.isActive {
                    Text("Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.green)
                }

                Text(term.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(.indigo)
            }

            HStack(spacing: 16) {
                Label("\(term.durationDays) days", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))

                let periodCount = config.gradingPeriods(for: term.id).count
                Label("\(periodCount) grading period\(periodCount == 1 ? "" : "s")", systemImage: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(term.isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            if isAdmin {
                Button {
                    editingTerm = term
                } label: {
                    Label("Edit Term", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    termToDelete = term
                    showDeleteTermConfirmation = true
                } label: {
                    Label("Delete Term", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(term.name), \(term.type.rawValue), \(term.isActive ? "active" : "inactive"), \(term.durationDays) days")
    }

    // MARK: - Events List

    private var eventsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Events")
                .font(.headline)

            if config.events.isEmpty {
                emptyStateCard(icon: "star.circle", message: "No events scheduled")
            } else {
                let sortedEvents = config.events.sorted { $0.date < $1.date }

                // Group by type
                let grouped = Dictionary(grouping: sortedEvents) { $0.type }
                ForEach(EventType.allCases, id: \.self) { type in
                    if let events = grouped[type], !events.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: type.iconName)
                                    .font(.caption)
                                    .foregroundStyle(eventColor(type))
                                Text(type.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(eventColor(type))
                                Text("(\(events.count))")
                                    .font(.caption2)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            ForEach(events) { event in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(eventColor(event.type))
                                        .frame(width: 8, height: 8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.subheadline)
                                            .foregroundStyle(Color(.label))
                                        Text(event.formattedDate)
                                            .font(.caption2)
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }

                                    Spacer()

                                    if event.date < Date() {
                                        Text("Past")
                                            .font(.caption2)
                                            .foregroundStyle(Color(.tertiaryLabel))
                                    }
                                }
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .contextMenu {
                                    if isAdmin {
                                        Button {
                                            editingEvent = event
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            eventToDelete = event
                                            showDeleteEventConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(event.title), \(event.formattedDate)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grading Periods

    private var gradingPeriodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grading Periods")
                .font(.headline)

            if config.gradingPeriods.isEmpty {
                emptyStateCard(icon: "chart.bar.doc.horizontal", message: "No grading periods configured")
            } else {
                ForEach(config.terms) { term in
                    let periods = config.gradingPeriods(for: term.id)
                    if !periods.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(term.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.indigo)

                            ForEach(periods) { period in
                                gradingPeriodCard(period)
                            }
                        }
                    }
                }
            }
        }
    }

    private func gradingPeriodCard(_ period: GradingPeriod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(period.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                if period.isActive {
                    Text("Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.green)
                }
            }

            Text(period.formattedDateRange)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(period.deadlinePassed ? .red : .purple)
                Text("Grades due: \(period.gradeSubmissionDeadline.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(period.deadlinePassed ? .red : Color(.secondaryLabel))
                if period.deadlinePassed {
                    Text("PAST DUE")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(period.isActive ? Color.green.opacity(0.3) : period.deadlinePassed ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            if isAdmin {
                Button(role: .destructive) {
                    gradingPeriodToDelete = period
                    showDeleteGradingPeriodConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(period.name), \(period.formattedDateRange), grades due \(period.gradeSubmissionDeadline.formatted(date: .abbreviated, time: .omitted))")
    }

    // MARK: - Helpers

    private func emptyStateCard(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color(.secondaryLabel))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func eventColor(_ type: EventType) -> Color {
        switch type {
        case .holiday: .red
        case .examPeriod: .orange
        case .gradeDeadline: .purple
        case .parentConference: .blue
        case .schoolEvent: .green
        case .noSchool: .gray
        }
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = firstWeekday - calendar.firstWeekday
        let adjustedBlanks = leadingBlanks < 0 ? leadingBlanks + 7 : leadingBlanks

        var days: [Date?] = Array(repeating: nil, count: adjustedBlanks)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func accessibilityLabelForDay(_ date: Date, events: [AcademicEvent], isToday: Bool) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        var label = "\(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
        if isToday { label += ", today" }
        if !events.isEmpty {
            let eventNames = events.map(\.title).joined(separator: ", ")
            label += ", events: \(eventNames)"
        }
        return label
    }
}

// MARK: - Add Term Sheet

struct AddTermSheet: View {
    let viewModel: AppViewModel
    var editingTerm: AcademicTerm?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 120)
    @State private var termType: TermType = .semester
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Term Details") {
                    TextField("Term Name", text: $name)
                        .accessibilityLabel("Term name")
                    Picker("Type", selection: $termType) {
                        ForEach(TermType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .accessibilityLabel("Term type")
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityLabel("Term start date")
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityLabel("Term end date")
                }
            }
            .navigationTitle(editingTerm != nil ? "Edit Term" : "Add Term")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingTerm != nil ? "Save" : "Add") {
                        hapticTrigger.toggle()
                        if let existing = editingTerm {
                            var updated = existing
                            updated.name = name
                            updated.startDate = startDate
                            updated.endDate = endDate
                            updated.type = termType
                            viewModel.updateTerm(updated)
                        } else {
                            let term = AcademicTerm(name: name, startDate: startDate, endDate: endDate, type: termType)
                            viewModel.addTerm(term)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
            .onAppear {
                if let term = editingTerm {
                    name = term.name
                    startDate = term.startDate
                    endDate = term.endDate
                    termType = term.type
                }
            }
        }
    }
}

// MARK: - Add Event Sheet

struct AddEventSheet: View {
    let viewModel: AppViewModel
    var editingEvent: AcademicEvent?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date().addingTimeInterval(86400)
    @State private var eventType: EventType = .schoolEvent
    @State private var description = ""
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                        .accessibilityLabel("Event title")
                    Picker("Type", selection: $eventType) {
                        ForEach(EventType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName).tag(type)
                        }
                    }
                    .accessibilityLabel("Event type")
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Event description")
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Event start date")
                    Toggle("Multi-day Event", isOn: $hasEndDate)
                        .accessibilityLabel("Multi-day event toggle")
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                            .accessibilityLabel("Event end date")
                    }
                }
            }
            .navigationTitle(editingEvent != nil ? "Edit Event" : "Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingEvent != nil ? "Save" : "Add") {
                        hapticTrigger.toggle()
                        let desc = description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description
                        if let existing = editingEvent {
                            var updated = existing
                            updated.title = title
                            updated.date = date
                            updated.endDate = hasEndDate ? endDate : nil
                            updated.type = eventType
                            updated.description = desc
                            viewModel.updateEvent(updated)
                        } else {
                            let event = AcademicEvent(
                                title: title,
                                date: date,
                                endDate: hasEndDate ? endDate : nil,
                                type: eventType,
                                description: desc
                            )
                            viewModel.addEvent(event)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
            .onAppear {
                if let event = editingEvent {
                    title = event.title
                    date = event.date
                    hasEndDate = event.endDate != nil
                    endDate = event.endDate ?? date.addingTimeInterval(86400)
                    eventType = event.type
                    description = event.description ?? ""
                }
            }
        }
    }
}

// MARK: - Add Grading Period Sheet

struct AddGradingPeriodSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedTermId: UUID?
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 60)
    @State private var deadline = Date().addingTimeInterval(86400 * 65)
    @State private var hapticTrigger = false

    private var terms: [AcademicTerm] {
        viewModel.academicCalendarConfig.terms
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Grading Period Details") {
                    TextField("Period Name", text: $name)
                        .accessibilityLabel("Grading period name")
                    Picker("Term", selection: $selectedTermId) {
                        Text("Select a term").tag(UUID?.none)
                        ForEach(terms) { term in
                            Text(term.name).tag(UUID?.some(term.id))
                        }
                    }
                    .accessibilityLabel("Associated term")
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityLabel("Period start date")
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityLabel("Period end date")
                    DatePicker("Grade Submission Deadline", selection: $deadline, displayedComponents: .date)
                        .accessibilityLabel("Grade submission deadline")
                }
            }
            .navigationTitle("Add Grading Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        hapticTrigger.toggle()
                        guard let termId = selectedTermId else { return }
                        let period = GradingPeriod(
                            name: name,
                            termId: termId,
                            startDate: startDate,
                            endDate: endDate,
                            gradeSubmissionDeadline: deadline
                        )
                        viewModel.addGradingPeriod(period)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedTermId == nil)
                }
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
        }
    }
}
