import SwiftUI

struct AssignmentsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedFilter = 0
    @State private var showSubmitSheet = false
    @State private var selectedAssignment: Assignment?
    @State private var resubmitAssignment: Assignment?
    @State private var hapticTrigger = false

    private var filtered: [Assignment] {
        switch selectedFilter {
        case 1: return viewModel.assignments.filter { !$0.isSubmitted && !$0.isOverdue }
        case 2: return viewModel.assignments.filter { $0.isSubmitted }
        case 3: return viewModel.assignments.filter { $0.isOverdue }
        default: return viewModel.assignments
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    filterBar
                    ForEach(filtered) { assignment in
                        assignmentRow(assignment)
                            .onAppear {
                                if assignment.id == filtered.last?.id {
                                    Task { await viewModel.loadMoreAssignments() }
                                }
                            }
                    }
                    if viewModel.assignmentPagination.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .overlay {
                if viewModel.assignments.isEmpty {
                    ContentUnavailableView(
                        "No Assignments",
                        systemImage: "doc.text",
                        description: Text("Assignments from your courses will appear here")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Matching Assignments",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different filter to see assignments")
                    )
                }
            }
            .refreshable {
                await viewModel.refreshAssignments()
            }
            .navigationTitle("Assignments")
            .task { await viewModel.loadAssignmentsIfNeeded() }
            .sheet(item: $selectedAssignment) { assignment in
                submitSheet(assignment)
            }
            .sheet(item: $resubmitAssignment) { assignment in
                ResubmitAssignmentView(assignment: assignment, viewModel: viewModel)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(["All", "Pending", "Submitted", "Overdue"].enumerated()), id: \.offset) { index, label in
                    Button(label) {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) { selectedFilter = index }
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selectedFilter == index ? .purple.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(selectedFilter == index ? .purple : .secondary)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("\(label) filter")
                    .accessibilityAddTraits(selectedFilter == index ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(.headline)
                    Text(assignment.courseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge(assignment)
                    if let lateBadge = assignment.latePenaltyBadgeText {
                        latePenaltyBadge(lateBadge)
                    }
                }
            }

            HStack(spacing: 16) {
                Label(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                Label("\(assignment.points) pts", systemImage: "star.fill")
                if assignment.latePenaltyType != .none {
                    Label(assignment.latePenaltyType.displayName, systemImage: assignment.latePenaltyType.iconName)
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Late policy info for overdue assignments
            if assignment.isOverdue && assignment.latePenaltyType != .none {
                latePolicyInfoBanner(assignment)
            }

            // Submit button for pending assignments
            if !assignment.isSubmitted && !assignment.isOverdue {
                Button {
                    hapticTrigger.toggle()
                    selectedAssignment = assignment
                } label: {
                    Text("Submit")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            // Late submit button for overdue assignments that can still be submitted
            if !assignment.isSubmitted && assignment.isOverdue && assignment.canSubmitLate {
                Button {
                    hapticTrigger.toggle()
                    selectedAssignment = assignment
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text("Submit Late")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            // Resubmit button for graded assignments that allow resubmission
            if assignment.canResubmit {
                resubmitSection(assignment)
            }

            // Resubmission history
            if !assignment.resubmissionHistory.isEmpty {
                resubmissionHistorySection(assignment)
            }

            if let feedback = assignment.feedback {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(.blue)
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(assignmentAccessibilityLabel(assignment))
        .accessibilityHint(assignmentAccessibilityHint(assignment))
    }

    // MARK: - Late Penalty Badge

    private func latePenaltyBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.red.opacity(0.15), in: Capsule())
            .foregroundStyle(.red)
    }

    // MARK: - Late Policy Info Banner

    private func latePolicyInfoBanner(_ assignment: Assignment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                if assignment.canSubmitLate {
                    Text("Late submission accepted")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    let remaining = assignment.maxLateDays - assignment.daysLate
                    if remaining > 0 {
                        Text("\(remaining) day\(remaining == 1 ? "" : "s") remaining to submit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Late submission deadline has passed")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 8))
    }

    // MARK: - Resubmit Section

    private func resubmitSection(_ assignment: Assignment) -> some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resubmission Available")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    Text("\(assignment.remainingResubmissions) of \(assignment.maxResubmissions) resubmission\(assignment.maxResubmissions == 1 ? "" : "s") remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let deadline = assignment.resubmissionDeadline {
                        Text("Deadline: \(deadline.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(8)
            .background(.indigo.opacity(0.08), in: .rect(cornerRadius: 8))

            Button {
                hapticTrigger.toggle()
                resubmitAssignment = assignment
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Resubmit")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
    }

    // MARK: - Resubmission History

    private func resubmissionHistorySection(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Previous Submissions")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            ForEach(assignment.resubmissionHistory) { entry in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.submittedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let grade = entry.grade {
                        Text("\(Int(grade))%")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.gradeColor(grade))
                    } else {
                        Text("--")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 6))
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
    }

    private func statusBadge(_ assignment: Assignment) -> some View {
        Text(assignment.statusText)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(assignment).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(assignment))
    }

    private func statusColor(_ assignment: Assignment) -> Color {
        if assignment.grade != nil { return .green }
        if assignment.isSubmitted { return .blue }
        if assignment.isOverdue {
            return assignment.canSubmitLate ? .orange : .red
        }
        return .orange
    }

    private func submitSheet(_ assignment: Assignment) -> some View {
        SubmitAssignmentView(assignment: assignment, viewModel: viewModel)
    }

    // MARK: - Accessibility Helpers

    private func assignmentAccessibilityLabel(_ assignment: Assignment) -> String {
        var label = "\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())), \(assignment.points) points, status: \(assignment.statusText)"
        if let lateBadge = assignment.latePenaltyBadgeText {
            label += ", \(lateBadge)"
        }
        if assignment.canResubmit {
            label += ", resubmission available"
        }
        return label
    }

    private func assignmentAccessibilityHint(_ assignment: Assignment) -> String {
        if assignment.canResubmit {
            return "Contains resubmit button"
        }
        if !assignment.isSubmitted && !assignment.isOverdue {
            return "Contains submit button"
        }
        if !assignment.isSubmitted && assignment.isOverdue && assignment.canSubmitLate {
            return "Contains late submit button"
        }
        return ""
    }
}

// MARK: - Resubmit Assignment View

struct ResubmitAssignmentView: View {
    let assignment: Assignment
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var responseText = ""
    @State private var attachments: [PickedFile] = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var hapticTrigger = false

    private let fileUploadService = FileUploadService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        resubmissionInfoCard
                        previousGradeCard
                        responseSection
                        attachmentsSection
                        resubmitButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }

                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView("Resubmitting...")
                                .font(.subheadline)
                            Text("Please wait while your resubmission is being uploaded.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .navigationTitle("Resubmit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .disabled(isSubmitting)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .alert("Resubmission Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Resubmitted!", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your assignment has been resubmitted successfully. Your previous grade has been saved to history.")
            }
        }
    }

    // MARK: - Resubmission Info Card

    private var resubmissionInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(assignment.title)
                .font(.title3.bold())

            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
                Text(assignment.courseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(.indigo)
                    Text("Resubmission \(assignment.resubmissionCount + 1) of \(assignment.maxResubmissions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let deadline = assignment.resubmissionDeadline {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.orange)
                        Text("Due: \(deadline.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !assignment.instructions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instructions")
                        .font(.subheadline.bold())
                    Text(assignment.instructions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Previous Grade Card

    private var previousGradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Previous Grade", systemImage: "chart.bar.fill")
                .font(.headline)

            HStack(spacing: 16) {
                if let grade = assignment.grade {
                    VStack(spacing: 4) {
                        Text("\(Int(grade))%")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.gradeColor(grade))
                        Text("Current Grade")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.gradeColor(grade).opacity(0.1), in: .rect(cornerRadius: 8))
                }

                VStack(spacing: 4) {
                    Text("\(assignment.resubmissionHistory.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.indigo)
                    Text("Past Attempts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.indigo.opacity(0.1), in: .rect(cornerRadius: 8))
            }

            if let feedback = assignment.feedback, !feedback.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(.blue)
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your New Response")
                .font(.headline)

            EnhancedTextEditor(
                text: $responseText,
                placeholder: "Write your updated response here...",
                minHeight: 150
            )
            .clipShape(.rect(cornerRadius: 10))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Attachments Section

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments")
                    .font(.headline)
                Spacer()
                Text("Max 10 MB each")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FileAttachmentView(attachments: $attachments, maxAttachments: 5)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Resubmit Button

    private var resubmitButton: some View {
        Button {
            hapticTrigger.toggle()
            Task {
                await submitResubmission()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("Resubmit Assignment")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(isSubmitDisabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    // MARK: - Helpers

    private var isSubmitDisabled: Bool {
        (responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty) || isSubmitting
    }

    private func submitResubmission() async {
        isSubmitting = true
        defer { isSubmitting = false }

        guard let user = viewModel.currentUser else {
            errorMessage = "You must be logged in to resubmit."
            showError = true
            return
        }

        var uploadedURLs: [String] = []

        for file in attachments {
            let storagePath = "\(user.id.uuidString)/\(assignment.id.uuidString)/resub_\(assignment.resubmissionCount + 1)_\(file.name)"
            do {
                let publicURL = try await fileUploadService.uploadFile(
                    bucket: FileUploadService.Bucket.assignmentSubmissions,
                    path: storagePath,
                    fileURL: file.url
                )
                uploadedURLs.append(publicURL)
            } catch {
                errorMessage = "Failed to upload \(file.name): \(error.localizedDescription)"
                showError = true
                return
            }
        }

        var submissionContent = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uploadedURLs.isEmpty {
            let urlsSection = uploadedURLs.joined(separator: "\n")
            if submissionContent.isEmpty {
                submissionContent = "[Attachments]\n\(urlsSection)"
            } else {
                submissionContent += "\n\n[Attachments]\n\(urlsSection)"
            }
        }

        viewModel.resubmitAssignment(assignmentId: assignment.id, newText: submissionContent)
        showSuccess = true
    }
}
