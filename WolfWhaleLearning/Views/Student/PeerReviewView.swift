import SwiftUI

struct PeerReviewView: View {
    @Bindable var viewModel: AppViewModel
    @State private var hapticTrigger = false

    private var myReviews: [PeerReview] {
        guard let userId = viewModel.currentUser?.id else { return [] }
        return viewModel.peerReviews
            .filter { $0.reviewerId == userId }
            .sorted { ($0.status == .assigned ? 0 : $0.status == .inProgress ? 1 : 2)
                    < ($1.status == .assigned ? 0 : $1.status == .inProgress ? 1 : 2) }
    }

    private var pendingReviews: [PeerReview] {
        myReviews.filter { $0.status != .completed }
    }

    private var completedReviews: [PeerReview] {
        myReviews.filter { $0.status == .completed }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                statsRow

                if !pendingReviews.isEmpty {
                    pendingSection
                }

                if !completedReviews.isEmpty {
                    completedSection
                }

                if myReviews.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Peer Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMyPeerReviews()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.indigo.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("My Peer Reviews")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Text("Review your classmates' work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("My peer reviews")
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(label: "Pending", value: "\(pendingReviews.count)", color: .orange)
            statCard(label: "Completed", value: "\(completedReviews.count)", color: .green)
            statCard(label: "Total", value: "\(myReviews.count)", color: .blue)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Pending Section

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Needs Your Review", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(pendingReviews.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
            }

            ForEach(pendingReviews) { review in
                NavigationLink {
                    PeerReviewDetailView(viewModel: viewModel, review: review)
                } label: {
                    reviewCard(review)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Completed Reviews", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            ForEach(completedReviews) { review in
                reviewCard(review)
            }
        }
    }

    // MARK: - Review Card

