import SwiftUI

struct ChildDetailView: View {
    let child: ChildInfo
    @Bindable var viewModel: AppViewModel

    @State private var isCreatingConversation = false
    @State private var messageTeacherError: String?
    @State private var hapticTrigger = false

    // MARK: - Computed Properties

    private var gpaProgress: Double {
        min(displayChild.gpa / 4.0, 1.0)
    }

    private var gpaColor: Color {
        Theme.gradeColor(displayChild.gpa / 4.0 * 100)
    }

    private var attendanceColor: Color {
        switch displayChild.attendanceRate {
        case 0.9...: .green
        case 0.7..<0.9: .orange
        default: .red
        }
    }

    // MARK: - Body

    /// The child data currently displayed. Starts with the passed-in snapshot and
    /// is updated when the parent pulls-to-refresh.
    private var displayChild: ChildInfo {
        viewModel.children.first(where: { $0.id == child.id }) ?? child
    }

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
        .navigationTitle(displayChild.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.refreshData()
        }
        .alert("Error", isPresented: .constant(messageTeacherError != nil)) {
            Button("OK") { messageTeacherError = nil }
        } message: {
            Text(messageTeacherError ?? "")
        }
    }

    // MARK: - Child Header

    private var childHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: displayChild.avatarSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.breathe)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayChild.name)
                    .font(.title3.bold())
                Text(displayChild.grade)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(displayChild.courses.count) courses enrolled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayChild.name), \(displayChild.grade), \(displayChild.courses.count) courses enrolled")
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
                            Text(String(format: "%.1f", displayChild.gpa))
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
                            .trim(from: 0, to: min(displayChild.attendanceRate, 1.0))
                            .stroke(attendanceColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(Int(displayChild.attendanceRate * 100))%")
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
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Academic Summary: GPA \(String(format: "%.1f", displayChild.gpa)) out of 4.0, Attendance \(Int(displayChild.attendanceRate * 100)) percent")
    }

    // MARK: - Course Grades

    private var courseGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Grades")
                .font(.headline)

            if displayChild.courses.isEmpty {
                HStack {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)
                    Text("No courses enrolled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            } else {
                ForEach(displayChild.courses) { grade in
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

            // Message Teacher button for this course
            Button {
                hapticTrigger.toggle()
                startConversationForCourse(grade)
            } label: {
                Label("Message Teacher", systemImage: "message.fill")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .controlSize(.small)
            .disabled(isCreatingConversation)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(grade.courseName): Grade \(grade.letterGrade), \(String(format: "%.0f", grade.numericGrade)) percent, \(grade.assignmentGrades.count) graded assignments")
    }

    // MARK: - Recent Assignments

    private var recentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assignments")
                .font(.headline)

            if displayChild.recentAssignments.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)
                    Text("No recent assignments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            } else {
                ForEach(displayChild.recentAssignments) { assignment in
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
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title) for \(assignment.courseName), \(assignment.statusText), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
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
                .symbolEffect(.bounce)

            Text(title)
                .font(.subheadline.bold())

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityHint("Double tap to open")
    }

    // MARK: - Message Teacher per Course

    /// Find the teacher for a specific course and create or navigate to a conversation.
    private func startConversationForCourse(_ grade: GradeEntry) {
        isCreatingConversation = true
        messageTeacherError = nil

        // Look up the matching Course object to get the teacher name
        let matchedCourse = viewModel.courses.first { $0.title == grade.courseName }
        let teacherName = matchedCourse?.teacherName ?? ""

        guard !teacherName.isEmpty else {
            isCreatingConversation = false
            messageTeacherError = "No teacher found for \(grade.courseName)."
            return
        }

        guard let currentUser = viewModel.currentUser else {
            isCreatingConversation = false
            messageTeacherError = "You must be logged in to send messages."
            return
        }

        let title = "Re: \(displayChild.name) - \(grade.courseName)"

        // Check for an existing conversation
        if viewModel.conversations.contains(where: { conversation in
            conversation.participantNames.contains(teacherName) &&
            conversation.title == title
        }) {
            isCreatingConversation = false
            // The conversation already exists -- the user can find it in the messaging view
            return
        }

        // Find the teacher's ProfileDTO to get their UUID
        let teacherProfile = viewModel.allUsers.first { profile in
            let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
            return fullName == teacherName
        }

        guard let teacherId = teacherProfile?.id else {
            isCreatingConversation = false
            messageTeacherError = "Teacher information unavailable for \(grade.courseName). Please try again later."
            return
        }

        Task {
            let participants: [(userId: UUID, userName: String)] = [
                (userId: currentUser.id, userName: currentUser.fullName),
                (userId: teacherId, userName: teacherName)
            ]
            await viewModel.createConversation(
                title: title,
                participantIds: participants
            )
            isCreatingConversation = false
        }
    }
}
