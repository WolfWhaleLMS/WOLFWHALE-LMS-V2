import SwiftUI

struct GradeCurveView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedCourseId: UUID?
    @State private var selectedAssignmentTitle: String?
    @State private var curveType: CurveType = .flat
    @State private var flatPoints: Double = 5
    @State private var percentageFactor: Double = 1.10
    @State private var bellTargetMean: Double = 80
    @State private var bellTargetStdDev: Double = 10
    @State private var showPreview = false
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var hapticTrigger = false
    @State private var showConfirmation = false
    @State private var curveError: String?

    // MARK: - Curve Types

    enum CurveType: String, CaseIterable, Identifiable {
        case flat = "Flat Curve"
        case percentage = "Percentage Boost"
        case bell = "Bell Curve"
        case squareRoot = "Square Root"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .flat: return "plus.circle.fill"
            case .percentage: return "percent"
            case .bell: return "chart.bar.fill"
            case .squareRoot: return "x.squareroot"
            }
        }

        var description: String {
            switch self {
            case .flat: return "Add a fixed number of points to all scores"
            case .percentage: return "Multiply all scores by a factor"
            case .bell: return "Scale to a target mean and standard deviation"
            case .squareRoot: return "Apply sqrt(score) * 10 transformation"
            }
        }
    }

    // MARK: - Computed Properties

    private var courseAssignmentTitles: [String] {
        guard let courseId = selectedCourseId else { return [] }
        let titles = Set(
            viewModel.assignments
                .filter { $0.courseId == courseId && $0.isSubmitted && $0.grade != nil }
                .map(\.title)
        )
        return titles.sorted()
    }

    private var currentStats: GradeStatistics {
        guard let courseId = selectedCourseId,
              let title = selectedAssignmentTitle else {
            return GradeStatistics(scores: [])
        }
        return viewModel.gradeStatisticsForAssignment(title: title, courseId: courseId)
    }

    private var previewStats: GradeStatistics {
        guard let courseId = selectedCourseId,
              let title = selectedAssignmentTitle else {
            return GradeStatistics(scores: [])
        }
        let matchingScores = viewModel.assignments
            .filter { $0.courseId == courseId && $0.title == title && $0.isSubmitted && $0.grade != nil }
            .compactMap(\.grade)

        let transformedScores = matchingScores.map { score -> Double in
            switch curveType {
            case .flat:
                return min(max(score + flatPoints, 0), 100)
            case .percentage:
                return min(max(score * percentageFactor, 0), 100)
            case .squareRoot:
                return min(sqrt(score) * 10.0, 100)
            case .bell:
                let mean = matchingScores.reduce(0, +) / Double(matchingScores.count)
                let variance = matchingScores.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(matchingScores.count)
                let stdDev = sqrt(variance)
                guard stdDev > 0 else { return score }
                let z = (score - mean) / stdDev
                return min(max(bellTargetMean + (z * bellTargetStdDev), 0), 100)
            }
        }

        return GradeStatistics(scores: transformedScores)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    courseSelectionSection
                    if selectedCourseId != nil {
                        assignmentSelectionSection
                    }
                    if selectedAssignmentTitle != nil && currentStats.count > 0 {
                        currentDistributionSection
                        curveTypeSection
                        curveParametersSection
                        if showPreview {
                            previewSection
                        }
                        previewToggleButton
                        applyCurveButton
                    } else if selectedAssignmentTitle != nil {
                        noGradesState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Grade Curve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
            .confirmationDialog(
                "Apply Curve?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Apply \(curveType.rawValue)", role: .destructive) {
                    hapticTrigger.toggle()
                    applyCurve()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently update \(currentStats.count) grade\(currentStats.count == 1 ? "" : "s"). This action cannot be undone.")
            }
            .alert("Grade Curve Failed", isPresented: Binding(
                get: { curveError != nil },
                set: { if !$0 { curveError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(curveError ?? "An unknown error occurred while applying the grade curve. No grades were saved.")
            }
        }
    }

    // MARK: - Course Selection

    private var courseSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Course", systemImage: "book.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if viewModel.courses.isEmpty {
                Text("No courses available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.courses) { course in
                            courseChip(course)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Course selection")
    }

    private func courseChip(_ course: Course) -> some View {
        let isSelected = selectedCourseId == course.id
        let color = Theme.courseColor(course.colorName)

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                selectedCourseId = course.id
                selectedAssignmentTitle = nil
                showPreview = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: course.iconSystemName)
                    .font(.caption)
                Text(course.title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(course.title)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Assignment Selection

    private var assignmentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Assignment", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if courseAssignmentTitles.isEmpty {
                Text("No graded assignments in this course")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(courseAssignmentTitles, id: \.self) { title in
                    assignmentRow(title: title)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Assignment selection")
    }

    private func assignmentRow(title: String) -> some View {
        let isSelected = selectedAssignmentTitle == title
        let count = viewModel.assignments.filter {
            $0.courseId == selectedCourseId && $0.title == title && $0.isSubmitted && $0.grade != nil
        }.count

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                selectedAssignmentTitle = title
                showPreview = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .pink : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text("\(count) graded submission\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                isSelected
                    ? Color.pink.opacity(0.08)
                    : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(title), \(count) graded submissions\(isSelected ? ", selected" : "")")
    }

    // MARK: - Current Distribution

    private var currentDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Distribution", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            histogramView(stats: currentStats, color: .blue)
            statisticsRow(stats: currentStats, label: "Current")
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Current grade distribution")
    }

    // MARK: - Histogram View

    private func histogramView(stats: GradeStatistics, color: Color) -> some View {
        let maxCount = stats.distribution.max() ?? 1
        let labels = ["0-9", "10-19", "20-29", "30-39", "40-49", "50-59", "60-69", "70-79", "80-89", "90-100"]

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    VStack(spacing: 2) {
                        if stats.distribution[index] > 0 {
                            Text("\(stats.distribution[index])")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.gradient)
                            .frame(
                                height: maxCount > 0
                                    ? max(CGFloat(stats.distribution[index]) / CGFloat(maxCount) * 100, stats.distribution[index] > 0 ? 8 : 2)
                                    : 2
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)

            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    Text(labels[index])
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grade distribution histogram with \(stats.count) scores")
    }

    // MARK: - Statistics Row

    private func statisticsRow(stats: GradeStatistics, label: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            statBadge(title: "Mean", value: String(format: "%.1f", stats.mean), color: .blue)
            statBadge(title: "Median", value: String(format: "%.1f", stats.median), color: .purple)
            statBadge(title: "Min", value: String(format: "%.1f", stats.min), color: .red)
            statBadge(title: "Max", value: String(format: "%.1f", stats.max), color: .green)
        }
    }

    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Curve Type Selection

    private var curveTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Curve Method", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(Color(.label))

            ForEach(CurveType.allCases) { type in
                curveTypeRow(type)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Curve method selection")
    }

    private func curveTypeRow(_ type: CurveType) -> some View {
        let isSelected = curveType == type
        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                curveType = type
                showPreview = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .pink)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? Color.pink : Color.pink.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.pink)
                }
            }
            .padding(12)
            .background(
                isSelected ? Color.pink.opacity(0.08) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(type.rawValue)\(isSelected ? ", selected" : "")")
        .accessibilityHint(type.description)
    }

    // MARK: - Curve Parameters

    private var curveParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Parameters", systemImage: "gearshape.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            switch curveType {
            case .flat:
                flatCurveParameters
            case .percentage:
                percentageParameters
            case .bell:
                bellCurveParameters
            case .squareRoot:
                squareRootInfo
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var flatCurveParameters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Points to add:")
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("+\(String(format: "%.0f", flatPoints)) pts")
                    .font(.subheadline.bold())
                    .foregroundStyle(.pink)
            }

            Slider(value: $flatPoints, in: 1...30, step: 1)
                .tint(.pink)
                .onChange(of: flatPoints) { _, _ in showPreview = false }
                .accessibilityLabel("Points to add: \(Int(flatPoints))")

            HStack {
                Text("1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("30")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var percentageParameters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Multiplier:")
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(String(format: "%.0f", (percentageFactor - 1.0) * 100))% boost")
                    .font(.subheadline.bold())
                    .foregroundStyle(.pink)
            }

            Slider(value: $percentageFactor, in: 1.01...1.50, step: 0.01)
                .tint(.pink)
                .onChange(of: percentageFactor) { _, _ in showPreview = false }
                .accessibilityLabel("Percentage boost: \(Int((percentageFactor - 1.0) * 100)) percent")

            HStack {
                Text("1%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("50%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bellCurveParameters: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target Mean:")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Text(String(format: "%.0f", bellTargetMean))
                        .font(.subheadline.bold())
                        .foregroundStyle(.pink)
                }
                Slider(value: $bellTargetMean, in: 60...95, step: 1)
                    .tint(.pink)
                    .onChange(of: bellTargetMean) { _, _ in showPreview = false }
                    .accessibilityLabel("Target mean: \(Int(bellTargetMean))")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target Std Dev:")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Text(String(format: "%.0f", bellTargetStdDev))
                        .font(.subheadline.bold())
                        .foregroundStyle(.pink)
                }
                Slider(value: $bellTargetStdDev, in: 3...20, step: 1)
                    .tint(.pink)
                    .onChange(of: bellTargetStdDev) { _, _ in showPreview = false }
                    .accessibilityLabel("Target standard deviation: \(Int(bellTargetStdDev))")
            }
        }
    }

    private var squareRootInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Formula: new = sqrt(original) x 10")
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Example transformations:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    exampleTransform(from: 49, to: 70)
                    exampleTransform(from: 64, to: 80)
                    exampleTransform(from: 81, to: 90)
                    exampleTransform(from: 100, to: 100)
                }
            }
        }
    }

    private func exampleTransform(from: Int, to: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(from)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundStyle(.pink)
            Text("\(to)%")
                .font(.caption2.bold())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preview (After Curve)", systemImage: "eye.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            histogramView(stats: previewStats, color: .green)
            statisticsRow(stats: previewStats, label: "After")

            // Before/After comparison
            comparisonRow
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var comparisonRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before vs After")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            HStack(spacing: 12) {
                comparisonCard(
                    label: "Mean",
                    before: currentStats.mean,
                    after: previewStats.mean
                )
                comparisonCard(
                    label: "Median",
                    before: currentStats.median,
                    after: previewStats.median
                )
                comparisonCard(
                    label: "Min",
                    before: currentStats.min,
                    after: previewStats.min
                )
                comparisonCard(
                    label: "Max",
                    before: currentStats.max,
                    after: previewStats.max
                )
            }
        }
    }

    private func comparisonCard(label: String, before: Double, after: Double) -> some View {
        let delta = after - before
        let deltaColor: Color = delta > 0 ? .green : (delta < 0 ? .red : .secondary)

        return VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", before))
                .font(.caption)
                .foregroundStyle(.secondary)
                .strikethrough()
            Text(String(format: "%.1f", after))
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Text(String(format: "%+.1f", delta))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(deltaColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(deltaColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.1f", before)) to \(String(format: "%.1f", after)), change \(String(format: "%+.1f", delta))")
    }

    // MARK: - Preview Toggle Button

    private var previewToggleButton: some View {
        Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                showPreview.toggle()
            }
        } label: {
            Label(
                showPreview ? "Hide Preview" : "Preview Changes",
                systemImage: showPreview ? "eye.slash.fill" : "eye.fill"
            )
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.indigo)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel(showPreview ? "Hide preview" : "Preview changes")
    }

    // MARK: - Apply Curve Button

    private var applyCurveButton: some View {
        Button {
            hapticTrigger.toggle()
            showConfirmation = true
        } label: {
            Group {
                if isApplying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Apply \(curveType.rawValue)", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .disabled(isApplying || currentStats.count == 0)
        .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel("Apply \(curveType.rawValue) to \(currentStats.count) grades")
    }

    // MARK: - No Grades State

    private var noGradesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Graded Submissions")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("This assignment has no graded submissions to curve.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Curve Applied")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("\(currentStats.count) grade\(currentStats.count == 1 ? "" : "s") updated with \(curveType.rawValue.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
            dismiss()
        }
    }

    // MARK: - Apply Curve Action

    private func applyCurve() {
        guard let courseId = selectedCourseId,
              let title = selectedAssignmentTitle else { return }

        isApplying = true

        Task {
            switch curveType {
            case .flat:
                await viewModel.applyFlatCurve(assignmentTitle: title, courseId: courseId, points: flatPoints)
            case .percentage:
                await viewModel.applyPercentageBoost(assignmentTitle: title, courseId: courseId, factor: percentageFactor)
            case .squareRoot:
                await viewModel.applySquareRootCurve(assignmentTitle: title, courseId: courseId)
            case .bell:
                await viewModel.applyBellCurve(
                    assignmentTitle: title,
                    courseId: courseId,
                    targetMean: bellTargetMean,
                    targetStdDev: bellTargetStdDev
                )
            }

            isApplying = false

            // Check if the curve application set a gradeError (indicates failure with rollback)
            if let error = viewModel.gradeError {
                curveError = error
            } else {
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { showSuccess = false }
                dismiss()
            }
        }
    }
}
