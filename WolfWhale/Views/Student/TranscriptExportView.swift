import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct TranscriptExportView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isGenerating = false
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var showEmailCopied = false
    @State private var hapticTrigger = false
    @State private var gradeService = GradeCalculationService()

    // MARK: - Computed Properties

    private var studentName: String {
        viewModel.currentUser?.fullName ?? "Student"
    }

    private var studentId: String {
        String(viewModel.currentUser?.id.uuidString.prefix(8).uppercased() ?? "N/A")
    }

    private var schoolYear: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        return month >= 8 ? "\(year)-\(year + 1)" : "\(year - 1)-\(year)"
    }

    private var courseRows: [TranscriptPDFGenerator.CourseGradeRow] {
        viewModel.grades.map { entry in
            let matchingCourse = viewModel.courses.first { $0.id == entry.courseId }
            let teacherName = matchingCourse?.teacherName ?? "N/A"
            let gradePoints = gradeService.gradePoints(from: entry.numericGrade)
            let letterGrade = gradeService.letterGrade(from: entry.numericGrade)

            return TranscriptPDFGenerator.CourseGradeRow(
                courseName: entry.courseName,
                teacherName: teacherName,
                grade: entry.numericGrade,
                letterGrade: letterGrade,
                credits: 1.0,
                gradePoints: gradePoints
            )
        }
    }

    private var cumulativeGPA: Double {
        guard !courseRows.isEmpty else { return 0 }
        let total = courseRows.reduce(0.0) { $0 + $1.gradePoints }
        return total / Double(courseRows.count)
    }

    private var totalCredits: Double {
        courseRows.reduce(0.0) { $0 + $1.credits }
    }

    private var attendanceRate: Double {
        let total = viewModel.attendance.count
        guard total > 0 else { return 100 }
        let presentOrExcused = viewModel.attendance.filter {
            $0.status == .present || $0.status == .excused
        }.count
        return Double(presentOrExcused) / Double(total) * 100
    }

    private var gpaColor: Color {
        switch cumulativeGPA {
        case 3.5...: return .green
        case 3.0..<3.5: return .blue
        case 2.5..<3.0: return .yellow
        case 2.0..<2.5: return .orange
        default: return .red
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                studentInfoSection
                courseGradesTable
                summarySection
                actionButtons
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Transcript Export")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showEmailCopied {
                emailCopiedToast
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheetWrapper(activityItems: [url])
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)
                .compatBreatheEffect()

            Text("Academic Transcript")
                .font(.title2.bold())

            Text("Preview and export your official transcript")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Student Info

    private var studentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Student Information", systemImage: "person.text.rectangle")
                .font(.headline)

            VStack(spacing: 8) {
                infoRow(label: "Name", value: studentName)
                infoRow(label: "Student ID", value: studentId)
                infoRow(label: "School Year", value: schoolYear)
                infoRow(label: "Date", value: Date().formatted(date: .long, time: .omitted))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Course Grades Table

    private var courseGradesTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Grades", systemImage: "tablecells")
                .font(.headline)

            VStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text("Course")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Teacher")
                        .frame(width: 80, alignment: .leading)
                    Text("Grade")
                        .frame(width: 50)
                    Text("GPA")
                        .frame(width: 45)
                }
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.indigo.opacity(0.1))

                if viewModel.grades.isEmpty {
                    Text("No grades available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(courseRows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.courseName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(row.letterGrade)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Theme.gradeColor(row.grade))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(row.teacherName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 80, alignment: .leading)

                            Text(String(format: "%.1f%%", row.grade))
                                .font(.caption.bold())
                                .frame(width: 50)

                            Text(String(format: "%.1f", row.gradePoints))
                                .font(.caption)
                                .frame(width: 45)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            index % 2 == 0
                                ? Color.clear
                                : Color(UIColor.systemGray6).opacity(0.5)
                        )
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 16) {
            Label("Academic Summary", systemImage: "chart.bar.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                // GPA Ring
                GPADisplayView(gpa: cumulativeGPA, size: 90)

                VStack(alignment: .leading, spacing: 8) {
                    summaryRow(label: "Cumulative GPA", value: String(format: "%.2f / 4.00", cumulativeGPA))
                    summaryRow(label: "Total Credits", value: String(format: "%.1f", totalCredits))
                    summaryRow(label: "Courses", value: "\(courseRows.count)")
                    summaryRow(label: "Attendance Rate", value: String(format: "%.1f%%", attendanceRate))
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Export PDF
            Button {
                hapticTrigger.toggle()
                generateAndShare()
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isGenerating ? "Generating PDF..." : "Export PDF")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isGenerating || viewModel.grades.isEmpty)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            // Email to Parent
            Button {
                copyTranscriptLinkForParent()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                    Text("Email to Parent")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isGenerating || viewModel.grades.isEmpty)
        }
        .padding(.top, 4)
    }

    // MARK: - Email Copied Toast

    private var emailCopiedToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce)
                Text("Transcript info copied to clipboard")
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.4), value: showEmailCopied)
    }

    // MARK: - Actions

    private func generateAndShare() {
        isGenerating = true

        let transcriptData = TranscriptPDFGenerator.buildTranscriptData(
            from: viewModel.grades,
            courses: viewModel.courses,
            attendance: viewModel.attendance,
            user: viewModel.currentUser,
            gradeService: gradeService
        )

        let generator = TranscriptPDFGenerator()
        if let url = generator.generateTranscriptFile(from: transcriptData) {
            pdfURL = url
            isGenerating = false
            showShareSheet = true
        } else {
            isGenerating = false
        }
    }

    private func copyTranscriptLinkForParent() {
        #if canImport(UIKit)
        var summary = "Academic Transcript - \(studentName)\n"
        summary += "School Year: \(schoolYear)\n"
        summary += "Cumulative GPA: \(String(format: "%.2f", cumulativeGPA)) / 4.00\n"
        summary += "Total Credits: \(String(format: "%.1f", totalCredits))\n"
        summary += "Attendance Rate: \(String(format: "%.1f%%", attendanceRate))\n\n"
        summary += "Courses:\n"
        for row in courseRows {
            summary += "  \(row.courseName): \(row.letterGrade) (\(String(format: "%.1f%%", row.grade)))\n"
        }
        summary += "\nGenerated by WolfWhale LMS on \(Date().formatted(date: .long, time: .omitted))"

        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: summary as NSString]],
            options: [.expirationDate: Date().addingTimeInterval(120), .localOnly: true]
        )
        #endif

        withAnimation {
            showEmailCopied = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                showEmailCopied = false
            }
        }
    }
}

// MARK: - Share Sheet Wrapper

/// UIActivityViewController wrapper for sharing files.
/// Uses a distinct name to avoid collisions with the one declared in ReportCardView.
private struct ShareSheetWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
