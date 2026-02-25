import SwiftUI

struct GradeBreakdownView: View {
    let courseId: UUID
    let courseName: String
    @Bindable var viewModel: AppViewModel

    @State private var gradeService = GradeCalculationService()
    @State private var targetGradeText = "90"
    @State private var hapticTrigger = false

    private var courseGrades: [GradeEntry] {
        viewModel.grades.filter { $0.courseId == courseId }
    }

    private var allAssignmentGrades: [AssignmentGrade] {
        courseGrades.flatMap(\.assignmentGrades).sorted { $0.date < $1.date }
    }

    private var weights: GradeWeights {
        gradeService.getWeights(for: courseId)
    }

    private var result: CourseGradeResult {
        gradeService.calculateCourseGrade(
            grades: courseGrades,
            weights: weights,
            courseId: courseId,
            courseName: courseName
        )
    }

    private var recentGrades: [AssignmentGrade] {
        Array(allAssignmentGrades.suffix(5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                overallGradeCard
                trendSection
                categoryBreakdownSection
                recentGradesSection
                whatDoINeedSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle("Grade Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overall Grade Card

    private var overallGradeCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(result.letterGrade)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeService.gradeColor(from: result.overallPercentage))
                Text(String(format: "%.1f%%", result.overallPercentage))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(courseName)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("GPA:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", result.gradePoints))
                        .font(.subheadline.bold())
                }

                HStack(spacing: 4) {
                    trendIcon(result.trend)
                    Text(trendLabel(result.trend))
                        .font(.caption)
                        .foregroundStyle(trendColor(result.trend))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Grade Trend")
                    .font(.headline)
                Spacer()
                trendIcon(result.trend)
                Text(trendLabel(result.trend))
                    .font(.caption)
                    .foregroundStyle(trendColor(result.trend))
            }

            if allAssignmentGrades.count >= 2 {
                GradeTrendView(
                    dataPoints: allAssignmentGrades.suffix(10).map { ag in
                        ag.maxScore > 0 ? (ag.score / ag.maxScore * 100) : 0
                    },
                    trend: result.trend
                )
                .frame(height: 60)
            } else {
                Text("Not enough data to show a trend yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Category Breakdown (Horizontal Bars)

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)

            ForEach(result.breakdowns, id: \.category) { breakdown in
                categoryBar(breakdown)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func categoryBar(_ breakdown: GradeBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: breakdown.category.iconName)
                    .font(.caption)
                    .foregroundStyle(colorForCategory(breakdown.category))
                    .frame(width: 16)
                Text(breakdown.category.displayName)
                    .font(.subheadline)
                Spacer()
                if breakdown.totalPoints > 0 {
                    Text("\(Int(breakdown.earnedPoints))/\(Int(breakdown.totalPoints))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", breakdown.percentage))
                        .font(.caption.bold())
                        .foregroundStyle(gradeService.gradeColor(from: breakdown.percentage))
                } else {
                    Text("No grades")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    if breakdown.totalPoints > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForCategory(breakdown.category).gradient)
                            .frame(
                                width: max(0, geometry.size.width * min(breakdown.percentage / 100.0, 1.0)),
                                height: 8
                            )
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text("Weight: \(String(format: "%.0f%%", breakdown.weight * 100))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if breakdown.totalPoints > 0 {
                    Text("Contribution: \(String(format: "%.1f%%", breakdown.weightedContribution))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Recent Grades

    private var recentGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Grades")
                    .font(.headline)
                Spacer()
                if recentGrades.count >= 2 {
                    GradeTrendView(
                        dataPoints: recentGrades.map { ag in
                            ag.maxScore > 0 ? (ag.score / ag.maxScore * 100) : 0
                        },
                        trend: result.trend
                    )
                    .frame(width: 60, height: 24)
                }
            }

            if recentGrades.isEmpty {
                Text("No graded items yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentGrades) { ag in
                    HStack(spacing: 10) {
                        Image(systemName: gradeService.categorize(ag.type).iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ag.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(ag.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        let pct = ag.maxScore > 0 ? (ag.score / ag.maxScore * 100) : 0
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(ag.score))/\(Int(ag.maxScore))")
                                .font(.subheadline.bold())
                                .foregroundStyle(gradeService.gradeColor(from: pct))
                            Text(String(format: "%.0f%%", pct))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - What Do I Need Calculator

    private var whatDoINeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What Do I Need?", systemImage: "target")
                .font(.headline)

            HStack(spacing: 12) {
                Text("To get")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("90", text: $targetGradeText)
                    .font(.subheadline.bold())
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemGray6), in: .rect(cornerRadius: 8))

                Text("% overall")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            let targetPct = Double(targetGradeText) ?? 90
            let currentEarned = allAssignmentGrades.reduce(0.0) { $0 + $1.score }
            let currentTotal = allAssignmentGrades.reduce(0.0) { $0 + $1.maxScore }
            // Estimate remaining work as roughly equal to what has been done so far
            let estimatedRemaining = max(currentTotal * 0.5, 100)

            if let needed = gradeService.percentageNeeded(
                currentEarned: currentEarned,
                currentTotal: currentTotal,
                remainingTotal: estimatedRemaining,
                targetPercentage: targetPct
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.indigo)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You need an average of **\(String(format: "%.1f%%", needed))** on remaining work")
                            .font(.subheadline)
                        Text("(\(gradeService.letterGrade(from: targetPct)) target)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.indigo.opacity(0.08), in: .rect(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .symbolEffect(.wiggle)
                    Text("A \(gradeService.letterGrade(from: targetPct)) (\(String(format: "%.0f%%", targetPct))) may not be achievable based on current grades.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08), in: .rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func colorForCategory(_ category: GradeCategory) -> Color {
        switch category {
        case .assignment: return .blue
        case .quiz: return .orange
        case .participation: return .green
        case .attendance: return .teal
        }
    }

    private func trendIcon(_ trend: GradeTrend) -> some View {
        Image(systemName: trend.iconName)
            .font(.caption.bold())
            .foregroundStyle(trendColor(trend))
    }

    private func trendLabel(_ trend: GradeTrend) -> String {
        switch trend {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }

    private func trendColor(_ trend: GradeTrend) -> Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .gray
        }
    }
}
