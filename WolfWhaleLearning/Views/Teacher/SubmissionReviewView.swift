import SwiftUI

/// A teacher-facing view for reviewing student submissions for a specific assignment.
/// Shows submission status for each student, file previews, and inline grading.
struct SubmissionReviewView: View {
    @Bindable var viewModel: AppViewModel
    let assignment: Assignment
    let course: Course

    @State private var fileService = FileManagerService()
    @State private var sortOption: SortOption = .name
    @State private var selectedSubmission: StudentSubmission?
    @State private var showPreviewSheet = false
    @State private var previewData: Data?
    @State private var isLoadingPreview = false
    @State private var hapticTrigger = false
    @State private var previewFileItem: FileItem?
    @State private var showFilePreviewSheet = false

    // MARK: - Sort Options

    nonisolated enum SortOption: String, CaseIterable, Sendable {
        case name = "Name"
        case date = "Date"
        case grade = "Grade"
    }

    // MARK: - Student Submission Model

    struct StudentSubmission: Identifiable {
        let id: UUID
        let studentId: UUID
        let studentName: String
        let submissionText: String?
        let submittedDate: Date?
        let isSubmitted: Bool
        let isLate: Bool
        let grade: Double?
        let feedback: String?
        let fileURLs: [String]
    }

    // MARK: - Derived Data

    private var submissions: [StudentSubmission] {
        // Build submissions from the teacher's view of assignments
        let matchingAssignments = viewModel.assignments.filter {
            $0.id == assignment.id && $0.courseId == course.id
        }

        var subs: [StudentSubmission] = []
        for a in matchingAssignments {
            guard let sid = a.studentId else { continue }
            let fileURLs = extractFileURLs(from: a.submission)
            let isLate: Bool = {
                if let text = a.submission, !text.isEmpty {
                    return a.dueDate < Date() && a.grade == nil
                }
                return false
            }()

            subs.append(StudentSubmission(
                id: sid,
                studentId: sid,
                studentName: a.studentName ?? "Unknown Student",
                submissionText: a.submission,
                submittedDate: a.isSubmitted ? a.dueDate : nil,
                isSubmitted: a.isSubmitted,
                isLate: isLate,
                grade: a.grade,
                feedback: a.feedback,
                fileURLs: fileURLs
            ))
        }

        // Also add a placeholder for the unsubmitted assignment
        if subs.isEmpty && !assignment.isSubmitted {
            // No submissions at all
        }

        return sortedSubmissions(subs)
    }

    private var submittedCount: Int {
        submissions.filter(\.isSubmitted).count
    }

    private var gradedCount: Int {
        submissions.filter { $0.grade != nil }.count
    }

    private var lateCount: Int {
        submissions.filter(\.isLate).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                statsRow
                sortPicker
                submissionsList
                downloadAllButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Review Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPreviewSheet) {
            if let sub = selectedSubmission {
                submissionDetailSheet(sub)
            }
        }
        .sheet(isPresented: $showFilePreviewSheet) {
            if let file = previewFileItem {
                FilePreviewSheet(file: file, fileData: previewData) {
                    showFilePreviewSheet = false
                    previewFileItem = nil
                    previewData = nil
                }
            }
        }
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.indigo.gradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(.headline)
                    Text(course.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                Label(
                    "Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))",
                    systemImage: "calendar"
                )
                Label("\(assignment.points) pts", systemImage: "star.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if assignment.dueDate < Date() {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(.red)
                    Text("Past due date")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(label: "Submitted", value: "\(submittedCount)", color: .green)
            statCard(label: "Graded", value: "\(gradedCount)", color: .blue)
            statCard(label: "Late", value: "\(lateCount)", color: .red)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Sort", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Submissions List

    private var submissionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Student Submissions")
                .font(.headline)
                .padding(.horizontal, 4)

            if submissions.isEmpty {
                emptySubmissionsState
            } else {
                ForEach(submissions) { sub in
                    submissionRow(sub)
                }
            }
        }
    }

    private var emptySubmissionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No submissions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("When students submit this assignment, their work will appear here for review.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Submission Row

    private func submissionRow(_ sub: StudentSubmission) -> some View {
        Button {
            hapticTrigger.toggle()
            if sub.isSubmitted {
                selectedSubmission = sub
                showPreviewSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: statusIcon(for: sub))
                    .font(.title3)
                    .foregroundStyle(statusColor(for: sub))

                // Student info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(sub.studentName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        if sub.isLate {
                            Text("LATE")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red, in: .capsule)
                        }
                    }

