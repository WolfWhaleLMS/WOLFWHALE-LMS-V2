import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TranscriptPreviewCard: View {
    @Bindable var viewModel: AppViewModel
    @State private var gradeService = GradeCalculationService()
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var hapticTrigger = false

    // MARK: - Computed Properties

    private var studentName: String {
        viewModel.currentUser?.fullName ?? "Student"
    }

    private var courseCount: Int {
        viewModel.grades.count
    }

    private var cumulativeGPA: Double {
        guard !viewModel.grades.isEmpty else { return 0 }
        let totalGradePoints = viewModel.grades.reduce(0.0) {
            $0 + gradeService.gradePoints(from: $1.numericGrade)
        }
        return totalGradePoints / Double(viewModel.grades.count)
    }

    private var totalCredits: Double {
        Double(viewModel.grades.count) * 1.0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            // Top row: icon + title
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Academic Transcript")
                        .font(.subheadline.bold())
                    Text(studentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    TranscriptExportView(viewModel: viewModel)
                } label: {
                    Text("View")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.12), in: Capsule())
                        .foregroundStyle(.indigo)
                }
            }

            Divider()

            // Stats row: GPA ring, course count, credits
            HStack(spacing: 16) {
                // Compact GPA ring
                gpaRing

                Spacer()

                statColumn(label: "Courses", value: "\(courseCount)")
                statColumn(label: "Credits", value: String(format: "%.1f", totalCredits))
                statColumn(label: "GPA", value: String(format: "%.2f", cumulativeGPA))
            }

            // Export button
            Button {
                hapticTrigger.toggle()
                exportTranscript()
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                    }
                    Text(isGenerating ? "Generating..." : "Export Transcript")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isGenerating || viewModel.grades.isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                TranscriptShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - GPA Ring

    private var gpaRing: some View {
        let progress = min(cumulativeGPA / 4.0, 1.0)
        let ringColor = gpaColor

        return ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.gradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(String(format: "%.1f", cumulativeGPA))
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("GPA \(String(format: "%.2f", cumulativeGPA))")
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

    // MARK: - Stat Column

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
    }

    // MARK: - Export Action

    private func exportTranscript() {
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
}

// MARK: - Share Sheet (private to avoid duplicate symbol with ReportCardView)

private struct TranscriptShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
