import SwiftUI

struct StudentInsightsView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel
    var filterAtRiskOnly: Bool = false

    @State private var sortOption: StudentInsightSortOption = .gradeAsc
    @State private var showAtRiskOnly: Bool
    @State private var selectedStudent: StudentInsight?
    @State private var hapticTrigger = false

    init(course: Course, viewModel: AppViewModel, filterAtRiskOnly: Bool = false) {
        self.course = course
        self.viewModel = viewModel
        self.filterAtRiskOnly = filterAtRiskOnly
        _showAtRiskOnly = State(initialValue: filterAtRiskOnly)
    }

    private var insights: [StudentInsight] {
        var results = viewModel.studentInsights(for: course.id)

        if showAtRiskOnly {
            results = results.filter { $0.isAtRisk }
        }

        switch sortOption {
        case .gradeAsc:
            results.sort { $0.currentGrade < $1.currentGrade }
        case .gradeDesc:
            results.sort { $0.currentGrade > $1.currentGrade }
        case .trendDeclining:
            results.sort {
                let order: [GradeTrend] = [.declining, .stable, .improving]
                let lIdx = order.firstIndex(of: $0.gradeTrend) ?? 1
                let rIdx = order.firstIndex(of: $1.gradeTrend) ?? 1
                return lIdx < rIdx
            }
        case .attendanceAsc:
            results.sort { $0.attendanceRate < $1.attendanceRate }
        case .name:
            results.sort { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
        }

        return results
    }

    private var atRiskCount: Int {
        viewModel.studentInsights(for: course.id).filter(\.isAtRisk).count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                courseOverviewHeader
                filterSortControls

                if insights.isEmpty {
                    emptyStateView
                } else {
                    ForEach(insights) { insight in
                        Button {
                            hapticTrigger.toggle()
                            selectedStudent = insight
                        } label: {
                            studentInsightCard(insight)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Student Insights")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStudent) { student in
            NavigationStack {
                StudentDetailInsightView(student: student, course: course)
            }
        }
    }

    // MARK: - Course Overview Header

    private var courseOverviewHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.courseColor(course.colorName).gradient)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: course.iconSystemName)
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text("\(course.enrolledStudentCount) students enrolled")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                if atRiskCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .compatBreathePeriodic(delay: 2)
                        Text("\(atRiskCount)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.red.gradient, in: Capsule())
                    .accessibilityLabel("\(atRiskCount) at-risk students")
                }
            }

            // Summary stats row
            let allInsights = viewModel.studentInsights(for: course.id)
            let avgGrade = allInsights.isEmpty ? 0 : allInsights.reduce(0) { $0 + $1.currentGrade } / Double(allInsights.count)
            let avgAttendance = allInsights.isEmpty ? 0 : allInsights.reduce(0) { $0 + $1.attendanceRate } / Double(allInsights.count)
            let decliningCount = allInsights.filter { $0.gradeTrend == .declining }.count

            HStack(spacing: 10) {
                miniStat(value: String(format: "%.0f%%", avgGrade), label: "Avg Grade", color: Theme.gradeColor(avgGrade))
                miniStat(value: String(format: "%.0f%%", avgAttendance * 100), label: "Attendance", color: avgAttendance >= 0.9 ? .green : (avgAttendance >= 0.8 ? .orange : .red))
                miniStat(value: "\(decliningCount)", label: "Declining", color: decliningCount > 0 ? .red : .green)
                miniStat(value: "\(atRiskCount)", label: "At Risk", color: atRiskCount > 0 ? .red : .green)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.courseColor(course.colorName).opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Filter / Sort Controls

    private var filterSortControls: some View {
        HStack(spacing: 12) {
            // At-risk filter toggle
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    showAtRiskOnly.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAtRiskOnly ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.caption)
                    Text("At Risk")
                        .font(.caption.bold())
                }
                .foregroundStyle(showAtRiskOnly ? .white : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(showAtRiskOnly ? Color.red : Color.red.opacity(0.12), in: Capsule())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel(showAtRiskOnly ? "Showing at-risk students only" : "Show all students")
            .accessibilityHint("Double tap to toggle at-risk filter")

            Spacer()

            // Sort picker
            Menu {
                ForEach(StudentInsightSortOption.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                    Text("Sort")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
            .accessibilityLabel("Sort students")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: showAtRiskOnly ? "checkmark.shield.fill" : "person.3.fill")
                .font(.largeTitle)
                .foregroundStyle(showAtRiskOnly ? .green : Color(.secondaryLabel))
                .symbolEffect(.bounce)

            Text(showAtRiskOnly ? "No At-Risk Students" : "No Student Data")
                .font(.headline)
                .foregroundStyle(Color(.label))

            Text(showAtRiskOnly ? "All students in this course are performing well." : "Student insights will appear once assignments are graded and attendance is recorded.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Student Insight Card

    private func studentInsightCard(_ insight: StudentInsight) -> some View {
        VStack(spacing: 12) {
            // Top row: avatar, name, grade, trend
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Theme.gradeColor(insight.currentGrade).gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(insight.studentName.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(insight.studentName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                            .lineLimit(1)

                        if insight.isAtRisk {
                            atRiskBadge(level: insight.riskLevel ?? .low)
                        }
                    }

                    HStack(spacing: 8) {
                        // Grade trend indicator
                        HStack(spacing: 3) {
                            Image(systemName: insight.gradeTrend.iconName)
                                .font(.caption2)
                            Text(insight.gradeTrend.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(trendColor(insight.gradeTrend))

                        Text("Active \(insight.lastActiveDate, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }

                Spacer()

                // Current grade
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", insight.currentGrade))
                        .font(.title3.bold())
                        .foregroundStyle(Theme.gradeColor(insight.currentGrade))
                    Text("Grade")
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            // Sparkline chart
            if insight.gradeHistory.count >= 2 {
                SparklineView(values: insight.gradeHistory, color: Theme.gradeColor(insight.currentGrade))
                    .frame(height: 32)
                    .accessibilityLabel("Grade trajectory: \(insight.gradeTrend.displayName)")
            }

            // Stats row
            HStack(spacing: 0) {
                insightStatPill(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", insight.attendanceRate * 100),
                    label: "Attendance",
                    color: insight.attendanceRate >= 0.9 ? .green : (insight.attendanceRate >= 0.8 ? .orange : .red)
                )
                insightStatPill(
                    icon: "doc.fill",
                    value: String(format: "%.0f%%", insight.submissionRate * 100),
                    label: "Submitted",
                    color: insight.submissionRate >= 0.9 ? .green : (insight.submissionRate >= 0.7 ? .orange : .red)
                )
            }

            // Risk factors
            if !insight.riskFactors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(insight.riskFactors, id: \.self) { factor in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text(factor)
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Chevron hint
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    insight.isAtRisk ? Color.red.opacity(0.3) : Color.clear,
                    lineWidth: insight.isAtRisk ? 1 : 0
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.studentName), grade \(Int(insight.currentGrade)) percent, trend \(insight.gradeTrend.displayName), attendance \(Int(insight.attendanceRate * 100)) percent\(insight.isAtRisk ? ", at risk" : "")")
        .accessibilityHint("Double tap to view detailed performance")
    }

    private func atRiskBadge(level: RiskLevel) -> some View {
        Text("At Risk")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskLevelColor(level).gradient, in: Capsule())
            .accessibilityLabel("At risk, \(level.rawValue) level")
    }

    private func insightStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(Color(.label))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Color Helpers

    private func trendColor(_ trend: GradeTrend) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .blue
        case .declining: .red
        }
    }

    private func riskLevelColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low: .orange
        case .medium: .red
        case .high: .red
        }
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minVal = (values.min() ?? 0) - 5
            let maxVal = (values.max() ?? 100) + 5
            let range = max(maxVal - minVal, 1)
            let stepX = geo.size.width / max(CGFloat(values.count - 1), 1)

            ZStack {
                // Gradient fill under the line
                Path { path in
                    guard values.count >= 2 else { return }
                    let firstY = geo.size.height * (1 - (values[0] - minVal) / range)
                    path.move(to: CGPoint(x: 0, y: firstY))
                    for i in 1..<values.count {
                        let x = stepX * CGFloat(i)
                        let y = geo.size.height * (1 - (values[i] - minVal) / range)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: stepX * CGFloat(values.count - 1), y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard values.count >= 2 else { return }
                    let firstY = geo.size.height * (1 - (values[0] - minVal) / range)
                    path.move(to: CGPoint(x: 0, y: firstY))
                    for i in 1..<values.count {
                        let x = stepX * CGFloat(i)
                        let y = geo.size.height * (1 - (values[i] - minVal) / range)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // End dot
                if let lastValue = values.last {
                    let x = stepX * CGFloat(values.count - 1)
                    let y = geo.size.height * (1 - (lastValue - minVal) / range)
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Student Detail Insight View (Sheet)

struct StudentDetailInsightView: View {
    let student: StudentInsight
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Student header
                studentHeader

                // Grade trajectory chart
                if student.gradeHistory.count >= 2 {
                    gradeTrajectorySection
                }

                // Detailed stats
                detailedStatsSection

                // Risk factors
                if !student.riskFactors.isEmpty {
                    riskFactorsSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Student Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    private var studentHeader: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Theme.gradeColor(student.currentGrade).gradient)
                .frame(width: 72, height: 72)
                .overlay {
                    Text(String(student.studentName.prefix(1)).uppercased())
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(student.studentName)
                        .font(.title3.bold())
                        .foregroundStyle(Color(.label))

                    if student.isAtRisk, let level = student.riskLevel {
                        Text("At Risk")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(level == .high ? Color.red : (level == .medium ? Color.red : Color.orange), in: Capsule())
                    }
                }

                Text(course.title)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // Large grade display
            VStack(spacing: 4) {
                Text(String(format: "%.1f%%", student.currentGrade))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gradeColor(student.currentGrade))

                HStack(spacing: 4) {
                    Image(systemName: student.gradeTrend.iconName)
                        .font(.caption)
                    Text(student.gradeTrend.displayName)
                        .font(.caption.bold())
                }
                .foregroundStyle(trendColor(student.gradeTrend))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(student.studentName), current grade \(Int(student.currentGrade)) percent, \(student.gradeTrend.displayName) trend")
    }

    private var gradeTrajectorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Trajectory")
                .font(.headline)
                .foregroundStyle(Color(.label))

            SparklineView(values: student.gradeHistory, color: Theme.gradeColor(student.currentGrade))
                .frame(height: 80)
                .accessibilityLabel("Grade chart showing \(student.gradeTrend.displayName) trajectory")

            // Grade history labels
            HStack {
                if let first = student.gradeHistory.first {
                    Text("Start: \(Int(first))%")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                if let last = student.gradeHistory.last {
                    Text("Current: \(Int(last))%")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.gradeColor(last))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Overview")
                .font(.headline)
                .foregroundStyle(Color(.label))

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                detailStatCard(
                    icon: "chart.bar.fill",
                    value: String(format: "%.0f%%", student.currentGrade),
                    label: "Current Grade",
                    color: Theme.gradeColor(student.currentGrade)
                )
                detailStatCard(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", student.attendanceRate * 100),
                    label: "Attendance",
                    color: student.attendanceRate >= 0.9 ? .green : (student.attendanceRate >= 0.8 ? .orange : .red)
                )
                detailStatCard(
                    icon: "doc.text.fill",
                    value: String(format: "%.0f%%", student.submissionRate * 100),
                    label: "Submissions",
                    color: student.submissionRate >= 0.9 ? .green : (student.submissionRate >= 0.7 ? .orange : .red)
                )
                detailStatCard(
                    icon: "clock.fill",
                    value: student.lastActiveDate.formatted(.dateTime.month(.abbreviated).day()),
                    label: "Last Active",
                    color: .blue
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var riskFactorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .compatVariableColorPeriodic(delay: 3)
                Text("Risk Factors")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
            }

            ForEach(student.riskFactors, id: \.self) { factor in
                HStack(spacing: 10) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text(factor)
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Risk factors: \(student.riskFactors.joined(separator: ", "))")
    }

    private func trendColor(_ trend: GradeTrend) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .blue
        case .declining: .red
        }
    }
}
