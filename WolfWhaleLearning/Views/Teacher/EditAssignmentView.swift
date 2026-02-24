import SwiftUI

struct EditAssignmentView: View {
    let assignment: Assignment
    @Bindable var viewModel: AppViewModel

    @State private var title: String
    @State private var instructions: String
    @State private var dueDate: Date
    @State private var points: Int
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    // Duplicate / Template state
    @State private var isDuplicating = false
    @State private var showDuplicateSuccess = false
    @State private var showSaveTemplateSheet = false
    @State private var templateName: String = ""
    @State private var showTemplateSaved = false

    // Late Policy state
    @State private var latePenaltyType: LatePenaltyType
    @State private var latePenaltyPerDay: Double
    @State private var maxLateDays: Int

    // Resubmission state
    @State private var allowResubmission: Bool
    @State private var maxResubmissions: Int
    @State private var resubmissionDeadline: Date
    @State private var hasResubmissionDeadline: Bool

    @Environment(\.dismiss) private var dismiss

    init(assignment: Assignment, viewModel: AppViewModel) {
        self.assignment = assignment
        self.viewModel = viewModel
        _title = State(initialValue: assignment.title)
        _instructions = State(initialValue: assignment.instructions)
        _dueDate = State(initialValue: assignment.dueDate)
        _points = State(initialValue: assignment.points)
        _latePenaltyType = State(initialValue: assignment.latePenaltyType)
        _latePenaltyPerDay = State(initialValue: assignment.latePenaltyPerDay)
        _maxLateDays = State(initialValue: assignment.maxLateDays)
        _allowResubmission = State(initialValue: assignment.allowResubmission)
        _maxResubmissions = State(initialValue: assignment.maxResubmissions)
        _resubmissionDeadline = State(initialValue: assignment.resubmissionDeadline ?? Date().addingTimeInterval(14 * 86400))
        _hasResubmissionDeadline = State(initialValue: assignment.resubmissionDeadline != nil)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        title != assignment.title ||
        instructions != assignment.instructions ||
        dueDate != assignment.dueDate ||
        points != assignment.points ||
        latePenaltyType != assignment.latePenaltyType ||
        latePenaltyPerDay != assignment.latePenaltyPerDay ||
        maxLateDays != assignment.maxLateDays ||
        allowResubmission != assignment.allowResubmission ||
        maxResubmissions != assignment.maxResubmissions ||
        hasResubmissionDeadline != (assignment.resubmissionDeadline != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                assignmentHeader
                detailsSection
                dueDateSection
                pointsSection
                latePolicySection
                resubmissionSection
                quickActionsSection
                saveButton
                deleteSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .alert("Delete Assignment", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteAssignment()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(assignment.title)\"? All student submissions for this assignment will also be removed. This action cannot be undone.")
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .allowsHitTesting(!isDeleting)
        .sheet(isPresented: $showSaveTemplateSheet) {
            saveTemplateSheet
        }
        .overlay {
            if showDuplicateSuccess {
                duplicateSuccessOverlay
            }
            if showTemplateSaved {
                templateSavedOverlay
            }
        }
    }

    // MARK: - Assignment Header

    private var assignmentHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.pink.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.courseName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("\(assignment.points) pts", systemImage: "star.fill")
                    if assignment.isSubmitted {
                        Label("Submitted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Assignment Details", systemImage: "pencil.line")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Assignment Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Assignment instructions...", text: $instructions, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Due Date Section

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Due Date", systemImage: "calendar")
                .font(.headline)

            DatePicker(
                "Due Date",
                selection: $dueDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(.pink)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Points Section

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Points", systemImage: "star.fill")
                .font(.headline)

            Stepper("Points: \(points)", value: $points, in: 10...500, step: 10)
                .font(.subheadline)

            // Points preview
            pointsPreview(label: "Points", value: "\(points)", color: .pink)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func pointsPreview(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 8))
    }

    // MARK: - Late Policy Section

    private var latePolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Late Policy", systemImage: "clock.badge.exclamationmark")
                .font(.headline)

            // Penalty type picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Penalty Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Penalty Type", selection: $latePenaltyType) {
                    ForEach(LatePenaltyType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            if latePenaltyType != .none && latePenaltyType != .noCredit {
                HStack {
                    Text("Penalty per day")
                        .font(.subheadline)
                    Spacer()
                    TextField("10", value: $latePenaltyPerDay, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text(latePenaltyType == .percentPerDay ? "%" : "pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if latePenaltyType != .none {
                Stepper("Max late days: \(maxLateDays)", value: $maxLateDays, in: 1...30)
                    .font(.subheadline)
            }

            // Current late status for this assignment
            if latePenaltyType != .none {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Policy Summary")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    switch latePenaltyType {
                    case .none:
                        EmptyView()
                    case .percentPerDay:
                        Text("Students lose \(Int(latePenaltyPerDay))% per day late, up to \(maxLateDays) days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .flatDeduction:
                        Text("Students lose \(Int(latePenaltyPerDay)) points per day late, up to \(maxLateDays) days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .noCredit:
                        Text("Late submissions receive zero credit.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Resubmission Section

    private var resubmissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Resubmission", systemImage: "arrow.counterclockwise.circle")
                .font(.headline)

            Toggle("Allow Resubmission", isOn: $allowResubmission)
                .font(.subheadline)

            if allowResubmission {
                Stepper("Max resubmissions: \(maxResubmissions)", value: $maxResubmissions, in: 1...5)
                    .font(.subheadline)

                Toggle("Set resubmission deadline", isOn: $hasResubmissionDeadline)
                    .font(.subheadline)

                if hasResubmissionDeadline {
                    DatePicker("Deadline", selection: $resubmissionDeadline, displayedComponents: [.date, .hourAndMinute])
                        .font(.subheadline)
                }

                // Info text
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Students can resubmit \(maxResubmissions) time\(maxResubmissions == 1 ? "" : "s") after being graded. Previous grades are kept in history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Quick Actions (Duplicate, Template, Peer Review)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)

            HStack(spacing: 10) {
                // Duplicate Assignment
                Button {
                    hapticTrigger.toggle()
                    duplicateAssignment()
                } label: {
                    VStack(spacing: 8) {
                        if isDuplicating {
                            ProgressView()
                                .frame(height: 28)
                        } else {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        Text("Duplicate")
                            .font(.caption2.bold())
                            .foregroundStyle(Color(.label))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isDuplicating)
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .accessibilityLabel("Duplicate assignment")
                .accessibilityHint("Creates a copy of this assignment with a new due date")

                // Save as Template
                Button {
                    hapticTrigger.toggle()
                    templateName = assignment.title
                    showSaveTemplateSheet = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                        Text("Save Template")
                            .font(.caption2.bold())
                            .foregroundStyle(Color(.label))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Save as template")
                .accessibilityHint("Saves this assignment as a reusable template")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Save Template Sheet

    private var saveTemplateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Template Name", systemImage: "text.badge.checkmark")
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    TextField("e.g. Weekly Essay", text: $templateName)
                        .textFieldStyle(.roundedBorder)

                    Text("This template will save the title, instructions, and point value so you can reuse it for future assignments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Preview", systemImage: "eye.fill")
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        Text("\(assignment.points) points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !assignment.instructions.isEmpty {
                            Text(assignment.instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Save as Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSaveTemplateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        hapticTrigger.toggle()
                        saveAsTemplate()
                    }
                    .fontWeight(.semibold)
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Duplicate Success Overlay

    private var duplicateSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Assignment Duplicated")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("A copy has been created with a due date one week from now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showDuplicateSuccess = false }
        }
    }

    // MARK: - Template Saved Overlay

    private var templateSavedOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Template Saved")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("\(templateName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showTemplateSaved = false }
        }
    }

    // MARK: - Quick Action Methods

    private func duplicateAssignment() {
        isDuplicating = true
        Task {
            do {
                try await viewModel.duplicateAssignment(assignmentId: assignment.id)
                isDuplicating = false
                withAnimation(.snappy) { showDuplicateSuccess = true }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { showDuplicateSuccess = false }
            } catch {
                errorMessage = "Failed to duplicate assignment."
                isDuplicating = false
            }
        }
    }

    private func saveAsTemplate() {
        viewModel.saveAssignmentAsTemplate(
            assignmentId: assignment.id,
            templateName: templateName
        )
        showSaveTemplateSheet = false
        withAnimation(.snappy) { showTemplateSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showTemplateSaved = false }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
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
                saveAssignment()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isLoading || !isValid || !hasChanges)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(.top, 4)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button {
                hapticTrigger.toggle()
                showDeleteConfirmation = true
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Delete Assignment", systemImage: "trash.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeleting)
            .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)

            Text("This will permanently delete the assignment and all submissions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
                Text("Assignment Updated")
                    .font(.title3.bold())
                Text("\(title) has been saved")
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

    private func saveAssignment() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                if !viewModel.isDemoMode {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let dueDateString = formatter.string(from: dueDate)

                    try await DataService.shared.updateAssignment(
                        assignmentId: assignment.id,
                        title: trimmedTitle,
                        instructions: trimmedInstructions,
                        dueDate: dueDateString,
                        points: points
                    )
                }

                // Update local state (core fields + late policy + resubmission)
                for index in viewModel.assignments.indices {
                    if viewModel.assignments[index].id == assignment.id &&
                       viewModel.assignments[index].studentId == assignment.studentId {
                        viewModel.assignments[index].title = trimmedTitle
                        viewModel.assignments[index].instructions = trimmedInstructions
                        viewModel.assignments[index].dueDate = dueDate
                        viewModel.assignments[index].points = points
                    }
                }

                // Update late policy and resubmission settings via the extension
                viewModel.updateAssignmentPolicy(
                    assignmentId: assignment.id,
                    latePenaltyType: latePenaltyType,
                    latePenaltyPerDay: latePenaltyPerDay,
                    maxLateDays: maxLateDays,
                    allowResubmission: allowResubmission,
                    maxResubmissions: maxResubmissions,
                    resubmissionDeadline: hasResubmissionDeadline ? resubmissionDeadline : nil
                )

                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to update assignment. Please try again."
                isLoading = false
            }
        }
    }

    private func deleteAssignment() {
        isDeleting = true
        errorMessage = nil

        Task {
            do {
                if !viewModel.isDemoMode {
                    try await DataService.shared.deleteAssignment(assignmentId: assignment.id)
                }
                viewModel.assignments.removeAll { $0.id == assignment.id }
                isDeleting = false
                dismiss()
            } catch {
                errorMessage = "Failed to delete assignment. Please try again."
                isDeleting = false
            }
        }
    }
}
