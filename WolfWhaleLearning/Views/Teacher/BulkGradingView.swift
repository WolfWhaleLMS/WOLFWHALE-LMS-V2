import SwiftUI

struct BulkGradingView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCourseId: UUID?
    @State private var gradeEntries: [BulkGradeEntry] = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var successCount = 0
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    /// Ungraded submitted assignments for the selected course.
    private var ungradedSubmissions: [Assignment] {
        guard let courseId = selectedCourseId else { return [] }
        return viewModel.assignments.filter {
            $0.courseId == courseId && $0.isSubmitted && $0.grade == nil
        }
    }

    /// Number of entries with a valid score filled in.
    private var filledCount: Int {
        gradeEntries.filter { entry in
            guard let score = Double(entry.scoreText) else { return false }
            guard let assignment = ungradedSubmissions.first(where: { $0.id == entry.assignmentId && $0.studentId == entry.studentId }) else { return false }
            return score >= 0 && score <= Double(assignment.points)
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    coursePicker
                    if selectedCourseId != nil {
                        if ungradedSubmissions.isEmpty {
                            emptyState
                        } else {
                            submissionsList
                            gradeAllButton
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bulk Grading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Course Picker

    private var coursePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Course", systemImage: "book.fill")
                .font(.headline)

            if viewModel.courses.isEmpty {
                Text("No courses available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.courses) { course in
                            courseChip(course)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func courseChip(_ course: Course) -> some View {
        let isSelected = selectedCourseId == course.id
        let color = Theme.courseColor(course.colorName)

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                selectedCourseId = course.id
                buildGradeEntries()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: course.iconSystemName)
                    .font(.caption)
                Text(course.title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(course.title)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("All Caught Up")
                .font(.headline)
            Text("No ungraded submissions for this course.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Submissions List

    private var submissionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(ungradedSubmissions.count) Ungraded", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                Text("\(filledCount) ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(gradeEntries.enumerated()), id: \.element.id) { index, entry in
                if let assignment = ungradedSubmissions.first(where: { $0.id == entry.assignmentId && $0.studentId == entry.studentId }) {
                    submissionRow(assignment: assignment, index: index)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func submissionRow(assignment: Assignment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: student name + assignment title
            HStack(spacing: 10) {
                Circle()
                    .fill(.red.gradient)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.studentName ?? "Unknown Student")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(assignment.title)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                }
                Spacer()
                Text("\(assignment.points) pts")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Grade input row
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    TextField("Score", text: $gradeEntries[index].scoreText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("/ \(assignment.points)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Auto letter grade preview
                if let score = Double(gradeEntries[index].scoreText) {
                    let pct = Double(assignment.points) > 0 ? (score / Double(assignment.points)) * 100 : 0
                    Text(letterGrade(from: pct))
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gradeColor(pct))
                        .frame(minWidth: 28)
                }

                // Expand feedback toggle
                Button {
                    withAnimation(.snappy) {
                        gradeEntries[index].showFeedback.toggle()
                    }
                } label: {
                    Image(systemName: gradeEntries[index].showFeedback ? "text.bubble.fill" : "text.bubble")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(gradeEntries[index].showFeedback ? "Hide feedback" : "Add feedback")
            }

            // Expandable feedback field
            if gradeEntries[index].showFeedback {
                TextField("Feedback (optional)", text: $gradeEntries[index].feedback, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Submission by \(assignment.studentName ?? "Unknown") for \(assignment.title)")
    }

    // MARK: - Grade All Button

    private var gradeAllButton: some View {
        Button {
            hapticTrigger.toggle()
            submitAllGrades()
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Grade All (\(filledCount))", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isSubmitting || filledCount == 0)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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
                Text("Grades Saved")
                    .font(.title3.bold())
                Text("\(successCount) submission\(successCount == 1 ? "" : "s") graded successfully")
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

    // MARK: - Helpers

    private func buildGradeEntries() {
        gradeEntries = ungradedSubmissions.map { assignment in
            BulkGradeEntry(
                assignmentId: assignment.id,
                studentId: assignment.studentId,
                scoreText: "",
                feedback: "",
                showFeedback: false
            )
        }
    }

    private func submitAllGrades() {
        isSubmitting = true
        errorMessage = nil

        let gradesToSubmit: [(assignmentId: UUID, studentId: UUID?, score: Double, feedback: String)] = gradeEntries.compactMap { entry in
            guard let score = Double(entry.scoreText) else { return nil }
            guard let assignment = ungradedSubmissions.first(where: { $0.id == entry.assignmentId && $0.studentId == entry.studentId }) else { return nil }
            guard score >= 0, score <= Double(assignment.points) else { return nil }
            return (assignmentId: entry.assignmentId, studentId: entry.studentId, score: score, feedback: entry.feedback)
        }

        guard !gradesToSubmit.isEmpty else {
            isSubmitting = false
            return
        }

        Task {
            do {
                let count = try await viewModel.bulkGradeSubmissions(grades: gradesToSubmit)
                isSubmitting = false
                successCount = count

                // Check for partial failures reported by the ViewModel
                if let partialError = viewModel.gradeError {
                    errorMessage = partialError
                } else {
                    withAnimation(.snappy) {
                        showSuccess = true
                    }
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { showSuccess = false }
                    dismiss()
                }
            } catch {
                errorMessage = viewModel.gradeError ?? "Failed to submit grades. Please try again."
                isSubmitting = false
            }
        }
    }

    private func letterGrade(from percentage: Double) -> String {
        switch percentage {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }
}

// MARK: - Bulk Grade Entry Model

struct BulkGradeEntry: Identifiable {
    let id = UUID()
    let assignmentId: UUID
    let studentId: UUID?
    var scoreText: String
    var feedback: String
    var showFeedback: Bool
}
