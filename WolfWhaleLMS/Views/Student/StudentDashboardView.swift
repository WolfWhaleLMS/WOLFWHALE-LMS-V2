import SwiftUI

struct StudentDashboardView: View {
    let viewModel: AppViewModel
    @State private var appeared = false
    @State private var showNotifications = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var totalLessons: Int {
        viewModel.courses.reduce(0) { $0 + $1.totalLessons }
    }

    private var completedLessons: Int {
        viewModel.courses.reduce(0) { $0 + $1.completedLessons }
    }

    private var lessonsProgress: Double {
        totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0
    }

    private var totalAssignments: Int {
        viewModel.assignments.count
    }

    private var submittedAssignments: Int {
        viewModel.assignments.filter(\.isSubmitted).count
    }

    private var assignmentsProgress: Double {
        totalAssignments > 0 ? Double(submittedAssignments) / Double(totalAssignments) : 0
    }

    private var totalUnreadMessages: Int {
        viewModel.conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isDataLoading && viewModel.courses.isEmpty {
                    VStack(spacing: 20) {
                        ShimmerLoadingView(rowCount: 4)
                        LoadingStateView(
                            icon: "graduationcap.fill",
                            title: "Loading Dashboard",
                            message: "Fetching your courses, assignments, and progress..."
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 20) {
                        activitySection
                        statsRow
                        xpSection
                        upcomingSection
                        coursesSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(greeting), \(viewModel.currentUser?.firstName ?? "Student")")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .symbolEffect(.bounce, value: totalUnreadMessages)
                    }
                    .accessibilityLabel(totalUnreadMessages > 0 ? "Notifications, \(totalUnreadMessages) unread" : "Notifications")
                    .accessibilityHint("Double tap to view notifications")
                    .overlay(alignment: .topTrailing) {
                        if totalUnreadMessages > 0 {
                            Text("\(totalUnreadMessages)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(viewModel: viewModel)
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ActivityRingView(
                    lessonsProgress: lessonsProgress,
                    assignmentsProgress: assignmentsProgress,
                    xpProgress: viewModel.currentUser?.xpProgress ?? 0
                )

                VStack(alignment: .leading, spacing: 10) {
                    ActivityRingLabel(title: "Lessons", value: "\(completedLessons)/\(totalLessons) done", color: .green)
                    ActivityRingLabel(title: "Assignments", value: "\(submittedAssignments)/\(totalAssignments) done", color: .cyan)
                    ActivityRingLabel(title: "XP Earned", value: "\(viewModel.currentUser?.xp ?? 0) XP", color: .purple)
                }
                Spacer()
            }
            .padding(20)
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity rings: \(completedLessons) of \(totalLessons) lessons done, \(submittedAssignments) of \(totalAssignments) assignments done, \(viewModel.currentUser?.xp ?? 0) XP earned")
    }

    private var statsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(icon: "flame.fill", value: "\(viewModel.currentUser?.streak ?? 0)", label: "Day Streak", color: .orange)
                statCard(icon: "star.fill", value: "Lv.\(viewModel.currentUser?.level ?? 1)", label: "Level", color: .purple)
                statCard(icon: "bitcoinsign.circle.fill", value: "\(viewModel.currentUser?.coins ?? 0)", label: "Coins", color: .yellow)
            }

            HStack(spacing: 12) {
                NavigationLink {
                    AttendanceHistoryView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Attendance")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }

                NavigationLink {
                    LeaderboardView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text("Leaderboard")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var xpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Experience Points")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(viewModel.currentUser?.xp ?? 0) / \(viewModel.currentUser?.xpForNextLevel ?? 500) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            XPBar(progress: viewModel.currentUser?.xpProgress ?? 0, level: viewModel.currentUser?.level ?? 1)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Experience Points: \(viewModel.currentUser?.xp ?? 0) of \(viewModel.currentUser?.xpForNextLevel ?? 500) XP, Level \(viewModel.currentUser?.level ?? 1)")
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Deadlines")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", value: "assignments")
                    .font(.subheadline)
            }

            if viewModel.upcomingAssignments.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(viewModel.upcomingAssignments.prefix(3)) { assignment in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.orange.gradient)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "doc.text.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.title)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text(assignment.courseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(assignment.dueDate, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(assignment.points) pts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())), \(assignment.points) points")
                }
            }
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Learning")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.courses) { course in
                        NavigationLink(value: course) {
                            courseCard(course)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .navigationDestination(for: Course.self) { course in
            CourseDetailView(course: course, viewModel: viewModel)
        }
        .navigationDestination(for: String.self) { destination in
            if destination == "assignments" {
                AssignmentsView(viewModel: viewModel)
            }
        }
    }

    private func courseCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: course.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(Theme.courseColor(course.colorName))
                Spacer()
                Text("\(Int(course.progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(course.title)
                .font(.subheadline.bold())
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(course.teacherName)
                .font(.caption)
                .foregroundStyle(.secondary)

            StatRing(progress: course.progress, color: Theme.courseColor(course.colorName), lineWidth: 4, size: 32)
        }
        .frame(width: 160)
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.title), taught by \(course.teacherName), \(Int(course.progress * 100)) percent complete")
        .accessibilityHint("Double tap to open course")
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private var totalUnreadMessages: Int {
        viewModel.conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        NavigationStack {
            List {
                // Unread messages summary
                if totalUnreadMessages > 0 {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "message.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unread Messages")
                                    .font(.subheadline.bold())
                                Text("\(totalUnreadMessages) unread message\(totalUnreadMessages == 1 ? "" : "s") across your conversations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        ForEach(viewModel.conversations.filter { $0.unreadCount > 0 }) { conversation in
                            HStack(spacing: 10) {
                                Image(systemName: conversation.avatarSystemName)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title)
                                        .font(.subheadline)
                                    Text(conversation.lastMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(conversation.unreadCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(.blue, in: Circle())
                            }
                        }
                    } header: {
                        Text("Messages")
                    }
                }

                // Announcements
                if !viewModel.announcements.isEmpty {
                    Section {
                        ForEach(viewModel.announcements) { announcement in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    if announcement.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    Text(announcement.title)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(announcement.date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(announcement.content)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("by \(announcement.authorName)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Announcements")
                    }
                }

                // Empty state
                if totalUnreadMessages == 0 && viewModel.announcements.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "bell.slash",
                        description: Text("No new notifications right now")
                    )
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
