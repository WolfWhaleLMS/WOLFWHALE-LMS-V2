import SwiftUI

struct StandardsMasteryView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var expandedStandardId: UUID?
    @State private var hapticTrigger = false

    private var usedStandards: [LearningStandard] {
        viewModel.standardsUsedInCourse(course.id)
    }

    /// Standards grouped by subject for organized display.
    private var groupedBySubject: [(subject: String, standards: [LearningStandard])] {
        let grouped = Dictionary(grouping: usedStandards) { $0.subject }
        return grouped.map { (subject: $0.key, standards: $0.value.sorted { $0.code < $1.code }) }
            .sorted { $0.subject < $1.subject }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                overallSummary

                if usedStandards.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedBySubject, id: \.subject) { group in
                        subjectSection(group.subject, standards: group.standards)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Standards Mastery")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Text("Standards Alignment & Mastery")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(usedStandards.count) standard\(usedStandards.count == 1 ? "" : "s") tracked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Standards Mastery for \(course.title)")
    }

    // MARK: - Overall Summary

    private var overallSummary: some View {
        let masteryValues = usedStandards.compactMap { viewModel.standardMastery(standardId: $0.id, courseId: course.id) }
        let masteredCount = masteryValues.filter { $0 >= 80 }.count
        let approachingCount = masteryValues.filter { $0 >= 60 && $0 < 80 }.count
        let needsWorkCount = masteryValues.filter { $0 < 60 }.count
        let noDataCount = usedStandards.count - masteryValues.count

        return HStack(spacing: 10) {
            summaryCard(label: "Mastered", value: "\(masteredCount)", color: .green, icon: "checkmark.circle.fill")
            summaryCard(label: "Approaching", value: "\(approachingCount)", color: .yellow, icon: "arrow.up.circle.fill")
            summaryCard(label: "Needs Work", value: "\(needsWorkCount)", color: .red, icon: "exclamationmark.circle.fill")
            if noDataCount > 0 {
                summaryCard(label: "No Data", value: "\(noDataCount)", color: .gray, icon: "questionmark.circle.fill")
            }
        }
    }

    private func summaryCard(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Standards Tagged")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Tag learning standards to assignments to track student mastery across standards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Subject Section

    private func subjectSection(_ subject: String, standards: [LearningStandard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: subject == "Math" ? "function" : "text.book.closed.fill")
                    .foregroundStyle(.accentColor)
                Text(subject)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(standards.count) standard\(standards.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(standards) { standard in
                standardMasteryCard(standard)
            }
        }
    }

    // MARK: - Standard Mastery Card

    private func standardMasteryCard(_ standard: LearningStandard) -> some View {
        let mastery = viewModel.standardMastery(standardId: standard.id, courseId: course.id)
        let isExpanded = expandedStandardId == standard.id

        return VStack(spacing: 0) {
            // Main row
            Button {
                hapticTrigger.toggle()
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedStandardId = isExpanded ? nil : standard.id
                }
            } label: {
                HStack(spacing: 12) {
                    // Mastery indicator
                    masteryIndicator(mastery)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(standard.code)
                            .font(.caption.bold())
                            .foregroundStyle(.accentColor)
                        Text(standard.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    if let mastery {
                        Text("\(Int(mastery))%")
                            .font(.headline)
                            .foregroundStyle(masteryColor(mastery))
                    } else {
                        Text("--")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("\(standard.code): \(standard.title), mastery \(mastery.map { "\(Int($0))%" } ?? "no data")")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") student breakdown")

            // Expanded detail: per-student breakdown
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                studentBreakdown(standard)
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Mastery Indicator Circle

    private func masteryIndicator(_ mastery: Double?) -> some View {
        let color = mastery.map { masteryColor($0) } ?? Color.gray.opacity(0.3)
        let progress = mastery.map { $0 / 100 } ?? 0

        return ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: masteryIcon(mastery))
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
    }

    // MARK: - Student Breakdown

    private func studentBreakdown(_ standard: LearningStandard) -> some View {
        let students = viewModel.studentStandardMastery(standardId: standard.id, courseId: course.id)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Student Breakdown")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if students.isEmpty {
                Text("No graded submissions for this standard yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(students, id: \.studentName) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(entry.studentName)
                            .font(.caption)
                            .foregroundStyle(Color(.label))
                        Spacer()

                        // Mini progress bar
                        GeometryReader { geo in
                            let width = geo.size.width
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(masteryColor(entry.average))
                                    .frame(width: max(0, width * entry.average / 100), height: 6)
                            }
                        }
                        .frame(width: 60, height: 6)

                        Text("\(Int(entry.average))%")
                            .font(.caption.bold())
                            .foregroundStyle(masteryColor(entry.average))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.studentName): \(Int(entry.average))% mastery")
                }
            }
        }
    }

    // MARK: - Helpers

    private func masteryColor(_ percentage: Double) -> Color {
        switch percentage {
        case 80...: .green
        case 60..<80: .yellow
        default: .red
        }
    }

    private func masteryIcon(_ mastery: Double?) -> String {
        guard let mastery else { return "questionmark" }
        switch mastery {
        case 80...: return "checkmark"
        case 60..<80: return "arrow.up"
        default: return "exclamationmark"
        }
    }
}
