import SwiftUI

struct ProgressGoalsView: View {
    let viewModel: AppViewModel
    @State private var selectedCourseForGoal: Course?
    @State private var hapticTrigger = false

    private var coursesWithGrades: [(course: Course, grade: GradeEntry)] {
        viewModel.courses.compactMap { course in
            guard let grade = viewModel.grades.first(where: { $0.courseId == course.id }) else { return nil }
            return (course: course, grade: grade)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                headerCard

                if coursesWithGrades.isEmpty {
                    emptyState
                } else {
                    ForEach(coursesWithGrades, id: \.course.id) { item in
                        courseGoalCard(course: item.course, grade: item.grade)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress Goals")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCourseForGoal) { course in
            SetGoalSheet(
                viewModel: viewModel,
                course: course,
                currentGrade: viewModel.grades.first(where: { $0.courseId == course.id })?.numericGrade ?? 0
            )
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "target")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Grade Goals")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text("Set targets and track what you need to achieve them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Summary stats
            let goalsSet = viewModel.progressGoals.count
            let onTrackCount = coursesWithGrades.filter {
                let s = isOnTrack(courseId: $0.course.id, currentGrade: $0.grade.numericGrade)
                return s == .onTrack || s == .achieved
            }.count

            HStack(spacing: 16) {
                summaryPill(value: "\(goalsSet)", label: "Goals Set", color: .indigo)
                summaryPill(value: "\(onTrackCount)", label: "On Track", color: .green)
                summaryPill(value: "\(coursesWithGrades.count)", label: "Courses", color: .blue)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress Goals: \(viewModel.progressGoals.count) goals set across \(coursesWithGrades.count) courses")
    }

    private func summaryPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: 1)
            Text("No Graded Courses")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Once you have grades in your courses, you can set target goals here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Course Goal Card

    private func courseGoalCard(course: Course, grade: GradeEntry) -> some View {
        let courseColor = Theme.courseColor(course.colorName)
        let goal = viewModel.progressGoal(for: course.id)
        let status = isOnTrack(courseId: course.id, currentGrade: grade.numericGrade)
        let remaining = viewModel.remainingAssignmentCount(for: course.id)

        return VStack(spacing: 14) {
            // Course header
            HStack(spacing: 12) {
                Image(systemName: course.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(courseColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(course.teacherName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if goal != nil {
                    statusBadge(status)
                }
            }

            // Grade progress
            if let goal {
                gradeProgressSection(
                    currentGrade: grade.numericGrade,
                    targetGrade: goal.targetGrade,
                    targetLetter: goal.targetLetterGrade,
                    courseColor: courseColor
                )

                // Required score info
                if let requiredAvg = viewModel.requiredAverageScore(courseId: course.id, targetGrade: goal.targetGrade) {
                    requiredScoreSection(
                        requiredAverage: requiredAvg,
                        remainingCount: remaining,
                        status: status
                    )
                }

                // Motivational message
                motivationalMessage(status: status, targetLetter: goal.targetLetterGrade, courseName: course.title)

                // Actions
                HStack {
                    Button {
                        hapticTrigger.toggle()
                        selectedCourseForGoal = course
                    } label: {
                        Label("Edit Goal", systemImage: "pencil")
                            .font(.caption.bold())
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    Spacer()

                    Button(role: .destructive) {
                        hapticTrigger.toggle()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.removeProgressGoal(courseId: course.id)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption.bold())
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                .padding(.top, 4)
            } else {
                // No goal set
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Grade: \(grade.letterGrade) (\(Int(grade.numericGrade))%)")
                            .font(.subheadline)
                            .foregroundStyle(Color(.label))
                        Text("\(remaining) assignment\(remaining == 1 ? "" : "s") remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        hapticTrigger.toggle()
                        selectedCourseForGoal = course
                    } label: {
                        Text("Set Goal")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(courseColor, in: Capsule())
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Set goal for \(course.title)")
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    goal != nil ? statusColor(status).opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.title), current grade \(Int(grade.numericGrade)) percent\(goal.map { ", target \($0.targetLetterGrade), \(status.rawValue)" } ?? ", no goal set")")
    }

    // MARK: - Grade Progress Section

    private func gradeProgressSection(currentGrade: Double, targetGrade: Double, targetLetter: String, courseColor: Color) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(currentGrade))%")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.gradeColor(currentGrade))
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(courseColor.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(currentGrade / targetGrade, 1.0))
                        .stroke(
                            LinearGradient(
                                colors: [courseColor, courseColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(min(currentGrade / targetGrade * 100, 999)))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(courseColor)
                        Text("of goal")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(targetLetter)
                        .font(.title2.bold())
                        .foregroundStyle(courseColor)
                    Text("(\(Int(targetGrade))%)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(courseColor.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [courseColor, courseColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: min(CGFloat(currentGrade / targetGrade) * geo.size.width, geo.size.width), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Required Score Section

    private func requiredScoreSection(requiredAverage: Double, remainingCount: Int, status: GoalStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: requiredAverage <= 100 ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(statusColor(status))

            VStack(alignment: .leading, spacing: 2) {
                if requiredAverage <= 0 {
                    Text("You have already reached your goal!")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else if requiredAverage > 100 {
                    Text("Target may be unreachable")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("You would need \(Int(requiredAverage))% avg on \(remainingCount) remaining assignment\(remainingCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Average \(Int(requiredAverage))% needed on remaining work")
                        .font(.caption.bold())
                        .foregroundStyle(Color(.label))
                    Text("\(remainingCount) assignment\(remainingCount == 1 ? "" : "s") left to submit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(statusColor(status).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Motivational Message

    private func motivationalMessage(status: GoalStatus, targetLetter: String, courseName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: motivationalIcon(status))
                .font(.title2)
                .foregroundStyle(statusColor(status))

            Text(motivationalText(status: status, targetLetter: targetLetter, courseName: courseName))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor(status).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: GoalStatus) -> some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status), in: Capsule())
            .accessibilityLabel("Status: \(status.rawValue)")
    }

    // MARK: - Status Calculation

    private enum GoalStatus: String {
        case onTrack = "On Track"
        case atRisk = "At Risk"
        case behind = "Behind"
        case achieved = "Achieved"
    }

    private func isOnTrack(courseId: UUID, currentGrade: Double) -> GoalStatus {
        guard let goal = viewModel.progressGoal(for: courseId) else { return .onTrack }

        if currentGrade >= goal.targetGrade {
            return .achieved
        }

        let gap = goal.targetGrade - currentGrade

        if let requiredAvg = viewModel.requiredAverageScore(courseId: courseId, targetGrade: goal.targetGrade) {
            if requiredAvg > 100 {
                return .behind
            } else if requiredAvg > 90 || gap > 15 {
                return .atRisk
            }
        }

        if gap <= 5 {
            return .onTrack
        } else if gap <= 12 {
            return .atRisk
        }

        return .behind
    }

    private func statusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .onTrack, .achieved: .green
        case .atRisk: .orange
        case .behind: .red
        }
    }

    private func motivationalIcon(_ status: GoalStatus) -> String {
        switch status {
        case .achieved: return "star.fill"
        case .onTrack: return "flame.fill"
        case .atRisk: return "bolt.fill"
        case .behind: return "heart.fill"
        }
    }

    private func motivationalText(status: GoalStatus, targetLetter: String, courseName: String) -> String {
        switch status {
        case .achieved:
            return "Amazing work! You have reached your \(targetLetter) goal in \(courseName). Keep it up!"
        case .onTrack:
            return "You are on track for \(targetLetter) in \(courseName). Stay consistent and you will get there!"
        case .atRisk:
            return "You can still hit your \(targetLetter) target in \(courseName). Focus on upcoming assignments to close the gap."
        case .behind:
            return "Reaching \(targetLetter) in \(courseName) will be challenging, but every point counts. Talk to your teacher for strategies."
        }
    }
}

// MARK: - Set Goal Sheet

private struct SetGoalSheet: View {
    let viewModel: AppViewModel
    let course: Course
    let currentGrade: Double
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLetterGrade = "B"
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Course info
                HStack(spacing: 12) {
                    Image(systemName: course.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(Theme.courseColor(course.colorName))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.title)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                        Text("Current: \(ProgressGoal.letterGrade(for: currentGrade)) (\(Int(currentGrade))%)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Grade picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Your Target Grade")
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 10)], spacing: 10) {
                        ForEach(ProgressGoal.allLetterGrades, id: \.self) { letter in
                            let percentage = ProgressGoal.gradePercentage(for: letter)
                            let isSelected = selectedLetterGrade == letter

                            Button {
                                hapticTrigger.toggle()
                                selectedLetterGrade = letter
                            } label: {
                                VStack(spacing: 4) {
                                    Text(letter)
                                        .font(.headline.bold())
                                    Text("\(Int(percentage))%")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isSelected
                                        ? Theme.courseColor(course.colorName)
                                        : Color(.secondarySystemGroupedBackground)
                                )
                                .foregroundStyle(isSelected ? .white : Color(.label))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            isSelected ? Color.clear : Color(.separator),
                                            lineWidth: 0.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                            .accessibilityLabel("\(letter), \(Int(percentage)) percent")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }

                // Preview of what it means
                let targetPct = ProgressGoal.gradePercentage(for: selectedLetterGrade)
                let gap = targetPct - currentGrade

                VStack(spacing: 8) {
                    if gap <= 0 {
                        Label("You are already at or above this target!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Label("You need to improve by \(Int(gap)) percentage points", systemImage: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundStyle(gap > 20 ? .red : (gap > 10 ? .orange : .green))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        hapticTrigger.toggle()
                        viewModel.setProgressGoal(
                            courseId: course.id,
                            targetLetterGrade: selectedLetterGrade
                        )
                        dismiss()
                    }
                    .sensoryFeedback(.success, trigger: hapticTrigger)
                    .bold()
                }
            }
            .onAppear {
                // Pre-select current goal if one exists
                if let existing = viewModel.progressGoal(for: course.id) {
                    selectedLetterGrade = existing.targetLetterGrade
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProgressGoalsView(viewModel: {
            let vm = AppViewModel()
            vm.loginAsDemo(role: .student)
            return vm
        }())
    }
}
