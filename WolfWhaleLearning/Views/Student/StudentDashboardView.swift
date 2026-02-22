import SwiftUI

struct StudentDashboardView: View {
    let viewModel: AppViewModel
    @State private var appeared = false
    @State private var showNotifications = false
    @State private var showRadio = false
    @State private var showWidgetGallery = false
    @State private var hapticTrigger = false

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
        viewModel.totalUnreadMessages
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
                    GlassEffectContainer {
                        LazyVStack(spacing: 20) {
                            if let dataError = viewModel.dataError {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text(dataError)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        viewModel.dataError = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 12))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Warning: \(dataError)")
                            }
                            activitySection
                            statsRow
                            FishTankView()
                            campusLifeSection
                            upcomingSection
                            coursesSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(greeting), \(viewModel.currentUser?.firstName ?? "Student")")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .symbolEffect(.bounce, value: totalUnreadMessages)
                                .padding(6)

                            if totalUnreadMessages > 0 {
                                Text("\(totalUnreadMessages)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(.red, in: Circle())
                            }
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel(totalUnreadMessages > 0 ? "Notifications, \(totalUnreadMessages) unread" : "Notifications")
                    .accessibilityHint("Double tap to view notifications")
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showRadio) {
                RadioView()
            }
            .sheet(isPresented: $showWidgetGallery) {
                WidgetGalleryView(viewModel: viewModel)
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ActivityRingView(
                    lessonsProgress: lessonsProgress,
                    assignmentsProgress: assignmentsProgress
                )

                VStack(alignment: .leading, spacing: 10) {
                    ActivityRingLabel(title: "Lessons", value: "\(completedLessons)/\(totalLessons) done", color: .green)
                    ActivityRingLabel(title: "Assignments", value: "\(submittedAssignments)/\(totalAssignments) done", color: .cyan)
                }
                Spacer()
            }
            .padding(20)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity rings: \(completedLessons) of \(totalLessons) lessons done, \(submittedAssignments) of \(totalAssignments) assignments done")
    }

    private var statsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(icon: "flame.fill", value: "\(viewModel.currentUser?.streak ?? 0)", label: "Day Streak", color: .orange)
            }

            NavigationLink {
                AttendanceHistoryView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text("Attendance History")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .accessibilityHint("Double tap to view attendance history")
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
        .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Campus Life Section

    private var campusLifeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Campus Life")
                .font(.headline)

            // Compact campus location label (static — avoids spawning a duplicate CLLocationManager)
            NavigationLink {
                CampusLocationView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campus Location")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Tap to view location status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Campus Map
            NavigationLink {
                CampusMapView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campus Map")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Buildings & rooms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Campus Map")
            .accessibilityHint("Double tap to open the interactive campus map")

            // Classroom Finder
            NavigationLink {
                ClassroomFinderView(courses: viewModel.courses)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Classroom Finder")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Find your next class")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Classroom Finder")
            .accessibilityHint("Double tap to find your classroom on the map")

            // Study Groups
            NavigationLink {
                StudyGroupView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Study Groups")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Connect with nearby classmates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Study Groups")
            .accessibilityHint("Double tap to find and join nearby study groups")

            HStack(spacing: 12) {
                // Radio button
                Button {
                    hapticTrigger.toggle()
                    showRadio = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "radio.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Campus Radio")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Listen now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Campus Radio")
                .accessibilityHint("Double tap to open the radio player")
            }

            // Widget gallery link
            Button {
                hapticTrigger.toggle()
                showWidgetGallery = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apps.iphone")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home Screen Widgets")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Preview & add widgets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("Home Screen Widgets")
            .accessibilityHint("Double tap to preview available widgets")
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Deadlines")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", value: "assignments")
                    .font(.subheadline)
                    .accessibilityHint("Double tap to view all assignments")
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
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
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

            if viewModel.courses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No courses yet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Enroll in a course to start learning")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
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
        .glassEffect(.regular.tint(Theme.courseColor(course.colorName)), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.title), taught by \(course.teacherName), \(Int(course.progress * 100)) percent complete")
        .accessibilityHint("Double tap to open course")
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    private var totalUnreadMessages: Int {
        viewModel.totalUnreadMessages
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
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }
}
