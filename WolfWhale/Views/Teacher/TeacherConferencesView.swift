import SwiftUI

struct TeacherConferencesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showAddSlot = false
    @State private var hapticTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pendingRequestsSection
                upcomingConferencesSection
                availabilitySlotsSection
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
                    showAddSlot = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Add available time slot")
            }
        }
        .sheet(isPresented: $showAddSlot) {
            AddTimeSlotSheet(viewModel: viewModel)
        }
        .task {
            #if DEBUG
            if viewModel.conferences.isEmpty {
                viewModel.loadDemoConferenceData()
            }
            #endif
        }
    }

    // MARK: - Pending Requests

    private var pendingRequestsSection: some View {
        let pending = viewModel.myConferences.filter { $0.status == .requested }

        return Group {
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Pending Requests", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .foregroundStyle(Color(.label))

                        Spacer()

                        Text("\(pending.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(.red, in: Capsule())
                    }

                    ForEach(pending) { conference in
                        requestCard(conference)
                    }
                }
            }
        }
    }

    private func requestCard(_ conference: Conference) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill.questionmark")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(conference.parentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Re: \(conference.childName)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(conference.date, style: .date)
                        .font(.caption.bold())
                        .foregroundStyle(Color(.label))
                    Text(conference.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            if let notes = conference.notes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(2)
                }
            }

            HStack(spacing: 12) {
                Button {
                    hapticTrigger.toggle()
                    viewModel.approveConference(conference.id)
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                Button(role: .destructive) {
                    hapticTrigger.toggle()
                    viewModel.declineConference(conference.id)
                } label: {
                    Label("Decline", systemImage: "xmark.circle.fill")
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
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conference request from \(conference.parentName) about \(conference.childName), \(conference.timeSlotLabel)")
    }

    // MARK: - Upcoming Conferences

    private var upcomingConferencesSection: some View {
        let confirmed = viewModel.upcomingConferences.filter { $0.status == .confirmed }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Confirmed Conferences")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if confirmed.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("No confirmed conferences")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(confirmed) { conference in
                    confirmedConferenceRow(conference)
                }
            }
        }
    }

    private func confirmedConferenceRow(_ conference: Conference) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(conference.parentName)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("Re: \(conference.childName)")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(conference.date, style: .date)
                    .font(.caption.bold())
                    .foregroundStyle(Color(.label))
                Text(conference.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                Text("\(conference.duration) min")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confirmed conference with \(conference.parentName) about \(conference.childName), \(conference.timeSlotLabel)")
    }

    // MARK: - Availability Slots

    private var availabilitySlotsSection: some View {
        let mySlots = viewModel.teacherAvailableSlots
            .filter { $0.teacherId == viewModel.currentUser?.id && $0.date > Date() }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Available Slots")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(mySlots.count) slots")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            if mySlots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No availability set")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add time slots for parents to book")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(mySlots) { slot in
                    HStack(spacing: 12) {
                        Image(systemName: slot.isBooked ? "calendar.badge.checkmark" : "calendar")
                            .font(.title3)
                            .foregroundStyle(slot.isBooked ? .green : .blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.dateLabel)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                            Text("\(slot.timeLabel) - \(slot.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        if slot.isBooked {
                            Text("Booked")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                        } else {
                            Button(role: .destructive) {
                                hapticTrigger.toggle()
                                viewModel.removeAvailableSlot(slot.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                            .accessibilityLabel("Remove time slot")
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Time slot \(slot.dateLabel) at \(slot.timeLabel), \(slot.isBooked ? "booked" : "available")")
                }
            }
        }
    }
}

// MARK: - Add Time Slot Sheet

struct AddTimeSlotSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false
    @State private var selectedDate = Date()
    @State private var durationMinutes = 15

    private let durationOptions = [15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker(
                        "Select Date & Time",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

                Section("Duration") {
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(durationOptions, id: \.self) { mins in
                            Text("\(mins) minutes").tag(mins)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Time Slot")
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
                    Button("Add") {
                        hapticTrigger.toggle()
                        viewModel.addAvailableSlot(date: selectedDate, durationMinutes: durationMinutes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
    }
}
