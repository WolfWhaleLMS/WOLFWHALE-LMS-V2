import SwiftUI

struct CourseProgressCard: View {
    let progress: ProgressService.CourseProgress
    let onContinue: (() -> Void)?

    @State private var animatedProgress: Double = 0
    @State private var hapticTrigger = false

    init(progress: ProgressService.CourseProgress, onContinue: (() -> Void)? = nil) {
        self.progress = progress
        self.onContinue = onContinue
    }

    private var courseColor: Color {
        Theme.courseColor(progress.colorName)
    }

    private var completionText: String {
        "\(progress.lessonsCompleted) of \(progress.lessonsTotal) lessons completed"
    }

    private var percentageText: String {
        "\(Int(progress.overallPercentage * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: ring + course info
            HStack(spacing: 14) {
                completionRing
                courseInfo
                Spacer()
            }

            // Mini progress bars
            progressBarsSection

            // Grade + continue button
            bottomSection
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).fill(courseColor.opacity(0.06)))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.2).delay(0.1)) {
                animatedProgress = min(progress.overallPercentage, 1.0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.courseName), \(completionText), \(percentageText) complete")
        .accessibilityHint(progress.nextUncompletedLesson != nil ? "Double tap to continue learning" : "")
    }

    // MARK: - Completion Ring

    private var completionRing: some View {
        ZStack {
            Circle()
                .stroke(courseColor.opacity(0.15), lineWidth: 8)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [courseColor, courseColor.opacity(0.7), courseColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(percentageText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(courseColor)
            }
        }
        .frame(width: 64, height: 64)
    }

    // MARK: - Course Info

    private var courseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: progress.iconSystemName)
                    .font(.caption)
                    .foregroundStyle(courseColor)
                Text(progress.courseName)
                    .font(.subheadline.bold())
                    .lineLimit(2)
            }

            Text(progress.teacherName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(completionText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Mini Progress Bars

    private var progressBarsSection: some View {
        VStack(spacing: 6) {
            miniProgressBar(
                label: "Lessons",
                completed: progress.lessonsCompleted,
                total: progress.lessonsTotal,
                color: .green
            )
            miniProgressBar(
                label: "Assignments",
                completed: progress.assignmentsSubmitted,
                total: progress.assignmentsTotal,
                color: .cyan
            )
            miniProgressBar(
                label: "Quizzes",
                completed: progress.quizzesCompleted,
                total: progress.quizzesTotal,
                color: .purple
            )
        }
    }

    private func miniProgressBar(label: String, completed: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: total > 0
                            ? geometry.size.width * CGFloat(completed) / CGFloat(total)
                            : 0
                        )
                }
            }
            .frame(height: 4)

            Text("\(completed)/\(total)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Bottom: Grade + Continue

    private var bottomSection: some View {
        HStack {
            if let grade = progress.currentGrade {
                gradeChip(grade: grade, letter: progress.letterGrade)
            }

            Spacer()

            if progress.nextUncompletedLesson != nil, let action = onContinue {
                Button {
                    hapticTrigger.toggle()
                    action()
                } label: {
                    HStack(spacing: 4) {
                        Text("Continue")
                            .font(.caption.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(courseColor.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    private func gradeChip(grade: Double, letter: String?) -> some View {
        HStack(spacing: 4) {
            if let letter {
                Text(letter)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.gradeColor(grade))
            }
            Text("\(Int(grade))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.gradeColor(grade).opacity(0.12), in: Capsule())
    }
}
