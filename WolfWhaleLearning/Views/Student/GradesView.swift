import SwiftUI

struct GradesView: View {
    @Bindable var viewModel: AppViewModel

    @State private var gradeService = GradeCalculationService()

    /// Weighted grade results for each course, sourced from the view model.
    private var courseResults: [CourseGradeResult] {
        viewModel.courseGradeResults
    }

    /// Weighted GPA from the view model (uses GradeCalculationService under the hood).
    private var gpa: Double {
        viewModel.gpa
    }

    /// Weighted average percentage across all courses.
    private var averagePercent: Double {
        viewModel.weightedAveragePercent
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading grades")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        gpaCard
                        gradesList
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .overlay {
                    if viewModel.grades.isEmpty {
                        ContentUnavailableView("No Grades Yet", systemImage: "chart.bar", description: Text("Grades will appear here once assignments are graded"))
                    }
                }
                .refreshable {
                    await viewModel.refreshGrades()
                }
            }
        }
        .navigationTitle("Grades")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReportCardView(viewModel: viewModel)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Report Card")
                .accessibilityHint("Double tap to view your report card")
            }
        }
    }

    // MARK: - GPA Card (Weighted)

    private var gpaCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(gpa / 4.0, 1.0))
                    .stroke(Theme.gradeColor(averagePercent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", gpa))
                        .font(.title2.bold())
                    Text("GPA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text("Overall Performance")
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(viewModel.overallLetterGrade)
                        .font(.subheadline.bold())
                        .foregroundStyle(gradeService.gradeColor(from: averagePercent))
                    Text("Weighted")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text("\(viewModel.courseGradeResults.count) courses this semester")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%% weighted average", averagePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall Performance: GPA \(String(format: "%.2f", gpa)), \(String(format: "%.1f", averagePercent)) percent weighted average, \(viewModel.courseGradeResults.count) courses this semester")
    }

    // MARK: - Grades List (with Navigation to Breakdown)

    @ViewBuilder
    private var gradesList: some View {
        ForEach(viewModel.grades) { grade in
            let weightedResult = courseResults.first(where: { $0.courseId == grade.courseId })

            NavigationLink {
                GradeBreakdownView(
                    courseId: grade.courseId,
                    courseName: grade.courseName,
                    viewModel: viewModel
                )
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.courseColor(grade.courseColor).gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: grade.courseIcon)
                                    .foregroundStyle(.white)
                                    .symbolRenderingMode(.hierarchical)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(grade.courseName)
                                .font(.headline)
                                .foregroundStyle(Color(.label))
                            HStack(spacing: 4) {
                                Text("\(grade.assignmentGrades.count) graded items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let result = weightedResult {
                                    Text("  \(trendIcon(result.trend))")
                                        .font(.caption2)
                                        .foregroundStyle(trendColor(result.trend))
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let result = weightedResult {
                                Text(result.letterGrade)
                                    .font(.title3.bold())
                                    .foregroundStyle(gradeService.gradeColor(from: result.overallPercentage))
                                Text(String(format: "%.1f%%", result.overallPercentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(grade.letterGrade)
                                    .font(.title3.bold())
                                    .foregroundStyle(Theme.gradeColor(grade.numericGrade))
                                Text(String(format: "%.1f%%", grade.numericGrade))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)

                    // Compact weight summary bar
                    if let result = weightedResult {
                        weightSummaryBar(result)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }

                    Divider().padding(.leading, 72)

                    ForEach(grade.assignmentGrades) { ag in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ag.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.label))
                                Text(ag.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(ag.score))/\(Int(ag.maxScore))")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.gradeColor(ag.score / ag.maxScore * 100))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(grade.courseName): Grade \(weightedResult?.letterGrade ?? grade.letterGrade), \(String(format: "%.1f", weightedResult?.overallPercentage ?? grade.numericGrade)) percent weighted, \(grade.assignmentGrades.count) graded items. Tap for breakdown.")
            .onAppear {
                if grade.id == viewModel.grades.last?.id {
                    Task { await viewModel.loadMoreAssignments() }
                }
            }
        }
        if viewModel.assignmentPagination.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    // MARK: - Compact Weight Summary Bar

    private func weightSummaryBar(_ result: CourseGradeResult) -> some View {
        let activeBreakdowns = result.breakdowns.filter { $0.totalPoints > 0 }
        return VStack(spacing: 4) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(activeBreakdowns, id: \.category) { breakdown in
                        let proportion = breakdown.weight / max(activeBreakdowns.reduce(0) { $0 + $1.weight }, 0.01)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForCategory(breakdown.category).gradient)
                            .frame(width: max(0, geometry.size.width * proportion - 2), height: 6)
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                ForEach(activeBreakdowns, id: \.category) { breakdown in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(colorForCategory(breakdown.category))
                            .frame(width: 6, height: 6)
                        Text("\(breakdown.category.displayName): \(String(format: "%.0f%%", breakdown.percentage))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
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

    private func trendIcon(_ trend: GradeTrend) -> String {
        switch trend {
        case .improving: return "^"
        case .declining: return "v"
        case .stable: return "-"
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
