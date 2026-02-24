import SwiftUI

struct PlagiarismReportView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedAssignmentTitle: String?
    @State private var report: PlagiarismReport?
    @State private var isRunning = false
    @State private var expandedMatchId: UUID?
    @State private var hapticTrigger = false

    // MARK: - Computed

    /// Assignment titles in this course that have at least 2 text submissions.
    private var checkableAssignmentTitles: [String] {
        let courseAssignments = viewModel.assignments.filter {
            $0.courseId == course.id && $0.isSubmitted && $0.submission != nil
        }
        var titleCounts: [String: Int] = [:]
        for a in courseAssignments {
            // Only count submissions with actual text content
            if let text = Assignment.cleanSubmissionText(a.submission),
               !text.isEmpty,
               text.split(separator: " ").count >= 10 {
                titleCounts[a.title, default: 0] += 1
            }
        }
        return titleCounts
            .filter { $0.value >= 2 }
            .keys
            .sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    assignmentSelectionSection
                    if let title = selectedAssignmentTitle {
                        runCheckSection(title: title)
                    }
                    if let report {
                        reportSummarySection(report)
                        matchesList(report)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plagiarism Check")
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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Plagiarism Detection")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Compare text submissions for similarity using n-gram analysis")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plagiarism detection for \(course.title)")
    }

    // MARK: - Assignment Selection

    private var assignmentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Assignment", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if checkableAssignmentTitles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No assignments with 2+ text submissions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Plagiarism checks require at least 2 text submissions to compare.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(checkableAssignmentTitles, id: \.self) { title in
                    assignmentRow(title: title)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func assignmentRow(title: String) -> some View {
        let isSelected = selectedAssignmentTitle == title
        let submissionCount = viewModel.assignments.filter {
            $0.courseId == course.id && $0.title == title && $0.isSubmitted && $0.submission != nil
        }.count

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                selectedAssignmentTitle = title
                report = nil
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .indigo : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text("\(submissionCount) submission\(submissionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                isSelected
                    ? Color.indigo.opacity(0.08)
                    : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(title), \(submissionCount) submissions\(isSelected ? ", selected" : "")")
    }

    // MARK: - Run Check Section

    private func runCheckSection(title: String) -> some View {
        Button {
            hapticTrigger.toggle()
            runCheck(title: title)
        } label: {
            Group {
                if isRunning {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Analyzing Submissions...")
                            .fontWeight(.semibold)
                    }
                } else {
                    Label("Run Plagiarism Check", systemImage: "play.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(isRunning)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel("Run plagiarism check on \(title)")
    }

    // MARK: - Report Summary

    private func reportSummarySection(_ report: PlagiarismReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Results", systemImage: "chart.bar.doc.horizontal.fill")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(report.runDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                summaryCard(
                    label: "Checked",
                    value: "\(report.totalSubmissionsChecked)",
                    color: .blue
                )
                summaryCard(
                    label: "Flagged",
                    value: "\(report.flaggedCount)",
                    color: report.flaggedCount > 0 ? .red : .green
                )
            }

            if report.flaggedCount > 0 {
                HStack(spacing: 8) {
                    severityBadge(count: report.highSeverityCount, severity: .high)
                    severityBadge(count: report.mediumSeverityCount, severity: .medium)
                    severityBadge(count: report.lowSeverityCount, severity: .low)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("No significant similarities detected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plagiarism report summary: \(report.totalSubmissionsChecked) checked, \(report.flaggedCount) flagged")
    }

    private func summaryCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func severityBadge(count: Int, severity: PlagiarismSeverity) -> some View {
        let color = severityColor(severity)
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(severity.displayName)")
                .font(.caption2.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: Capsule())
        .accessibilityLabel("\(count) \(severity.displayName) severity matches")
    }

    // MARK: - Matches List

    private func matchesList(_ report: PlagiarismReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !report.matches.isEmpty {
                Text("Flagged Pairs")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 4)

                ForEach(report.matches) { match in
                    matchRow(match)
                }
            }
        }
    }

    private func matchRow(_ match: PlagiarismMatch) -> some View {
        let isExpanded = expandedMatchId == match.id
        let color = severityColor(match.severity)

        return VStack(spacing: 0) {
            // Main row
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    expandedMatchId = isExpanded ? nil : match.id
                }
            } label: {
                HStack(spacing: 12) {
                    // Severity indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 4, height: 44)

                    // Student names
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(color)
                            Text(match.studentNameA)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(color)
                            Text(match.studentNameB)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Similarity percentage
                    VStack(spacing: 2) {
                        Text("\(Int(match.similarityPercentage))%")
                            .font(.title3.bold())
                            .foregroundStyle(color)
                        Text("similar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            // Expanded content: matching excerpts
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                expandedExcerpts(match: match, color: color)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(match.studentNameA) and \(match.studentNameB), \(Int(match.similarityPercentage)) percent similar, \(match.severity.displayName) severity"
        )
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand matching excerpts")
    }

    private func expandedExcerpts(match: PlagiarismMatch, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if match.matchingExcerpts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Similarity detected via n-gram overlap. Individual matching passages are shorter than the display threshold.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(match.matchingExcerpts.enumerated()), id: \.offset) { index, excerpt in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Match \(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(color)

                        HStack(alignment: .top, spacing: 8) {
                            // Student A excerpt
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.studentNameA)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(excerpt.excerptA)
                                    .font(.caption)
                                    .foregroundStyle(Color(.label))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity)

                            // Student B excerpt
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.studentNameB)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(excerpt.excerptB)
                                    .font(.caption)
                                    .foregroundStyle(Color(.label))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if index < match.matchingExcerpts.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func severityColor(_ severity: PlagiarismSeverity) -> Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }

    private func runCheck(title: String) {
        isRunning = true
        expandedMatchId = nil

        // Run on next tick to allow the UI to update with the loading state
        Task {
            // Small delay for visual feedback
            try? await Task.sleep(for: .milliseconds(300))
            let result = viewModel.runPlagiarismCheck(assignmentTitle: title, courseId: course.id)
            withAnimation(.snappy) {
                report = result
                isRunning = false
            }
        }
    }
}
