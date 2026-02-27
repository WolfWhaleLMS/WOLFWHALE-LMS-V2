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
    @State private var fileService = FileManagerService()
    @State private var previewFile: FileItem?
    @State private var previewData: Data?
    @State private var showFilePreview = false
    @State private var isLoadingFile = false
    @State private var applyLatePenalty = true

    // MARK: - Rubric Grading State
    /// Maps criterion ID -> selected level points. Updated when teacher taps a rubric level.
    @State private var rubricSelections: [UUID: Int] = [:]

    @Environment(\.dismiss) private var dismiss

    /// The rubric attached to this assignment, if any.
    private var attachedRubric: Rubric? {
        viewModel.rubric(for: assignment.rubricId)
    }

    /// Sum of points selected across all rubric criteria.
    private var rubricTotalSelected: Int {
        rubricSelections.values.reduce(0, +)
    }

    private var numericScore: Double? {
        Double(scoreText)
    }

    private var autoLetterGrade: String {
        guard let score = numericScore else { return "--" }
        let maxPoints = Double(assignment.points)
        let pct = maxPoints > 0 ? (score / maxPoints) * 100 : 0
        switch pct {
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

    /// Attachment URLs extracted from the submission text.
    private var attachmentURLs: [String] {
        Assignment.extractAttachmentURLs(from: assignment.submission)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                assignmentHeader
                if assignment.latePenaltyType != .none && assignment.daysLate > 0 {
                    latePenaltyGradingSection
                }
                if assignment.allowResubmission && assignment.resubmissionCount > 0 {
                    resubmissionInfoSection
                }
                submissionSection
                if !attachmentURLs.isEmpty {
                    attachedFilesSection
                }
                if attachedRubric != nil {
                    rubricGradingSection
                }
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
        .sheet(isPresented: $showFilePreview) {
            if let file = previewFile {
                FilePreviewSheet(file: file, fileData: previewData) {
                    showFilePreview = false
                    previewFile = nil
                    previewData = nil
                }
            }
        }
    }

    // MARK: - Assignment Header

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.red.gradient)
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
                        .foregroundStyle(.red)
                    Text(studentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 10))
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
        let cleanedText = Assignment.cleanSubmissionText(assignment.submission)

        return VStack(alignment: .leading, spacing: 10) {
            Label("Student Submission", systemImage: "person.text.rectangle")
                .font(.headline)

            if let text = cleanedText, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
            } else if attachmentURLs.isEmpty {
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

    // MARK: - Attached Files Section

    private var attachedFilesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Attached Files (\(attachmentURLs.count))", systemImage: "paperclip")
                .font(.headline)

            ForEach(attachmentURLs, id: \.self) { urlString in
                attachmentFileRow(urlString: urlString)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func attachmentFileRow(urlString: String) -> some View {
        let fileName = Self.fileNameFromURL(urlString)
        let ext = (fileName as NSString).pathExtension.lowercased()
        let icon = Self.iconForExtension(ext)
        let color = Self.colorForExtension(ext)

        return Button {
            hapticTrigger.toggle()
            openFilePreview(urlString: urlString, fileName: fileName, ext: ext)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(ext.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isLoadingFile {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "eye.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func openFilePreview(urlString: String, fileName: String, ext: String) {
        isLoadingFile = true
        let nameNoExt = (fileName as NSString).deletingPathExtension

        Task {
            let data = await fileService.downloadFile(url: urlString)
            isLoadingFile = false

            previewFile = FileItem(
                id: UUID(),
                fileName: nameNoExt.isEmpty ? "File" : nameNoExt,
                fileExtension: ext.isEmpty ? "bin" : ext,
                fileSize: Int64(data?.count ?? 0),
                uploadDate: Date(),
                courseId: nil,
                courseName: nil,
                assignmentId: assignment.id,
                assignmentName: assignment.title,
                storageURL: urlString,
                uploaderId: assignment.studentId ?? UUID()
            )
            previewData = data
            showFilePreview = true
        }
    }

    private static func fileNameFromURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        let name = url.lastPathComponent
        return name.removingPercentEncoding ?? name
    }

    private static func iconForExtension(_ ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo.fill"
        case "doc", "docx": return "doc.fill"
        case "txt", "md", "rtf": return "doc.text.fill"
        default: return "doc.badge.ellipsis"
        }
    }

    private static func colorForExtension(_ ext: String) -> Color {
        switch ext {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return .blue
        case "doc", "docx": return .indigo
        case "txt", "md", "rtf": return .purple
        default: return .gray
        }
    }

    // MARK: - Rubric Grading Section

    private var rubricGradingSection: some View {
        guard let rubric = attachedRubric else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(rubric.title, systemImage: "list.bullet.rectangle.portrait")
                        .font(.headline)
                    Spacer()
                    Text("\(rubricTotalSelected) / \(rubric.totalPoints) pts")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }

                ForEach(rubric.criteria) { criterion in
                    rubricCriterionRow(criterion: criterion)
                }

                // Apply rubric score button
                Button {
                    hapticTrigger.toggle()
                    scoreText = "\(rubricTotalSelected)"
                } label: {
                    Label("Apply Rubric Score", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        )
    }

    private func rubricCriterionRow(criterion: RubricCriterion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Criterion header
            HStack {
                Text(criterion.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                let selected = rubricSelections[criterion.id]
                Text(selected.map { "\($0) / \(criterion.maxPoints)" } ?? "-- / \(criterion.maxPoints)")
                    .font(.caption.bold())
                    .foregroundStyle(selected != nil ? .red : .secondary)
            }

            if !criterion.description.isEmpty {
                Text(criterion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Performance levels as selectable chips
            FlowLayout(spacing: 6) {
                ForEach(criterion.levels) { level in
                    rubricLevelChip(criterionId: criterion.id, level: level)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
    }

    private func rubricLevelChip(criterionId: UUID, level: RubricLevel) -> some View {
        let isSelected = rubricSelections[criterionId] == level.points

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                if isSelected {
                    rubricSelections.removeValue(forKey: criterionId)
                } else {
                    rubricSelections[criterionId] = level.points
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(level.label)
                    .font(.caption.bold())
                Text("\(level.points) pts")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? .red.opacity(0.2) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .red : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? .red : Color(.label))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Late Penalty Grading Section (Teacher)

    private var latePenaltyGradingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("Late Submission")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            // Late details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Days Late:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(assignment.daysLate)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("Penalty Type:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(assignment.latePenaltyType.displayName)
                        .font(.subheadline.bold())
                }

                if let badgeText = assignment.latePenaltyBadgeText {
                    HStack {
                        Text("Calculated Penalty:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(badgeText)
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                }

                if let summary = viewModel.latePenaltySummary(for: assignment) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                }
            }

            // Toggle to apply or skip late penalty
            Toggle(isOn: $applyLatePenalty) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply Late Penalty")
                        .font(.subheadline.bold())
                    Text("Automatically deduct points based on late policy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.orange)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Resubmission Info Section (Teacher)

    private var resubmissionInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                Text("Resubmission #\(assignment.resubmissionCount)")
                    .font(.headline)
                    .foregroundStyle(.indigo)
            }

            if !assignment.resubmissionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous Grades")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(assignment.resubmissionHistory) { entry in
                        HStack {
                            Text("Attempt \(assignment.resubmissionHistory.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 } ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let grade = entry.grade {
                                Text("\(Int(grade))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.gradeColor(grade))
                            } else {
                                Text("--")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let feedback = entry.feedback, !feedback.isEmpty {
                                Image(systemName: "text.bubble.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 6))
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("This is resubmission \(assignment.resubmissionCount) of \(assignment.maxResubmissions). The student's previous grades have been preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.indigo.opacity(0.3), lineWidth: 1)
        )
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
        .tint(.red)
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
                if applyLatePenalty && assignment.latePenaltyType != .none && assignment.daysLate > 0 {
                    // Use the late penalty grading flow
                    try await viewModel.gradeWithLatePenalty(
                        assignmentId: assignment.id,
                        studentId: assignment.studentId,
                        rawScore: score,
                        letterGrade: finalLetterGrade,
                        feedback: trimmedFeedback.isEmpty ? nil : trimmedFeedback,
                        applyLatePenalty: true
                    )
                } else {
                    // Standard grading without late penalty
                    try await viewModel.gradeSubmission(
                        assignmentId: assignment.id,
                        studentId: assignment.studentId,
                        score: score,
                        letterGrade: finalLetterGrade,
                        feedback: trimmedFeedback.isEmpty ? nil : trimmedFeedback
                    )
                }
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

// MARK: - FlowLayout (for rubric level chips)

/// A simple flow layout that wraps children into multiple lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}
