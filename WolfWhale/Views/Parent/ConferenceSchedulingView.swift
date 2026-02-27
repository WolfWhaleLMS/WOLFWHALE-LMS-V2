import SwiftUI

struct ConferenceSchedulingView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab: ConferenceTab = .upcoming
    @State private var showBooking = false
    @State private var hapticTrigger = false

    enum ConferenceTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(ConferenceTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Conference view selector")

                switch selectedTab {
                case .upcoming:
                    upcomingSection
                case .past:
                    pastSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Conferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticTrigger.toggle()
                    showBooking = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Book new conference")
            }
        }
        .sheet(isPresented: $showBooking) {
            BookConferenceSheet(viewModel: viewModel)
        }
        .task {
            #if DEBUG
            if viewModel.conferences.isEmpty {
                viewModel.loadDemoConferenceData()
            }
            #endif
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        Group {
            if viewModel.upcomingConferences.isEmpty {
                emptyState(
                    icon: "calendar.badge.clock",
                    title: "No Upcoming Conferences",
                    message: "Book a conference with a teacher to get started."
                )
            } else {
                ForEach(viewModel.upcomingConferences) { conference in
                    conferenceCard(conference, showCancel: true)
                }
            }
        }
    }

    // MARK: - Past Section

    private var pastSection: some View {
        Group {
            if viewModel.pastConferences.isEmpty {
                emptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No Past Conferences",
                    message: "Your completed conferences will appear here."
                )
            } else {
                ForEach(viewModel.pastConferences) { conference in
                    conferenceCard(conference, showCancel: false)
                }
            }
        }
    }

    // MARK: - Conference Card

    private func conferenceCard(_ conference: Conference, showCancel: Bool) -> some View {
        let statusColor = conferenceStatusColor(conference.status)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor.gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: conference.status.iconName)
                            .font(.callout)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(conference.teacherName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Re: \(conference.childName)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Text(conference.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Divider()

            HStack(spacing: 16) {
                Label {
                    Text(conference.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Label {
                    Text(conference.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Label {
                    Text("\(conference.duration) min")
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                } icon: {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }

            if let location = conference.location {
                Label {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let notes = conference.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
            }

            if showCancel && conference.status != .cancelled {
                Button(role: .destructive) {
                    hapticTrigger.toggle()
                    viewModel.cancelConference(conference.id)
                } label: {
                    Label("Cancel Conference", systemImage: "xmark.circle")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(statusColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conference with \(conference.teacherName) about \(conference.childName), \(conference.status.rawValue), \(conference.timeSlotLabel)")
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func conferenceStatusColor(_ status: ConferenceStatus) -> Color {
        switch status {
        case .requested: .orange
        case .confirmed: .green
        case .cancelled: .red
        case .completed: .blue
        }
    }
}

// MARK: - Book Conference Sheet

struct BookConferenceSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    @State private var selectedChild: ChildInfo?
    @State private var selectedTeacherName: String = ""
    @State private var selectedTeacherId: UUID?
    @State private var selectedSlot: TeacherAvailableSlot?
    @State private var notes: String = ""

    private var childTeachers: [(name: String, id: UUID?)] {
        // Get unique teacher names from courses associated with children.
        // Teacher IDs are resolved from allUsers; nil if the teacher cannot be found.
        var seen = Set<String>()
        var result: [(name: String, id: UUID?)] = []
        let teacherNames: [String] = viewModel.courses.isEmpty
            ? (selectedChild?.courses.map(\.courseName) ?? [])
            : viewModel.courses.map(\.teacherName)

        for name in teacherNames {
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            let profile = viewModel.allUsers.first { profile in
                let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return fullName == name
            }
            result.append((name: name, id: profile?.id))
        }
        return result
    }

    private var availableSlotsForTeacher: [TeacherAvailableSlot] {
        viewModel.teacherAvailableSlots
            .filter { !$0.isBooked && $0.date > Date() }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Child selection
                Section("Select Child") {
                    if viewModel.children.isEmpty {
                        Text("No children linked")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.children) { child in
                            Button {
                                selectedChild = child
                            } label: {
                                HStack {
                                    Text(child.name)
                                        .foregroundStyle(Color(.label))
                                    Spacer()
                                    if selectedChild?.id == child.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }

                // Teacher selection
                if selectedChild != nil {
                    Section("Select Teacher") {
                        if childTeachers.isEmpty {
                            Text("No teachers available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(childTeachers, id: \.name) { teacher in
                                Button {
                                    selectedTeacherName = teacher.name
                                    selectedTeacherId = teacher.id
                                } label: {
                                    HStack {
                                        Text(teacher.name)
                                            .foregroundStyle(teacher.id != nil ? Color(.label) : .secondary)
                                        if teacher.id == nil {
                                            Text("(unavailable)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        Spacer()
                                        if selectedTeacherName == teacher.name {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(teacher.id != nil ? .green : .orange)
                                        }
                                    }
                                }
                                .disabled(teacher.id == nil)
                            }
                        }
                    }
                }

                // Time slot selection
                if !selectedTeacherName.isEmpty {
                    Section("Available Time Slots") {
                        if availableSlotsForTeacher.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("No available slots")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else {
                            ForEach(availableSlotsForTeacher) { slot in
                                Button {
                                    selectedSlot = slot
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(slot.dateLabel)
                                                .font(.subheadline)
                                                .foregroundStyle(Color(.label))
                                            Text("\(slot.timeLabel) - \(slot.durationMinutes) min")
                                                .font(.caption)
                                                .foregroundStyle(Color(.secondaryLabel))
                                        }
                                        Spacer()
                                        if selectedSlot?.id == slot.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Notes
                Section("Notes (Optional)") {
                    TextField("Reason for meeting...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle("Book Conference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Book") {
                        hapticTrigger.toggle()
                        bookConference()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canBook)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .alert("Error", isPresented: .constant(bookingError != nil)) {
                Button("OK") { bookingError = nil }
            } message: {
                Text(bookingError ?? "")
            }
        }
    }

    @State private var bookingError: String?

    private var canBook: Bool {
        selectedChild != nil && !selectedTeacherName.isEmpty && selectedSlot != nil && selectedTeacherId != nil
    }

    private func bookConference() {
        guard let child = selectedChild,
              let slot = selectedSlot else { return }

        guard let teacherId = selectedTeacherId else {
            bookingError = "Unable to resolve teacher identity. Please try again later."
            return
        }

        viewModel.bookConference(
            teacherId: teacherId,
            teacherName: selectedTeacherName,
            childName: child.name,
            slotId: slot.id,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}
