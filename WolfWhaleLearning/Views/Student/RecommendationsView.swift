import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RecommendationsView: View {
    let viewModel: AppViewModel
    @State private var recommendationService = LearningRecommendationService()
    @State private var hapticTrigger = false
    @State private var selectedFilter: RecommendationFilter = .all
    @State private var showAnalyticsDetail = false
    @State private var animateCards = false

    private var filteredRecommendations: [LearningRecommendation] {
        switch selectedFilter {
        case .all:
            return recommendationService.recommendations
        case .urgent:
            return recommendationService.recommendations.filter { $0.priority == .urgent || $0.priority == .high }
        case .study:
            return recommendationService.recommendations.filter {
                $0.type == .lessonSuggestion || $0.type == .studyTimeOptimal || $0.type == .learningStyle
            }
        case .performance:
            return recommendationService.recommendations.filter {
                $0.type == .weakArea || $0.type == .performanceTrend
            }
        }
    }

    var body: some View {
        Group {
            if recommendationService.isLoading {
                loadingState
            } else if recommendationService.recommendations.isEmpty && recommendationService.analytics == nil {
                emptyState
            } else {
                recommendationsContent
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("AI Recommendations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticTrigger.toggle()
                    refreshRecommendations()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolRenderingMode(.hierarchical)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Refresh Recommendations")
                .accessibilityHint("Double tap to regenerate AI recommendations")
            }
        }
        .onAppear {
            if recommendationService.recommendations.isEmpty {
                refreshRecommendations()
            }
        }
    }

    // MARK: - Main Content

    private var recommendationsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analytics = recommendationService.analytics {
                    analyticsCard(analytics)
                    learningStyleIndicator(analytics)
                    subjectsVisualization(analytics)
                }

                filterPicker

                if filteredRecommendations.isEmpty {
                    noMatchingState
                } else {
                    recommendationsList
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable {
            refreshRecommendations()
        }
    }

    // MARK: - Analytics Summary Card

    private func analyticsCard(_ analytics: StudentAnalytics) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                Text("AI Analytics")
                    .font(.headline)
                Spacer()
                Text("On-Device")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.indigo.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 0) {
                analyticsStat(
                    icon: "chart.bar.fill",
                    value: String(format: "%.0f%%", analytics.averageGrade),
                    label: "Avg Grade",
                    color: gradeColor(analytics.averageGrade)
                )

                analyticsDivider

                analyticsStat(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", analytics.completionRate * 100),
                    label: "Completion",
                    color: .green
                )

                analyticsDivider

                analyticsStat(
                    icon: "flame.fill",
                    value: "\(analytics.studyStreakDays)",
                    label: "Streak",
                    color: .orange
                )

                analyticsDivider

                analyticsStat(
                    icon: "sparkles",
                    value: String(format: "%.0f%%", analytics.predictedPerformance),
                    label: "Predicted",
                    color: .purple
                )
            }

            // Progress indicators
            HStack(spacing: 12) {
                miniProgressItem(
                    label: "Lessons Done",
                    value: analytics.totalLessonsCompleted,
                    icon: "book.closed.fill",
                    color: .blue
                )
                miniProgressItem(
                    label: "Submitted",
                    value: analytics.totalAssignmentsSubmitted,
                    icon: "paperplane.fill",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI Analytics: Average grade \(String(format: "%.0f", analytics.averageGrade)) percent, completion rate \(String(format: "%.0f", analytics.completionRate * 100)) percent, \(analytics.studyStreakDays) day streak, predicted performance \(String(format: "%.0f", analytics.predictedPerformance)) percent")
    }

    private func analyticsStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var analyticsDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 44)
    }

    private func miniProgressItem(label: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.subheadline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 10))
    }

    // MARK: - Learning Style Indicator

    private func learningStyleIndicator(_ analytics: StudentAnalytics) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: analytics.preferredLearningStyle.iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Preferred Learning Style")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(analytics.preferredLearningStyle.rawValue)
                    .font(.headline.bold())
            }

            Spacer()

            // All style indicators
            HStack(spacing: 6) {
                ForEach([LessonType.reading, .video, .activity, .quiz], id: \.rawValue) { type in
                    Image(systemName: type.iconName)
                        .font(.caption)
                        .foregroundStyle(type == analytics.preferredLearningStyle ? Color.indigo : Color.gray.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(
                            type == analytics.preferredLearningStyle
                                ? AnyShapeStyle(.indigo.opacity(0.15))
                                : AnyShapeStyle(.clear),
                            in: Circle()
                        )
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preferred learning style: \(analytics.preferredLearningStyle.rawValue)")
    }

    // MARK: - Subjects Visualization

    private func subjectsVisualization(_ analytics: StudentAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !analytics.strongSubjects.isEmpty || !analytics.weakSubjects.isEmpty {
                HStack {
                    Image(systemName: "chart.dots.scatter")
                        .foregroundStyle(.indigo)
                    Text("Subject Analysis")
                        .font(.headline)
                    Spacer()
                }

                if !analytics.strongSubjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Strong Areas", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)

                        RecommendationsFlowLayout(spacing: 8) {
                            ForEach(analytics.strongSubjects, id: \.self) { subject in
                                subjectChip(subject, color: .green)
                            }
                        }
                    }
                }

                if !analytics.weakSubjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Needs Attention", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)

                        RecommendationsFlowLayout(spacing: 8) {
                            ForEach(analytics.weakSubjects, id: \.self) { subject in
                                subjectChip(subject, color: .orange)
                            }
                        }
                    }
                }

                // Grade distribution bars
                if !analytics.gradeDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade Distribution")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(analytics.gradeDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { course, grade in
                            HStack(spacing: 10) {
                                Text(course)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 80, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(.quaternary)
                                        Capsule()
                                            .fill(gradeColor(grade).gradient)
                                            .frame(width: geo.size.width * min(grade / 100, 1.0))
                                    }
                                }
                                .frame(height: 8)

                                Text(String(format: "%.0f%%", grade))
                                    .font(.caption.bold())
                                    .foregroundStyle(gradeColor(grade))
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func subjectChip(_ subject: String, color: Color) -> some View {
        Text(subject)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(RecommendationFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Recommendations List

    private var recommendationsList: some View {
        ForEach(Array(filteredRecommendations.enumerated()), id: \.element.id) { index, recommendation in
            recommendationCard(recommendation)
                .opacity(animateCards ? 1 : 0)
                .offset(y: animateCards ? 0 : 20)
                .animation(.spring(duration: 0.4, bounce: 0.2).delay(Double(index) * 0.05), value: animateCards)
        }
        .onAppear {
            withAnimation {
                animateCards = true
            }
        }
        .onChange(of: selectedFilter) {
            animateCards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    animateCards = true
                }
            }
        }
    }

    // MARK: - Recommendation Card

    private func recommendationCard(_ rec: LearningRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(priorityGradient(rec.priority))
                        .frame(width: 44, height: 44)
                    Image(systemName: rec.iconSystemName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                            .lineLimit(2)
                        Spacer()
                        priorityBadge(rec.priority)
                    }

                    Text(rec.type.rawValue.replacingOccurrences(
                        of: "([a-z])([A-Z])",
                        with: "$1 $2",
                        options: .regularExpression
                    ).capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(rec.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            HStack {
                Spacer()
                Button {
                    hapticTrigger.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(rec.actionLabel)
                            .font(.caption.bold())
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rec.priority.label) priority: \(rec.title). \(rec.description)")
        .accessibilityHint("Contains action: \(rec.actionLabel)")
    }

    private func priorityBadge(_ priority: RecommendationPriority) -> some View {
        Text(priority.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(priorityForegroundColor(priority))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(priorityBackgroundColor(priority), in: Capsule())
    }

    private func priorityGradient(_ priority: RecommendationPriority) -> LinearGradient {
        switch priority {
        case .urgent:
            LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .high:
            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .medium:
            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .low:
            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func priorityForegroundColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .urgent: .red
        case .high: .orange
        case .medium: .indigo
        case .low: .blue
        }
    }

    private func priorityBackgroundColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .urgent: .red.opacity(0.12)
        case .high: .orange.opacity(0.12)
        case .medium: .indigo.opacity(0.12)
        case .low: .blue.opacity(0.12)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing your learning patterns...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("All processing happens on-device")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading AI recommendations")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recommendations Yet", systemImage: "brain.head.profile.fill")
        } description: {
            Text("Complete some lessons and assignments to receive personalized AI-powered study recommendations.")
        } actions: {
            Button {
                hapticTrigger.toggle()
                refreshRecommendations()
            } label: {
                Text("Generate Recommendations")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    private var noMatchingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No \(selectedFilter.rawValue.lowercased()) recommendations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func refreshRecommendations() {
        animateCards = false
        recommendationService.generateRecommendations(
            courses: viewModel.courses,
            assignments: viewModel.assignments,
            quizzes: viewModel.quizzes,
            grades: viewModel.grades,
            streakDays: viewModel.currentUser?.streak ?? 0
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                animateCards = true
            }
        }
    }

    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 90...100: .green
        case 80..<90: .blue
        case 70..<80: .orange
        default: .red
        }
    }
}

// MARK: - Filter Enum

private enum RecommendationFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case urgent = "Priority"
    case study = "Study"
    case performance = "Grades"

    var id: String { rawValue }
}

// MARK: - Flow Layout

/// A simple horizontal wrapping layout for subject chips.
private struct RecommendationsFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + rowHeight
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecommendationsView(viewModel: {
            let vm = AppViewModel()
            vm.loginAsDemo(role: .student)
            return vm
        }())
    }
}
