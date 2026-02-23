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
                    LazyVStack(spacing: 16) {
                        if let dataError = viewModel.dataError {
                            errorBanner(dataError)
                        }
                        activitySection
                        coursesSection
                        upcomingSection
                        quickLinksSection
                        campusSection
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

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
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
        .accessibilityLabel("Warning: \(message)")
    }

    // MARK: - Activity Section

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
        .glassCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity rings: \(completedLessons) of \(totalLessons) lessons done, \(submittedAssignments) of \(totalAssignments) assignments done")
    }

    // MARK: - Courses Section

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
                .glassCard(cornerRadius: 16)
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

    // MARK: - Upcoming Section

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
                .glassCard(cornerRadius: 12)
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
                    .glassCard(cornerRadius: 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())), \(assignment.points) points")
                }
            }
        }
    }

    // MARK: - Quick Links

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Links")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickLinkCard(
                    icon: "calendar.badge.clock",
                    title: "Calendar",
                    color: .orange,
                    destination: AnyView(AssignmentCalendarView(viewModel: viewModel))
                )

                quickLinkCard(
                    icon: "target",
                    title: "Goals",
                    color: .green,
                    destination: AnyView(ProgressGoalsView(viewModel: viewModel))
                )

                quickLinkCard(
                    icon: "calendar.day.timeline.leading",
                    title: "Schedule",
                    color: .indigo,
                    destination: AnyView(TimetableView(viewModel: viewModel))
                )

                quickLinkCard(
                    icon: "calendar.badge.clock",
                    title: "Attendance",
                    color: .green,
                    destination: AnyView(AttendanceHistoryView(viewModel: viewModel))
                )
            }

            // Browse Courses
            NavigationLink {
                CourseCatalogView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "book.and.wrench.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
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
                .glassCard(cornerRadius: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Browse Courses")
            .accessibilityHint("Double tap to discover and enroll in new courses")
        }
    }

    private func quickLinkCard(icon: String, title: String, color: Color, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to open \(title)")
    }

    // MARK: - Campus Section (Compact)

    private var campusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Campus")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                campusLink(icon: "map.fill", title: "Campus Map", color: .blue) {
                    CampusMapView()
                }

                campusLink(icon: "location.magnifyingglass", title: "Classrooms", color: .green) {
                    ClassroomFinderView(courses: viewModel.courses)
                }

                Button {
                    hapticTrigger.toggle()
                    showRadio = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "radio.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                        Text("Radio")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    showWidgetGallery = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "apps.iphone")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                        Text("Widgets")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    private func campusLink<Destination: View>(icon: String, title: String, color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Course Card

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
        .glassCard(cornerRadius: 16)
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
                if viewModel.announcements.isEmpty && totalUnreadMessages == 0 {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash",
                        description: Text("You're all caught up!")
                    )
                }

                if totalUnreadMessages > 0 {
                    Section("Messages") {
                        Label("\(totalUnreadMessages) unread message\(totalUnreadMessages == 1 ? "" : "s")", systemImage: "envelope.fill")
                    }
                }

                if !viewModel.announcements.isEmpty {
                    Section("Announcements") {
                        ForEach(viewModel.announcements.prefix(5)) { announcement in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(announcement.title)
                                    .font(.subheadline.bold())
                                Text(announcement.content)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