    private func reviewCard(_ review: PeerReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: review.status.iconName)
                    .font(.title3)
                    .foregroundStyle(statusColor(review.status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.assignmentTitle ?? "Assignment")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Peer's submission to review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(review.status.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor(review.status).opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor(review.status))

                    if let score = review.score {
                        Text("Score: \(Int(score))%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            HStack(spacing: 12) {
                Label("Assigned \(review.createdDate.formatted(.dateTime.month(.abbreviated).day()))", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let completedDate = review.completedDate {
                    Label("Completed \(completedDate.formatted(.dateTime.month(.abbreviated).day()))", systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            if review.status != .completed {
                HStack {
                    Spacer()
                    Label("Start Review", systemImage: "arrow.right.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(review.assignmentTitle ?? "Assignment"), status: \(review.status.displayName)")
        .accessibilityHint(review.status != .completed ? "Double tap to start review" : "Review completed")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Peer Reviews")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))
            Text("When your teacher assigns peer reviews, they will appear here for you to complete.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No peer reviews assigned yet")
    }

    private func statusColor(_ status: PeerReviewStatus) -> Color {
        switch status {
        case .assigned: .orange
        case .inProgress: .blue
        case .completed: .green
        }
    }
}

// MARK: - Peer Review Detail View (Review Submission)

struct PeerReviewDetailView: View {
    @Bindable var viewModel: AppViewModel
    let review: PeerReview

    @State private var score: Double = 75
    @State private var feedback: String = ""
    @State private var rubricScores: [UUID: Int] = [:]
    @State private var showSuccess = false
    @State private var isSubmitting = false
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    /// The submission text being reviewed (anonymized).
    private var submissionText: String {
        let ownerAssignments = viewModel.assignments.filter {
            $0.id == review.assignmentId && $0.studentId == review.submissionOwnerId
        }
        if let submission = ownerAssignments.first?.submission {
            return Assignment.cleanSubmissionText(submission) ?? "No submission text available."
        }
        return "This is the student's submitted work for review. The submission has been anonymized -- you will not see who wrote it."
    }

    /// Rubric for this assignment, if any.
    private var assignmentRubric: Rubric? {
        guard let rubricId = viewModel.assignments.first(where: { $0.id == review.assignmentId })?.rubricId else {
            return nil
        }
        return viewModel.rubrics.first(where: { $0.id == rubricId })
    }

    private var isValid: Bool {
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                submissionSection
                if let rubric = assignmentRubric {
                    rubricScoringSection(rubric)
                } else {
                    scoringSection
                }
                feedbackSection
                submitButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Review Submission")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.markPeerReviewInProgress(reviewId: review.id)
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.indigo.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.assignmentTitle ?? "Peer Review")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text("Anonymous peer review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.orange)
                Text("This review is anonymous. The student will not know who reviewed their work.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Anonymous peer review for \(review.assignmentTitle ?? "assignment")")
    }

    // MARK: - Submission

    private var submissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Student Submission", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            Text(submissionText)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Student submission: \(submissionText)")
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Score Slider

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Score", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            VStack(spacing: 8) {
                HStack {
                    Text("0%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $score, in: 0...100, step: 5)
                        .tint(.indigo)
                    Text("100%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(score))%")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.gradeColor(score))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.gradeColor(score).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Score: \(Int(score)) percent")
    }

    // MARK: - Rubric Scoring

    private func rubricScoringSection(_ rubric: Rubric) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Rubric: \(rubric.title)", systemImage: "list.bullet.rectangle.portrait.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            ForEach(rubric.criteria) { criterion in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(criterion.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        Spacer()
                        Text("\(rubricScores[criterion.id] ?? 0)/\(criterion.maxPoints) pts")
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                    }

                    if !criterion.description.isEmpty {
                        Text(criterion.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Level buttons
                    ForEach(criterion.levels) { level in
                        Button {
                            hapticTrigger.toggle()
                            rubricScores[criterion.id] = level.points
                            recalculateScore(rubric: rubric)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: rubricScores[criterion.id] == level.points
                                    ? "largecircle.fill.circle"
                                    : "circle")
                                    .foregroundStyle(rubricScores[criterion.id] == level.points ? .indigo : .secondary)
                                    .font(.callout)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(level.label)
                                        .font(.caption.bold())
                                        .foregroundStyle(Color(.label))
                                    if !level.description.isEmpty {
                                        Text(level.description)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text("\(level.points) pts")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.indigo.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.indigo)
                            }
                            .padding(8)
                            .background(
                                rubricScores[criterion.id] == level.points
                                    ? Color.indigo.opacity(0.08)
                                    : Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: hapticTrigger)
                        .accessibilityLabel("\(level.label), \(level.points) points")
                        .accessibilityHint(rubricScores[criterion.id] == level.points ? "Currently selected" : "Double tap to select")
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            }

            // Total
            HStack {
                Text("Total Rubric Score")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                let totalEarned = rubricScores.values.reduce(0, +)
                Text("\(totalEarned)/\(rubric.totalPoints)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }
            .padding(10)
            .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Written Feedback", systemImage: "text.bubble.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            Text("Provide constructive, helpful feedback for your peer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Your feedback...", text: $feedback, axis: .vertical)
                .lineLimit(4...)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Feedback text field")

            if feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Feedback is required to submit your review.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: 8) {
            Button {
                hapticTrigger.toggle()
                submitReview()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Submit Review", systemImage: "paperplane.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(!isValid || isSubmitting || review.status == .completed)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel("Submit peer review")
            .accessibilityHint(isValid ? "Submits your score and feedback" : "Please provide feedback first")

            if review.status == .completed {
                Text("You have already submitted this review.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
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
                Text("Review Submitted")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("Score: \(Int(score))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
            dismiss()
        }
    }

    // MARK: - Actions

    private func recalculateScore(rubric: Rubric) {
        let totalEarned = Double(rubricScores.values.reduce(0, +))
        let totalPossible = Double(rubric.totalPoints)
        if totalPossible > 0 {
            score = (totalEarned / totalPossible) * 100
        }
    }

    private func submitReview() {
        isSubmitting = true

        viewModel.submitPeerReview(
            reviewId: review.id,
            score: score,
            feedback: feedback,
            rubricScores: rubricScores.isEmpty ? nil : rubricScores
        )

        isSubmitting = false
        withAnimation(.snappy) { showSuccess = true }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSuccess = false }
            dismiss()
        }
    }
}
