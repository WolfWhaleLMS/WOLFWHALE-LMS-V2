import SwiftUI

struct GradeSubmissionView: View {
    @Bindable var viewModel: AppViewModel
    let assignment: Assignment

    @State private var scoreText = ""
    @State private var letterGrade = ""
    @State private var feedback = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var numericScore: Double? {
        Double(scoreText)
    }

    private var autoLetterGrade: String {
        guard let score = numericScore else { return "--" }
        switch score {
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

    private var isValid: Bool {
        guard let score = numericScore else { return false }
        return score >= 0 && score <= Double(assignment.points)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                assignmentHeader
                submissionSection
                gradingSection
                feedbackSection
                saveButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grade Submission")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Assignment Header

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    Text(assignment.title)
                        .font(.headline)
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Student identification
            if let studentName = assignment.studentName {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.pink)
                    Text(studentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.pink.opacity(0.1), in: .rect(cornerRadius: 10))
            }

            HStack(spacing: 16) {
                Label("Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))", systemImage: "calendar")
                Label("\(assignment.points) pts", systemImage: "star.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Submission Section

    private var submissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Student Submission", systemImage: "person.text.rectangle")
                .font(.headline)

            if let submission = assignment.submission, !submission.isEmpty {
                Text(submission)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No submission text available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Grading Section

    private var gradingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Score", systemImage: "pencil.and.list.clipboard")
                .font(.headline)

            HStack(spacing: 12) {
                // Score input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $scoreText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("/ \(assignment.points)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Letter grade
                VStack(alignment: .leading, spacing: 4) {
                    Text("Letter Grade")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(letterGrade.isEmpty ? autoLetterGrade : letterGrade)
                            .font(.title2.bold())
                            .foregroundStyle(gradeColor)
                            .frame(minWidth: 40)

                        TextField("Auto", text: $letterGrade)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                }
            }

            if let score = numericScore {
                // Percentage bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Percentage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(score / Double(assignment.points) * 100))%")
                            .font(.caption.bold())
                            .foregroundStyle(gradeColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                            Capsule()
                                .fill(gradeColor.gradient)
                                .frame(width: geo.size.width * min(score / Double(assignment.points), 1.0))
                        }
                    }
                    .frame(height: 8)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Feedback", systemImage: "text.bubble")
                .font(.headline)

            TextField("Write feedback for the student...", text: $feedback, axis: .vertical)
                .lineLimit(5...)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            hapticTrigger.toggle()
            saveGrade()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Save Grade", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .disabled(isLoading || !isValid)
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
                Text("Grade Saved")
                    .font(.title3.bold())
                Text("\(assignment.title) graded successfully")
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

    private var gradeColor: Color {
        guard let score = numericScore else { return .secondary }
        let pct = score / Double(assignment.points) * 100
        return Theme.gradeColor(pct)
    }

    private func saveGrade() {
        guard let score = numericScore else { return }
        isLoading = true
        errorMessage = nil

        let finalLetterGrade = letterGrade.isEmpty ? autoLetterGrade : letterGrade
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await viewModel.gradeSubmission(
                    assignmentId: assignment.id,
                    studentId: assignment.studentId,
                    score: score,
                    letterGrade: finalLetterGrade,
                    feedback: trimmedFeedback.isEmpty ? nil : trimmedFeedback
                )
                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to save grade. Please try again."
                isLoading = false
            }
        }
    }
}
