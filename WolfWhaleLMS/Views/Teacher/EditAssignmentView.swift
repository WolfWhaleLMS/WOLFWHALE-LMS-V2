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

    @Environment(\.dismiss) private var dismiss

    init(assignment: Assignment, viewModel: AppViewModel) {
        self.assignment = assignment
        self.viewModel = viewModel
        _title = State(initialValue: assignment.title)
        _instructions = State(initialValue: assignment.instructions)
        _dueDate = State(initialValue: assignment.dueDate)
        _points = State(initialValue: assignment.points)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        title != assignment.title ||
        instructions != assignment.instructions ||
        dueDate != assignment.dueDate ||
        points != assignment.points
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                assignmentHeader
                detailsSection
                dueDateSection
                pointsSection
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
                    dismiss()
                }
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
            HStack(spacing: 16) {
                pointsPreview(label: "Points", value: "\(points)", color: .pink)
                pointsPreview(label: "XP Reward", value: "\(points / 2)", color: .purple)
            }
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
        }
        .padding(.top, 4)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button {
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

                // Update local state
                for index in viewModel.assignments.indices {
                    if viewModel.assignments[index].id == assignment.id &&
                       viewModel.assignments[index].studentId == assignment.studentId {
                        viewModel.assignments[index].title = trimmedTitle
                        viewModel.assignments[index].instructions = trimmedInstructions
                        viewModel.assignments[index].dueDate = dueDate
                        viewModel.assignments[index].points = points
                    }
                }

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
