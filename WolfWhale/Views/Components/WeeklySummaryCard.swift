import SwiftUI

struct WeeklySummaryCard: View {
    let summary: ProgressService.WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Text("This Week")
                    .font(.subheadline.bold())
                Spacer()
                trendBadge
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(
                    icon: "book.fill",
                    value: summary.lessonsCompleted,
                    label: "Lessons",
                    color: .green
                )

                Spacer()

                dividerLine

                Spacer()

                statItem(
                    icon: "doc.text.fill",
                    value: summary.assignmentsSubmitted,
                    label: "Submitted",
                    color: .cyan
                )

                Spacer()

                dividerLine

                Spacer()

                statItem(
                    icon: "questionmark.circle.fill",
                    value: summary.quizzesTaken,
                    label: "Quizzes",
                    color: .purple
                )

                Spacer()

                dividerLine

                Spacer()

                streakItem
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
    }

    // MARK: - Streak

    private var streakItem: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("\(summary.studyStreak)")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
            Text("Streak")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 32)
    }

    // MARK: - Trend Badge

    private var trendBadge: some View {
        HStack(spacing: 3) {
            switch summary.comparedToLastWeek {
            case .up(let n):
                Image(systemName: "arrow.up.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                Text("+\(n)")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            case .down(let n):
                Image(systemName: "arrow.down.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                Text("-\(n)")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            case .same:
                Image(systemName: "arrow.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text("Same")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(trendBackgroundColor.opacity(0.12), in: Capsule())
    }

    private var trendBackgroundColor: Color {
        switch summary.comparedToLastWeek {
        case .up: return .green
        case .down: return .red
        case .same: return .gray
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = ["This week summary"]
        parts.append("\(summary.lessonsCompleted) lessons completed")
        parts.append("\(summary.assignmentsSubmitted) assignments submitted")
        parts.append("\(summary.quizzesTaken) quizzes taken")
        parts.append("\(summary.studyStreak) day study streak")

        switch summary.comparedToLastWeek {
        case .up(let n):
            parts.append("Up \(n) from last week")
        case .down(let n):
            parts.append("Down \(n) from last week")
        case .same:
            parts.append("Same as last week")
        }

        return parts.joined(separator: ", ")
    }
}