                    Text(statusText(for: sub))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Grade or action indicator
                if let grade = sub.grade {
                    Text("\(Int(grade))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gradeColor(grade))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.gradeColor(grade).opacity(0.12), in: .capsule)
                } else if sub.isSubmitted {
                    Text("Review")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.indigo.opacity(0.12), in: .capsule)
                } else {
                    Text("--")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Download All Button

    private var downloadAllButton: some View {
        Button {
            hapticTrigger.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download All Submissions")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(submittedCount == 0)
        .padding(.top, 4)
    }

    // MARK: - Submission Detail Sheet

    private func submissionDetailSheet(_ sub: StudentSubmission) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Student header
                    studentDetailHeader(sub)

                    // File preview area
                    if !sub.fileURLs.isEmpty {
                        filePreviewSection(sub)
                    }

                    // Submission text
                    if let text = sub.submissionText,
                       !text.isEmpty {
                        submissionTextSection(cleanSubmissionText(text))
                    }

                    // Grade entry
                    gradeNavigationSection(sub)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Submission Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showPreviewSheet = false
                        selectedSubmission = nil
                    }
                }
            }
        }
    }

    // MARK: - Detail Sub-views

    private func studentDetailHeader(_ sub: StudentSubmission) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sub.studentName)
                        .font(.title3.bold())

                    if let date = sub.submittedDate {
                        Text("Submitted: \(date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if sub.isLate {
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Late")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                    .padding(8)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 10))
                }
            }

            if let grade = sub.grade {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Graded: \(Int(grade))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gradeColor(grade))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.gradeColor(grade).opacity(0.1), in: .rect(cornerRadius: 10))
            }

            if let feedback = sub.feedback, !feedback.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Previous Feedback")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func filePreviewSection(_ sub: StudentSubmission) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Attached Files", systemImage: "paperclip")
                .font(.headline)

            ForEach(sub.fileURLs, id: \.self) { urlString in
                filePreviewRow(urlString: urlString)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func filePreviewRow(urlString: String) -> some View {
        let fileName = extractFileNameFromURL(urlString)
        let ext = (fileName as NSString).pathExtension.lowercased()
        let icon = iconForExtension(ext)
        let color = colorForExtension(ext)

        return Button {
            hapticTrigger.toggle()
            loadAndPreviewURL(urlString, fileName: fileName, ext: ext)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                    }

                Text(fileName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isLoadingPreview {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.indigo)
                }
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func submissionTextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Response Text", systemImage: "text.alignleft")
                .font(.headline)

            Text(text)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 12))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func gradeNavigationSection(_ sub: StudentSubmission) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Grading", systemImage: "pencil.and.list.clipboard")
                .font(.headline)

            // Find the matching assignment for this student to pass to GradeSubmissionView
            let matchingAssignment = viewModel.assignments.first {
                $0.id == assignment.id && $0.studentId == sub.studentId
            } ?? assignment

            NavigationLink {
                GradeSubmissionView(viewModel: viewModel, assignment: matchingAssignment)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: sub.grade != nil ? "pencil.circle.fill" : "plus.circle.fill")
                    Text(sub.grade != nil ? "Update Grade" : "Enter Grade")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(sub.grade != nil ? .orange : .indigo)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func sortedSubmissions(_ subs: [StudentSubmission]) -> [StudentSubmission] {
        switch sortOption {
        case .name:
            return subs.sorted {
                $0.studentName.localizedStandardCompare($1.studentName) == .orderedAscending
            }
        case .date:
            return subs.sorted {
                ($0.submittedDate ?? .distantPast) > ($1.submittedDate ?? .distantPast)
            }
        case .grade:
            return subs.sorted {
                ($0.grade ?? -1) > ($1.grade ?? -1)
            }
        }
    }

    private func statusIcon(for sub: StudentSubmission) -> String {
        if sub.grade != nil {
            return "checkmark.circle.fill"
        } else if sub.isSubmitted {
            return "doc.circle.fill"
        } else {
            return "circle.dashed"
        }
    }

    private func statusColor(for sub: StudentSubmission) -> Color {
        if sub.grade != nil {
            return .green
        } else if sub.isLate {
            return .red
        } else if sub.isSubmitted {
            return .orange
        } else {
            return .secondary
        }
    }

    private func statusText(for sub: StudentSubmission) -> String {
        if let grade = sub.grade {
            return "Graded - \(Int(grade))%"
        } else if sub.isLate {
            return "Submitted late"
        } else if sub.isSubmitted {
            if let date = sub.submittedDate {
                return "Submitted \(date.formatted(.dateTime.month(.abbreviated).day()))"
            }
            return "Submitted"
        } else {
            return "Not submitted"
        }
    }

    private func extractFileURLs(from text: String?) -> [String] {
        guard let text, text.contains("[Attachments]") else { return [] }
        let lines = text.components(separatedBy: "\n")
        guard let startIdx = lines.firstIndex(where: { $0.contains("[Attachments]") }) else { return [] }
        return lines[(startIdx + 1)...].compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return trimmed
            }
            return nil
        }
    }

    private func cleanSubmissionText(_ text: String) -> String {
        if let range = text.range(of: "\n\n[Attachments]") {
            return String(text[text.startIndex..<range.lowerBound])
        }
        if let range = text.range(of: "[Attachments]") {
            return String(text[text.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func extractFileNameFromURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        let name = url.lastPathComponent
        return name.removingPercentEncoding ?? name
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo.fill"
        case "doc", "docx": return "doc.fill"
        case "txt", "md": return "doc.text.fill"
        default: return "doc.badge.ellipsis"
        }
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return .blue
        case "doc", "docx": return .indigo
        case "txt", "md": return .purple
        default: return .gray
        }
    }

    private func loadAndPreviewURL(_ urlString: String, fileName: String, ext: String) {
        isLoadingPreview = true
        let nameNoExt = (fileName as NSString).deletingPathExtension
        let fileItem = FileItem(
            id: UUID(),
            fileName: nameNoExt.isEmpty ? "File" : nameNoExt,
            fileExtension: ext.isEmpty ? "bin" : ext,
            fileSize: 0,
            uploadDate: Date(),
            courseId: course.id,
            courseName: course.title,
            assignmentId: assignment.id,
            assignmentName: assignment.title,
            storageURL: urlString,
            uploaderId: UUID()
        )

        Task {
            let data = await fileService.downloadFile(url: urlString)
            isLoadingPreview = false

            // Dismiss the detail sheet first
            showPreviewSheet = false
            selectedSubmission = nil

            // Brief delay to let the current sheet dismiss before presenting the file preview
            try? await Task.sleep(for: .milliseconds(500))

            // Present file preview sheet
            previewFileItem = fileItem
            previewData = data
            showFilePreviewSheet = true
        }
    }
}
