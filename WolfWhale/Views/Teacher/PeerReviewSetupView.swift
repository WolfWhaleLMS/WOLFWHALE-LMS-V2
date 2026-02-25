import SwiftUI

struct PeerReviewSetupView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course
    let assignment: Assignment

    @State private var peerReviewEnabled = false
    @State private var reviewsPerSubmission: Int = 2
    @State private var showAssignConfirmation = false
    @State private var showSuccess = false
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var assignmentReviews: [PeerReview] {
        viewModel.peerReviews.filter { $0.assignmentId == assignment.id }
    }

    private var completedReviews: [PeerReview] {
        assignmentReviews.filter { $0.status == .completed }
    }

    private var inProgressReviews: [PeerReview] {
        assignmentReviews.filter { $0.status == .inProgress }
    }

    private var assignedReviews: [PeerReview] {
        assignmentReviews.filter { $0.status == .assigned }
    }

    private var submittedStudentCount: Int {
        let submitted = viewModel.assignments.filter { $0.id == assignment.id && $0.isSubmitted }
        let uniqueIds = Set(submitted.compactMap(\.studentId))
        return uniqueIds.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                toggleSection
                if peerReviewEnabled {
                    configSection
                    assignButton
                    if !assignmentReviews.isEmpty {
                        statusOverviewSection
                        reviewListSection
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Peer Review Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadPeerReviews(assignmentId: assignment.id)
            peerReviewEnabled = !assignmentReviews.isEmpty
        }
        .alert("Assign Reviewers", isPresented: $showAssignConfirmation) {
            Button("Assign", role: .none) {
                performAssignment()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will randomly assign \(reviewsPerSubmission) reviewer(s) per submission. Any existing peer review assignments for this assignment will be replaced.")
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text("\(course.title) -- \(submittedStudentCount) submissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title), \(submittedStudentCount) submissions")
    }

    // MARK: - Enable Toggle

    private var toggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enable Peer Review")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("Students review each other's submissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $peerReviewEnabled)
                .labelsHidden()
                .tint(.red)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Enable peer review, currently \(peerReviewEnabled ? "on" : "off")")
        .accessibilityHint("Double tap to toggle")
    }

    // MARK: - Configuration

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Configuration", systemImage: "gearshape.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewers per Submission")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Text("Each submission will be reviewed by this many peers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Stepper("\(reviewsPerSubmission)", value: $reviewsPerSubmission, in: 1...5)
                    .frame(width: 140)
            }

            // Info card
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("How it works")
                        .font(.caption.bold())
                        .foregroundStyle(Color(.label))
                    Text("Submissions are anonymized. Each student receives peer submissions to review and provides scores and feedback. Reviews are anonymous to encourage honest feedback.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Assign Button

    private var assignButton: some View {
        VStack(spacing: 8) {
            Button {
                hapticTrigger.toggle()
                showAssignConfirmation = true
            } label: {
                Label("Assign Reviewers", systemImage: "person.badge.plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(submittedStudentCount < 2)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel("Assign reviewers")
            .accessibilityHint(submittedStudentCount < 2
                ? "Needs at least 2 submissions"
                : "Randomly assigns \(reviewsPerSubmission) reviewers per submission")

            if submittedStudentCount < 2 {
                Text("At least 2 student submissions are required to assign peer reviews.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Status Overview

    private var statusOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Review Status", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack(spacing: 12) {
                statusCard(
                    label: "Total",
                    value: "\(assignmentReviews.count)",
                    color: .blue
                )
                statusCard(
                    label: "Completed",
                    value: "\(completedReviews.count)",
                    color: .green
                )
                statusCard(
                    label: "In Progress",
                    value: "\(inProgressReviews.count)",
                    color: .red
                )
                statusCard(
                    label: "Pending",
                    value: "\(assignedReviews.count)",
                    color: .secondary
                )
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                let completionRate = assignmentReviews.isEmpty
                    ? 0.0
                    : Double(completedReviews.count) / Double(assignmentReviews.count)
                Text("Completion: \(Int(completionRate * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.label))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green.gradient)
                            .frame(width: geo.size.width * completionRate, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusCard(label: String, value: String, color: Color) -> some View {
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
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Review List

    private var reviewListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Assigned Reviews", systemImage: "list.bullet.clipboard.fill")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(assignmentReviews.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(assignmentReviews) { review in
                reviewRow(review)
            }
        }
    }

    private func reviewRow(_ review: PeerReview) -> some View {
        HStack(spacing: 10) {
            // Status icon
            Image(systemName: review.status.iconName)
                .font(.callout)
                .foregroundStyle(statusColor(review.status))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reviewer: \(review.reviewerName ?? "Student")")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.label))
                Text("Reviewing: \(review.submissionOwnerName ?? "Student")")
                    .font(.caption2)
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
                    Text("\(Int(score))%")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Review by \(review.reviewerName ?? "student") of \(review.submissionOwnerName ?? "student"), status: \(review.status.displayName)")
    }

    private func statusColor(_ status: PeerReviewStatus) -> Color {
        switch status {
        case .assigned: .red
        case .inProgress: .blue
        case .completed: .green
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
                Text("Reviewers Assigned")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("\(viewModel.peerReviews.filter { $0.assignmentId == assignment.id }.count) peer reviews created")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - Actions

    private func performAssignment() {
        viewModel.assignPeerReviewers(
            assignmentId: assignment.id,
            reviewsPerSubmission: reviewsPerSubmission
        )

        withAnimation(.snappy) {
            showSuccess = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showSuccess = false }
        }
    }
}
