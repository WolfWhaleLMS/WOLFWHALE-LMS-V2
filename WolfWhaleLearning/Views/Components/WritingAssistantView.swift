import SwiftUI

/// A collapsible panel that displays writing statistics and grammar issues for a given text.
struct WritingAssistantView: View {
    @Binding var text: String
    let writingService: WritingToolsService

    @State private var issues: [GrammarIssue] = []
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            headerRow

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    statsBar
                    Divider()
                    writingToolsTip
                    if !issues.isEmpty {
                        Divider()
                        issuesSection
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        .onChange(of: text) {
            refresh()
        }
        .onAppear {
            refresh()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Text("Writing Assistant")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                if !issues.isEmpty {
                    Text("\(issues.count) issue\(issues.count == 1 ? "" : "s")")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(issueBadgeColor, in: .capsule)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(label: "Words", value: "\(writingService.wordCount)")
            Divider().frame(height: 28)
            statItem(label: "Characters", value: "\(writingService.characterCount)")
            Divider().frame(height: 28)
            statItem(label: "Read Time", value: writingService.readingTime)
            Divider().frame(height: 28)
            statItem(label: "Grade", value: readabilityGrade)
        }
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var readabilityGrade: String {
        let score = writingService.readabilityScore
        if score <= 0 { return "--" }
        if score <= 5 { return "Easy" }
        if score <= 8 { return "Medium" }
        if score <= 12 { return "Hard" }
        return "Expert"
    }

    // MARK: - Writing Tools Tip

    private var writingToolsTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
            Text("Tip: Select text and use Writing Tools for AI proofreading, rewriting, and summarization.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.08), in: .rect(cornerRadius: 8))
    }

    // MARK: - Issues Section

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Issues")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(issues) { issue in
                issueRow(issue)
            }
        }
    }

    private func issueRow(_ issue: GrammarIssue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(colorFor(issue.severity))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    // Problematic text
                    Text(snippetFor(issue))
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(issue.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(issue.suggestion)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                Spacer(minLength: 0)

                if canAutoFix(issue) {
                    Button {
                        applyFix(issue)
                    } label: {
                        Text("Fix")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.blue, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func refresh() {
        writingService.analyzeText(text)
        issues = writingService.checkGrammar(text)
    }

    private func colorFor(_ severity: GrammarIssue.Severity) -> Color {
        switch severity {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    private var issueBadgeColor: Color {
        if issues.contains(where: { $0.severity == .error }) { return .red }
        if issues.contains(where: { $0.severity == .warning }) { return .orange }
        return .blue
    }

    private func snippetFor(_ issue: GrammarIssue) -> String {
        guard issue.range.lowerBound >= text.startIndex,
              issue.range.upperBound <= text.endIndex else {
            return ""
        }
        let snippet = String(text[issue.range])
        if snippet.count > 60 {
            return String(snippet.prefix(57)) + "..."
        }
        return snippet
    }

    private func canAutoFix(_ issue: GrammarIssue) -> Bool {
        // Only auto-fix double spaces and capitalization for now
        issue.description.contains("Multiple spaces") ||
        issue.description.contains("capital letter")
    }

    private func applyFix(_ issue: GrammarIssue) {
        guard issue.range.lowerBound >= text.startIndex,
              issue.range.upperBound <= text.endIndex else { return }

        if issue.description.contains("Multiple spaces") {
            text = text.replacingCharacters(in: issue.range, with: " ")
        } else if issue.description.contains("capital letter") {
            let char = String(text[issue.range])
            text = text.replacingCharacters(in: issue.range, with: char.uppercased())
        }

        // Re-analyze after fix
        refresh()
    }
}
