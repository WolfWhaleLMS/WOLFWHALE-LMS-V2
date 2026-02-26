import SwiftUI

/// A full-screen view for students to submit an assignment with text and file attachments.
struct SubmitAssignmentView: View {
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
                        assignmentInfoCard
                        responseSection
                        attachmentsSection
                        submitButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }

                // Loading overlay
                if isSubmitting {
                    loadingOverlay
                }
            }
            .navigationTitle("Submit Assignment")
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
            .alert("Submission Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Submitted!", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your assignment has been submitted successfully.")
            }
            .alert("Submission Failed", isPresented: Binding(
                get: { viewModel.submissionError != nil },
                set: { if !$0 { viewModel.submissionError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.submissionError ?? "Your assignment was not saved to the server. Please try submitting again.")
            }
        }
    }

    // MARK: - Assignment Info Card

    private var assignmentInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(assignment.title)
                .font(.title3.bold())

            // Course name
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
                Text(assignment.courseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Instructions
            if !assignment.instructions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instructions")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(assignment.instructions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Due date, points
            HStack(spacing: 20) {
                infoLabel(
                    icon: "calendar",
                    text: assignment.dueDate.formatted(.dateTime.month(.abbreviated).day().year()),
                    color: assignment.isOverdue ? .red : .orange
                )
                infoLabel(
                    icon: "star.fill",
                    text: "\(assignment.points) pts",
                    color: .orange
                )
            }

            // Late policy info
            if assignment.latePenaltyType != .none {
                latePolicyInfoSection
            }

            // Overdue warning with late penalty details
            if assignment.isOverdue {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("This assignment is past due")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }

                    if let lateBadge = assignment.latePenaltyBadgeText {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            Text(lateBadge)
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }

                    if assignment.canSubmitLate {
                        let remaining = assignment.maxLateDays - assignment.daysLate
                        if remaining > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("You have \(remaining) day\(remaining == 1 ? "" : "s") left to submit with a late penalty.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if assignment.latePenaltyType != .none {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text("The late submission window has closed. No further submissions accepted.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Response")
                .font(.headline)

            EnhancedTextEditor(
                text: $responseText,
                placeholder: "Write your response here...",
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

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            hapticTrigger.toggle()
            Task {
                await submitAssignment()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("Submit Assignment")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(isSubmitDisabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView("Uploading files...")
                    .font(.subheadline)
                Text("Please wait while your submission is being uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private var isSubmitDisabled: Bool {
        let noContent = responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
        let lateWindowClosed = assignment.isOverdue && !assignment.canSubmitLate
        return noContent || isSubmitting || assignment.isSubmitted || lateWindowClosed
    }

    // MARK: - Late Policy Info Section

    private var latePolicyInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: assignment.latePenaltyType.iconName)
                    .foregroundStyle(.orange)
                Text("Late Policy: \(assignment.latePenaltyType.displayName)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            switch assignment.latePenaltyType {
            case .percentPerDay:
                Text("\(Int(assignment.latePenaltyPerDay))% deducted per day late, up to \(assignment.maxLateDays) days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .flatDeduction:
                Text("\(Int(assignment.latePenaltyPerDay)) points deducted per day late, up to \(assignment.maxLateDays) days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .noCredit:
                Text("No credit awarded for late submissions.")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .none:
                EmptyView()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 8))
    }

    private func infoLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Submission Logic

    private func submitAssignment() async {
        isSubmitting = true
        defer { isSubmitting = false }

        guard let user = viewModel.currentUser else {
            errorMessage = "You must be logged in to submit."
            showError = true
            return
        }

        var uploadedURLs: [String] = []

        // Upload each attached file
        for file in attachments {
            let storagePath = "\(user.id.uuidString)/\(assignment.id.uuidString)/\(file.name)"
            do {
                let publicURL = try await fileUploadService.uploadFile(
                    bucket: FileUploadService.Bucket.assignmentSubmissions,
                    path: storagePath,
                    fileURL: file.url
                )
                uploadedURLs.append(publicURL)
            } catch {
                errorMessage = "Failed to upload \(file.name): \(UserFacingError.message(from: error))"
                showError = true

                // Clean up any files already uploaded in this batch
                for uploaded in uploadedURLs {
                    if let urlPath = extractStoragePath(from: uploaded) {
                        try? await fileUploadService.deleteFile(
                            bucket: FileUploadService.Bucket.assignmentSubmissions,
                            path: urlPath
                        )
                    }
                }
                return
            }
        }

        // Build the submission content: text + attachment URLs
        var submissionContent = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uploadedURLs.isEmpty {
            let urlsSection = uploadedURLs.joined(separator: "\n")
            if submissionContent.isEmpty {
                submissionContent = "[Attachments]\n\(urlsSection)"
            } else {
                submissionContent += "\n\n[Attachments]\n\(urlsSection)"
            }
        }

        // Submit via the view model
        viewModel.submitAssignment(assignment, text: submissionContent)
        showSuccess = true
    }

    /// Extracts the storage path portion from a full Supabase public URL.
    private func extractStoragePath(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let components = url.pathComponents
        // Look for the bucket name in the path and return everything after it
        if let bucketIndex = components.firstIndex(of: FileUploadService.Bucket.assignmentSubmissions) {
            let pathComponents = components[(bucketIndex + 1)...]
            return pathComponents.joined(separator: "/")
        }
        return nil
    }
}
