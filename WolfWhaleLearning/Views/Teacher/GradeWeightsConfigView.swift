import SwiftUI

struct GradeWeightsConfigView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var gradeService = GradeCalculationService()
    @State private var weights: GradeWeights = .default
    @State private var hapticTrigger = false
    @State private var isSaved = false

    /// Preview of the class average with the current weights.
    private var previewResult: CourseGradeResult {
        let courseGrades = viewModel.grades.filter { $0.courseId == course.id }
        return gradeService.calculateCourseGrade(
            grades: courseGrades,
            weights: weights,
            courseId: course.id,
            courseName: course.title
        )
    }

    private var totalWeight: Double {
        weights.assignments + weights.quizzes + weights.participation + weights.attendance
    }

    private var isValid: Bool {
        weights.isValid
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                pieChartSection
                weightSlidersSection
                validationSection
                previewSection
                actionButtons
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle("Grade Weights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            weights = gradeService.getWeights(for: course.id)
        }
    }

    // MARK: - Pie Chart

    private var pieChartSection: some View {
        VStack(spacing: 12) {
            Text("Weight Distribution")
                .font(.headline)

            ZStack {
                pieChart
                    .frame(width: 180, height: 180)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", totalWeight * 100))
                        .font(.title2.bold())
                        .foregroundStyle(isValid ? Color.primary : Color.red)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            pieLegend
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var pieChart: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            let slices: [(Double, Color)] = [
                (weights.assignments, .blue),
                (weights.quizzes, .orange),
                (weights.participation, .green),
                (weights.attendance, .teal)
            ]

            var startAngle = Angle.degrees(-90)

            for (value, color) in slices where value > 0 {
                let endAngle = startAngle + Angle.degrees(value * 360)
                let path = Path { p in
                    p.move(to: center)
                    p.addArc(
                        center: center,
                        radius: radius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false
                    )
                    p.closeSubpath()
                }
                context.fill(path, with: .color(color))

                // Thin separator line between slices
                let separatorPath = Path { p in
                    p.move(to: center)
                    let x = center.x + radius * cos(CGFloat(endAngle.radians))
                    let y = center.y + radius * sin(CGFloat(endAngle.radians))
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(separatorPath, with: .color(.white), lineWidth: 2)

                startAngle = endAngle
            }
        }
    }

    private var pieLegend: some View {
        let items: [(String, Color, Double)] = [
            ("Assignments", .blue, weights.assignments),
            ("Quizzes", .orange, weights.quizzes),
            ("Participation", .green, weights.participation),
            ("Attendance", .teal, weights.attendance)
        ]

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(items, id: \.0) { label, color, value in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", value * 100))
                        .font(.caption.bold())
                }
            }
        }
    }

    // MARK: - Weight Sliders

    private var weightSlidersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Weights")
                .font(.headline)

            weightSlider(
                category: .assignment,
                value: $weights.assignments,
                color: .blue
            )
            weightSlider(
                category: .quiz,
                value: $weights.quizzes,
                color: .orange
            )
            weightSlider(
                category: .participation,
                value: $weights.participation,
                color: .green
            )
            weightSlider(
                category: .attendance,
                value: $weights.attendance,
                color: .teal
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func weightSlider(
        category: GradeCategory,
        value: Binding<Double>,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(category.displayName)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .frame(width: 44, alignment: .trailing)
            }

            Slider(value: value, in: 0...1, step: 0.05)
                .tint(color)
        }
    }

    // MARK: - Validation

    @ViewBuilder
    private var validationSection: some View {
        if !isValid {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                let diff = totalWeight - 1.0
                if diff > 0 {
                    Text("Weights exceed 100% by \(String(format: "%.0f%%", diff * 100)). Adjust to save.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Weights are \(String(format: "%.0f%%", abs(diff) * 100)) below 100%. Adjust to save.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview with Current Weights")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(previewResult.letterGrade)
                        .font(.largeTitle.bold())
                        .foregroundStyle(gradeService.gradeColor(from: previewResult.overallPercentage))
                    Text(String(format: "%.1f%%", previewResult.overallPercentage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Student Average")
                        .font(.subheadline.bold())
                    Text("Based on \(viewModel.grades.filter { $0.courseId == course.id }.flatMap(\.assignmentGrades).count) graded items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("GPA: \(String(format: "%.2f", previewResult.gradePoints))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                hapticTrigger.toggle()
                guard isValid else { return }
                gradeService.setWeights(weights, for: course.id)
                // Notify the view model so weighted GPA recalculates immediately
                viewModel.invalidateGradeCalculations()
                isSaved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isSaved = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    Text(isSaved ? "Saved" : "Save Weights")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isSaved ? .green : .indigo)
            .disabled(!isValid)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            Button {
                hapticTrigger.toggle()
                withAnimation(.smooth) {
                    weights = .default
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }
}
