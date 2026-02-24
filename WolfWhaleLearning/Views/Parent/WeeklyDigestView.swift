import SwiftUI

struct WeeklyDigestView: View {
    @Bindable var viewModel: AppViewModel
    @State private var digests: [WeeklyDigest] = []
    @State private var isLoading = true

    private let digestService = WeeklyDigestService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Generating weekly summary...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .accessibilityLabel("Loading weekly digest")
                } else if digests.isEmpty {
                    emptyState
                } else {
                    weekRangeHeader

                    ForEach(Array(digests.enumerated()), id: \.offset) { _, digest in
                        childDigestSection(digest)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress Report")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadDigests()
        }
        .refreshable {
            loadDigests()
        }
    }

    // MARK: - Week Range Header

    private var weekRangeHeader: some View {
        Group {
            if let first = digests.first {
                HStack {
                    Image(systemName: "calendar.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week of \(first.weekStartDate, style: .date)")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        Text("through \(first.weekEndDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Week of \(first.weekStartDate.formatted(.dateTime.month(.abbreviated).day())) through \(first.weekEndDate.formatted(.dateTime.month(.abbreviated).day()))")
            }
        }
    }

    // MARK: - Child Digest Section

    private func childDigestSection(_ digest: WeeklyDigest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Child Name Header
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }

                Text(digest.childName)
                    .font(.headline)
                    .foregroundStyle(Color(.label))

                Spacer()

                Text("\(digest.assignmentsCompleted) completed")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }

            // Grade Changes
            gradeChangesSection(digest.gradeChanges)

            // Attendance Summary
            attendanceSummarySection(digest.attendanceSummary)

            // Assignments Due Next Week
            upcomingAssignmentsSection(digest.assignmentsDueNextWeek)

            // Teacher Comments
            teacherCommentsSection(digest.teacherComments)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekly digest for \(digest.childName)")
    }

    // MARK: - Grade Changes

    private func gradeChangesSection(_ changes: [WeeklyGradeChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Grade Changes", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            if changes.isEmpty {
                Text("No grade changes this week")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            } else {
                ForEach(changes) { change in
                    HStack(spacing: 10) {
                        Image(systemName: change.isImproving ? "arrow.up.right" : (change.changeAmount < 0 ? "arrow.down.right" : "arrow.right"))
                            .font(.caption)
                            .foregroundStyle(gradeChangeColor(change))
                            .frame(width: 20)

                        Text(change.courseName)
                            .font(.caption)
                            .foregroundStyle(Color(.label))
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Text(change.letterGrade)
                                .font(.caption.bold())
                                .foregroundStyle(gradeChangeColor(change))

                            Text(String(format: "%.0f%%", change.currentGrade))
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))

                            let changeText = change.changeAmount >= 0
                                ? "+\(String(format: "%.0f", change.changeAmount))"
                                : String(format: "%.0f", change.changeAmount)
                            Text(changeText)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(gradeChangeColor(change).opacity(0.15), in: Capsule())
                                .foregroundStyle(gradeChangeColor(change))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(change.courseName), \(change.letterGrade), \(String(format: "%.0f", change.currentGrade)) percent, change of \(String(format: "%.0f", change.changeAmount))")
                }
            }
        }
    }

    // MARK: - Attendance Summary

    private func attendanceSummarySection(_ summary: DigestAttendanceSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Attendance", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            HStack(spacing: 12) {
                attendancePill(label: "Present", count: summary.presentDays, color: .green)
                attendancePill(label: "Absent", count: summary.absentDays, color: .red)
                attendancePill(label: "Tardy", count: summary.tardyDays, color: .orange)
            }

            // Attendance rate bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.quaternarySystemFill))
                    Capsule()
                        .fill(attendanceRateColor(summary.attendanceRate).gradient)
                        .frame(width: geo.size.width * min(summary.attendanceRate, 1.0))
                }
            }
            .frame(height: 8)

            Text("\(Int(summary.attendanceRate * 100))% attendance rate")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .accessibilityLabel("Attendance rate \(Int(summary.attendanceRate * 100)) percent")
        }
    }

    private func attendancePill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count) days")
    }

    // MARK: - Upcoming Assignments

    private func upcomingAssignmentsSection(_ assignments: [DigestAssignment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Due Next Week", systemImage: "calendar.badge.exclamationmark")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            if assignments.isEmpty {
                Text("No assignments due next week")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            } else {
                ForEach(assignments) { assignment in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.title)
                                .font(.caption)
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                            Text(assignment.courseName)
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        Text(assignment.dueDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                }
            }
        }
    }

    // MARK: - Teacher Comments

    private func teacherCommentsSection(_ comments: [DigestTeacherComment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Teacher Comments", systemImage: "text.bubble.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            if comments.isEmpty {
                Text("No teacher comments this week")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(comment.teacherName)
                                .font(.caption.bold())
                                .foregroundStyle(.pink)
                            Spacer()
                            Text(comment.courseName)
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Text(comment.comment)
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(3)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Comment from \(comment.teacherName) for \(comment.courseName): \(comment.comment)")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Digest Available")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Weekly digests will be generated once children are linked to your account.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func loadDigests() {
        isLoading = true
        if viewModel.children.isEmpty {
            digests = []
        } else if viewModel.isDemoMode {
            digests = viewModel.children.map { digestService.generateDemoDigest(child: $0) }
        } else {
            digests = digestService.generateDigests(
                children: viewModel.children,
                assignments: viewModel.assignments,
                attendance: viewModel.attendance,
                courses: viewModel.courses
            )
        }
        isLoading = false
    }

    private func gradeChangeColor(_ change: WeeklyGradeChange) -> Color {
        if change.changeAmount > 0 { return .green }
        if change.changeAmount < 0 { return .red }
        return .gray
    }

    private func attendanceRateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.9...: .green
        case 0.7..<0.9: .orange
        default: .red
        }
    }
}
