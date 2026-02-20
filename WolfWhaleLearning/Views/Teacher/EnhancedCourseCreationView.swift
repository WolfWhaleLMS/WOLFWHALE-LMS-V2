import SwiftUI

struct EnhancedCourseCreationView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Header / Details
    @State private var courseTitle = ""
    @State private var courseDescription = ""
    @State private var selectedSubject = "Other"

    // MARK: - Visual Customization
    @State private var selectedIcon = "book.fill"
    @State private var selectedColor = "purple"

    // MARK: - Schedule
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var selectedSemester = "Spring 2026"
    @State private var credits: Int = 3

    // MARK: - Settings
    @State private var selectedGradeLevel = "9-12"
    @State private var maxEnrollment: Int = 30
    @State private var allowLateSubmissions = true
    @State private var lateGracePeriodDays: Int = 3

    // MARK: - State
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var hapticTrigger = false

    private let subjects = [
        "Mathematics", "Science", "English", "History", "Art",
        "Music", "Physical Education", "Computer Science",
        "Foreign Language", "Other"
    ]

    private let semesters = ["Fall 2025", "Spring 2026", "Summer 2026"]
    private let gradeLevels = ["K-5", "6-8", "9-12", "College"]

    private var resolvedAccentColor: Color {
        Theme.courseColor(selectedColor)
    }

    private var isValid: Bool {
        !courseTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    previewCard
                    detailsSection
                    visualSection
                    scheduleSection
                    settingsSection
                    createButton
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating course...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(resolvedAccentColor.gradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(courseTitle.isEmpty ? "Course Title" : courseTitle)
                        .font(.headline)
                        .foregroundStyle(courseTitle.isEmpty ? .secondary : .primary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label(selectedSubject, systemImage: "tag.fill")
                        Label(selectedSemester, systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Details", systemImage: "pencil.line")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Introduction to Biology", text: $courseTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Course title")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $courseDescription)
                    .frame(minHeight: 80)
                    .padding(4)
                    .background(Color(.systemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }
                    .accessibilityLabel("Course description")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Subject", selection: $selectedSubject) {
                    ForEach(subjects, id: \.self) { subject in
                        Text(subject).tag(subject)
                    }
                }
                .pickerStyle(.menu)
                .tint(resolvedAccentColor)
                .accessibilityLabel("Subject")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Visual Customization Section

    private var visualSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CourseIconPicker(selectedIcon: $selectedIcon, accentColor: resolvedAccentColor)
            CourseColorPicker(selectedColor: $selectedColor)
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schedule", systemImage: "calendar.badge.clock")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Start Date")
                        .font(.subheadline)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(resolvedAccentColor)
                        .accessibilityLabel("Start date")
                }

                Divider()

                HStack {
                    Text("End Date")
                        .font(.subheadline)
                    Spacer()
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(resolvedAccentColor)
                        .accessibilityLabel("End date")
                }

                Divider()

                HStack {
                    Text("Semester")
                        .font(.subheadline)
                    Spacer()
                    Picker("Semester", selection: $selectedSemester) {
                        ForEach(semesters, id: \.self) { semester in
                            Text(semester).tag(semester)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(resolvedAccentColor)
                    .accessibilityLabel("Semester")
                }

                Divider()

                Stepper("Credits: \(credits)", value: $credits, in: 1...6)
                    .font(.subheadline)
                    .accessibilityLabel("Credits: \(credits)")
                    .accessibilityHint("Adjustable, from 1 to 6 credits")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Grade Level")
                        .font(.subheadline)
                    Spacer()
                    Picker("Grade Level", selection: $selectedGradeLevel) {
                        ForEach(gradeLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(resolvedAccentColor)
                    .accessibilityLabel("Grade level")
                }

                Divider()

                Stepper("Max Enrollment: \(maxEnrollment)", value: $maxEnrollment, in: 1...200)
                    .font(.subheadline)
                    .accessibilityLabel("Maximum enrollment: \(maxEnrollment)")
                    .accessibilityHint("Adjustable, from 1 to 200 students")

                Divider()

                Toggle("Allow Late Submissions", isOn: $allowLateSubmissions)
                    .font(.subheadline)
                    .tint(resolvedAccentColor)
                    .accessibilityLabel("Allow late submissions")

                if allowLateSubmissions {
                    Divider()

                    Stepper("Grace Period: \(lateGracePeriodDays) day\(lateGracePeriodDays == 1 ? "" : "s")", value: $lateGracePeriodDays, in: 1...30)
                        .font(.subheadline)
                        .accessibilityLabel("Late submission grace period: \(lateGracePeriodDays) days")
                        .accessibilityHint("Adjustable, from 1 to 30 days")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }

            Button {
                hapticTrigger.toggle()
                createCourse()
            } label: {
                Label("Create Course", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(resolvedAccentColor)
            .disabled(!isValid || isCreating)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel("Create course")
            .accessibilityHint(isValid ? "Double tap to create the course" : "Enter a course title first")
        }
        .padding(.top, 4)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Course Created!")
                    .font(.title3.bold())
                Text("\(courseTitle) is ready for students")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
            dismiss()
        }
    }

    // MARK: - Actions

    private func createCourse() {
        isCreating = true
        errorMessage = nil

        let trimmedTitle = courseTitle.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = courseDescription.trimmingCharacters(in: .whitespaces)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        Task {
            do {
                try await viewModel.createCourse(
                    title: trimmedTitle,
                    description: trimmedDescription,
                    colorName: selectedColor,
                    iconSystemName: selectedIcon,
                    subject: selectedSubject,
                    gradeLevel: selectedGradeLevel,
                    semester: selectedSemester,
                    startDate: dateFormatter.string(from: startDate),
                    endDate: dateFormatter.string(from: endDate),
                    credits: Double(credits)
                )
                isCreating = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to create course. Please try again."
                isCreating = false
            }
        }
    }
}
