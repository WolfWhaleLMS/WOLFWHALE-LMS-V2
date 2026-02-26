import SwiftUI

struct ProgressDetailView: View {
    let viewModel: AppViewModel
    @State private var progressService = ProgressService()
    @State private var sortOption: ProgressService.SortOption = .completion
    @State private var hapticTrigger = false

    private var allProgress: [ProgressService.CourseProgress] {
        progressService.allCourseProgress(
            courses: viewModel.courses,
            assignments: viewModel.assignments,
            quizzes: viewModel.quizzes,
            grades: viewModel.grades
        )
    }

    private var sortedProgress: [ProgressService.CourseProgress] {
        progressService.sorted(allProgress, by: sortOption)
    }

    private var overallPercentage: Double {
        progressService.overallCompletionPercentage(progressList: allProgress)
    }

    private var streak: Int {
        progressService.studyStreak(user: viewModel.currentUser)
    }

    private var weeklySummary: ProgressService.WeeklySummary {
        progressService.weeklySummary(
            courses: viewModel.courses,
            assignments: viewModel.assignments,
            quizzes: viewModel.quizzes,
            streakDays: streak
        )
    }

    private var nextUpItems: [ProgressService.NextUpItem] {
        progressService.nextUpItems(
            courses: viewModel.courses,
            assignments: viewModel.assignments,
            quizzes: viewModel.quizzes
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                overallStatsSection
                weeklySummarySection
                nextUpSection
                coursesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.loadAssignmentsIfNeeded()
            viewModel.loadQuizzesIfNeeded()
            viewModel.loadGradesIfNeeded()
        }
    }

    // MARK: - Overall Stats

    private var overallStatsSection: some View {
        HStack(spacing: 16) {
            overallRing
            overallStatsText
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall progress: \(Int(overallPercentage * 100)) percent complete, \(streak) day streak, \(viewModel.courses.count) courses")
    }

    @State private var animatedOverall: Double = 0

    private var overallRing: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 12)

            Circle()
                .trim(from: 0, to: animatedOverall)
                .stroke(
                    AngularGradient(
                        colors: [.green, .cyan, .green],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(overallPercentage * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Overall")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.2).delay(0.2)) {
                animatedOverall = min(overallPercentage, 1.0)
            }
        }
    }

    private var overallStatsText: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak) Day Streak")
                        .font(.subheadline.bold())
                    Text("Keep it going!")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(viewModel.courses.count) Courses")
                        .font(.subheadline.bold())
                    Text("enrolled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce)
                VStack(alignment: .leading, spacing: 1) {
                    let totalCompleted = allProgress.reduce(0) { $0 + $1.lessonsCompleted }
                    let totalLessons = allProgress.reduce(0) { $0 + $1.lessonsTotal }
                    Text("\(totalCompleted)/\(totalLessons) Lessons")
                        .font(.subheadline.bold())
                    Text("completed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weekly Summary

    private var weeklySummarySection: some View {
        WeeklySummaryCard(summary: weeklySummary)
    }

    // MARK: - Next Up

    private var nextUpSection: some View {
        Group {
            if !nextUpItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.orange)
                            .symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: 3)))
                        Text("Next Up")
                            .font(.headline)
                        Spacer()
                    }

                    ForEach(Array(nextUpItems.prefix(5))) { item in
                        nextUpRow(item)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func nextUpRow(_ item: ProgressService.NextUpItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.iconName)
                .font(.subheadline)
                .foregroundStyle(Theme.courseColor(item.courseColor))
                .frame(width: 32, height: 32)
                .background(Theme.courseColor(item.courseColor).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.type.label)
                        .font(.caption2)
                        .foregroundStyle(Theme.courseColor(item.courseColor))
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(item.courseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let dueDate = item.dueDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dueDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("due")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.label): \(item.title) for \(item.courseName)\(item.dueDate != nil ? ", due \(item.dueDate!.formatted(.dateTime.month(.abbreviated).day()))" : "")")
    }

    // MARK: - Courses

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Course Progress")
                    .font(.headline)
                Spacer()
                sortPicker
            }

            if sortedProgress.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)
                    Text("No courses yet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Enroll in courses to track your progress")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(sortedProgress, id: \.courseId) { courseProgress in
                    verticalCourseCard(courseProgress)
                }
            }
        }
    }

    private var sortPicker: some View {
        Menu {
            ForEach(ProgressService.SortOption.allCases, id: \.self) { option in
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.smooth) {
                        sortOption = option
                    }
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
            HStack(spacing: 4) {
                Text(sortOption.rawValue)
                    .font(.caption)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    // MARK: - Vertical Course Card (for list layout)

    private func verticalCourseCard(_ progress: ProgressService.CourseProgress) -> some View {
        let color = Theme.courseColor(progress.colorName)

        return VStack(alignment: .leading, spacing: 14) {
            // Header: icon, name, ring
            HStack(spacing: 12) {
                Image(systemName: progress.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.courseName)
                        .font(.subheadline.bold())
                    Text(progress.teacherName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatRing(
                    progress: progress.overallPercentage,
                    color: color,
                    lineWidth: 5,
                    size: 44
                )
                .overlay {
                    Text("\(Int(progress.overallPercentage * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }

            // Progress bars
            HStack(spacing: 16) {
                verticalProgressItem(
                    label: "Lessons",
                    completed: progress.lessonsCompleted,
                    total: progress.lessonsTotal,
                    color: .green
                )
                verticalProgressItem(
                    label: "Assignments",
                    completed: progress.assignmentsSubmitted,
                    total: progress.assignmentsTotal,
                    color: .cyan
                )
                verticalProgressItem(
                    label: "Quizzes",
                    completed: progress.quizzesCompleted,
                    total: progress.quizzesTotal,
                    color: .purple
                )
            }

            // Grade row
            if let grade = progress.currentGrade {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.gradeColor(grade))
                            .frame(width: 8, height: 8)
                        if let letter = progress.letterGrade {
                            Text(letter)
                                .font(.caption.bold())
                                .foregroundStyle(Theme.gradeColor(grade))
                        }
                        Text("\(Int(grade))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if progress.nextUncompletedLesson != nil {
                        HStack(spacing: 4) {
                            Text("Next:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(progress.nextUncompletedLesson?.title ?? "")
                                .font(.caption2.bold())
                                .foregroundStyle(color)
                                .lineLimit(1)
                        }
                    }
                }
            } else if progress.nextUncompletedLesson != nil {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Next:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(progress.nextUncompletedLesson?.title ?? "")
                            .font(.caption2.bold())
                            .foregroundStyle(color)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.courseName), \(Int(progress.overallPercentage * 100)) percent complete, \(progress.lessonsCompleted) of \(progress.lessonsTotal) lessons, taught by \(progress.teacherName)")
    }

    private func verticalProgressItem(label: String, completed: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.gradient)
                        .frame(width: total > 0
                            ? geometry.size.width * CGFloat(completed) / CGFloat(total)
                            : 0
                        )
                }
            }
            .frame(height: 4)
        }
    }
}
