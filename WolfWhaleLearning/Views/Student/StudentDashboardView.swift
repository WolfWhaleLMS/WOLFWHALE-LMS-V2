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
                                .background(Color.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Warning: \(dataError)")
                            }
                            activitySection
                            xpCard
                            statsRow
                            FishTankView()
                            campusLifeSection
                            upcomingSection
                            assignmentCalendarLink
                            progressGoalsLink
                            browseCatalogCard
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
            .background { HolographicBackground() }
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


    // MARK: - XP Card

    private var xpCard: some View {
        NavigationLink {
            XPProfileView(viewModel: viewModel)
        } label: {
            HStack(spacing: 14) {
                // Mini XP ring
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: viewModel.xpProgressInLevel)
                        .stroke(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("Lv.\(viewModel.currentLevel)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(viewModel.currentXP) XP")
                            .font(.headline.bold())
                            .foregroundStyle(Color(.label))
                        Text(viewModel.levelTierName)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.indigo, in: Capsule())
                    }
                    Text("\(viewModel.xpToNextLevel) XP to next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Streak mini
                if viewModel.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text("\(viewModel.currentStreak)")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.indigo.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("XP Profile: Level \(viewModel.currentLevel), \(viewModel.currentXP) XP, \(viewModel.currentStreak) day streak")
        .accessibilityHint("Double tap to view your XP profile and badges")
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityHint("Double tap to view attendance history")

            NavigationLink {
                TimetableView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Schedule")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("View your class timetable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.indigo.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Weekly Schedule")
            .accessibilityHint("Double tap to view your weekly class timetable")
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .glassEffect(in: .rect(cornerRadius: 16))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                            Text(assignment.courseName)
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(assignment.dueDate, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(assignment.points) pts")
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())), \(assignment.points) points")
                }
            }
        }
    }

    // MARK: - Assignment Calendar Link

    private var assignmentCalendarLink: some View {
        NavigationLink {
            AssignmentCalendarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Assignment Calendar")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("View all due dates across courses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !viewModel.assignments.filter(\.isOverdue).isEmpty {
                    Text("\(viewModel.assignments.filter(\.isOverdue).count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.red, in: Circle())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.orange.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Assignment Calendar, view all due dates across courses")
        .accessibilityHint("Double tap to open the assignment calendar")
    }

    // MARK: - Progress Goals Link

    private var progressGoalsLink: some View {
        NavigationLink {
            ProgressGoalsView(viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Goals")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Set grade targets & track progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.green.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Progress Goals, set grade targets and track progress")
        .accessibilityHint("Double tap to view and set grade goals")
    }

    // MARK: - Browse Course Catalog

    private var browseCatalogCard: some View {
        NavigationLink {
            CourseCatalogView(viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "book.and.wrench.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Browse Courses")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Discover and enroll in new courses")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.indigo.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse Courses")
        .accessibilityHint("Double tap to discover and enroll in new courses")
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.courseColor(course.colorName).opacity(0.3), lineWidth: 1)
        )
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
