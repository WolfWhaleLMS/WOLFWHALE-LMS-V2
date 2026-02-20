import SwiftUI

nonisolated struct ChildDetailView: View, Sendable {
    let child: ChildInfo
    @Bindable var viewModel: AppViewModel

    // MARK: - Computed Properties

    private var gpaProgress: Double {
        min(child.gpa / 4.0, 1.0)
    }

    private var gpaColor: Color {
        Theme.gradeColor(child.gpa / 4.0 * 100)
    }

    private var attendanceColor: Color {
        switch child.attendanceRate {
        case 0.9...: .green
        case 0.7..<0.9: .orange
        default: .red
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                childHeader
                academicSummary
                courseGradesSection
                recentAssignmentsSection
                quickActionsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Child Header

    private var childHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: child.avatarSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.title3.bold())
                Text(child.grade)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(child.courses.count) courses enrolled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Academic Summary

    private var academicSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Academic Summary")
                .font(.headline)

            HStack(spacing: 20) {
                // GPA Ring
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(gpaColor.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: gpaProgress)
                            .stroke(gpaColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", child.gpa))
                                .font(.title3.bold())
                            Text("GPA")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 90, height: 90)
                }
                .frame(maxWidth: .infinity)

                // Attendance Rate Ring
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(attendanceColor.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: min(child.attendanceRate, 1.0))
                            .stroke(attendanceColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(Int(child.attendanceRate * 100))%")
                                .font(.title3.bold())
                            Text("Attend.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 90, height: 90)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Course Grades

    private var courseGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Grades")
                .font(.headline)

            if child.courses.isEmpty {
                HStack {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                    Text("No courses enrolled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(child.courses) { grade in
                    courseGradeRow(grade)
                }
            }
        }
    }

    private func courseGradeRow(_ grade: GradeEntry) -> some View {
        let gradeColor = Theme.gradeColor(grade.numericGrade)
        let progress = grade.numericGrade / 100.0

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: grade.courseIcon)
                    .font(.title3)
                    .foregroundStyle(Theme.courseColor(grade.courseColor))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(grade.courseName)
                        .font(.subheadline.bold())
                    Text("\(grade.assignmentGrades.count) graded assignments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(grade.letterGrade)
                        .font(.headline.bold())
                        .foregroundStyle(gradeColor)
                    Text(String(format: "%.0f%%", grade.numericGrade))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Grade progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.quaternarySystemFill))
                    Capsule()
                        .fill(gradeColor.gradient)
                        .frame(width: geo.size.width * min(progress, 1.0))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Recent Assignments

    private var recentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assignments")
                .font(.headline)

            if child.recentAssignments.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No recent assignments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(child.recentAssignments) { assignment in
                    assignmentRow(assignment)
                }
            }
        }
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(assignmentStatusColor(assignment).gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: assignmentIcon(assignment))
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(assignment.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(assignment.statusText)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(assignmentStatusColor(assignment).opacity(0.15), in: Capsule())
                    .foregroundStyle(assignmentStatusColor(assignment))

                Text(assignment.dueDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func assignmentStatusColor(_ assignment: Assignment) -> Color {
        if assignment.grade != nil { return .green }
        if assignment.isSubmitted { return .blue }
        if assignment.isOverdue { return .red }
        return .orange
    }

    private func assignmentIcon(_ assignment: Assignment) -> String {
        if assignment.grade != nil { return "checkmark.circle.fill" }
        if assignment.isSubmitted { return "paperplane.fill" }
        if assignment.isOverdue { return "exclamationmark.circle.fill" }
        return "clock.fill"
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                NavigationLink {
                    AttendanceHistoryView(viewModel: viewModel)
                } label: {
                    quickActionButton(
                        icon: "calendar.badge.clock",
                        title: "Attendance",
                        subtitle: "View history",
                        color: .green
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ParentMessagingView(viewModel: viewModel, child: child)
                } label: {
                    quickActionButton(
                        icon: "message.fill",
                        title: "Message",
                        subtitle: "Contact teachers",
                        color: .pink
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionButton(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline.bold())

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
