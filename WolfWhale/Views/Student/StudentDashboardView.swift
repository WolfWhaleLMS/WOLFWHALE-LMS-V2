import SwiftUI

struct StudentDashboardView: View {
    let viewModel: AppViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showNotifications = false
    @State private var hapticTrigger = false
    @State private var selectedCourse: Course?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var totalUnreadMessages: Int { viewModel.totalUnreadMessages }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isDataLoading && viewModel.courses.isEmpty {
                    ScrollView { loadingState }
                } else if sizeClass == .regular {
                    iPadContent
                } else {
                    ScrollView { content }
                }
            }
            .refreshable { await viewModel.loadData() }
            .background { HolographicBackground() }
            .navigationTitle("\(greeting), \(viewModel.currentUser?.firstName ?? "Student")")
            .toolbar { notificationButton }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - iPad Content (Two-Column)

    private var iPadContent: some View {
        HStack(spacing: 0) {
            // Left column: snapshot + courses list + quick links
            ScrollView {
                VStack(spacing: 20) {
                    if let dataError = viewModel.dataError {
                        errorBanner(dataError)
                    }

                    snapshotCard

                    // Courses as a vertical list for iPad sidebar
                    iPadCoursesList

                    quickLinksGrid
                }
                .padding()
            }
            .frame(width: 360)

            Divider()

            // Right column: selected course detail or due-soon assignments
            ScrollView {
                VStack(spacing: 20) {
                    if let course = selectedCourse {
                        iPadCourseDetail(course)
                    } else {
                        // Show due-soon assignments as default right-panel content
                        iPadDueSoonList

                        iPadQuickLinksExpanded
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationDestination(for: Course.self) { course in
            CourseDetailView(course: course, viewModel: viewModel)
        }
    }

    // MARK: - iPad Sidebar Courses List

    private var iPadCoursesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("My Courses", icon: "graduationcap.fill", effect: .wiggle)

            if viewModel.courses.isEmpty {
                NavigationLink {
                    CourseCatalogView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                            .symbolRenderingMode(.hierarchical)
                        Text("Browse Courses")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(viewModel.courses) { course in
                    Button {
                        withAnimation(.smooth) {
                            selectedCourse = selectedCourse?.id == course.id ? nil : course
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.courseColor(course.colorName).opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: course.iconSystemName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.courseColor(course.colorName))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                Text(course.teacherName)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(Int(course.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.courseColor(course.colorName))
                        }
                        .padding(12)
                        .background(
                            selectedCourse?.id == course.id
                                ? Theme.courseColor(course.colorName).opacity(0.1)
                                : Color.clear
                        )
                        .glassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(course.title), \(course.teacherName), \(Int(course.progress * 100)) percent complete")
                }
            }
        }
    }

    // MARK: - iPad Course Detail Panel

    private func iPadCourseDetail(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Course header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.courseColor(course.colorName).opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: course.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(Theme.courseColor(course.colorName))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.title3.bold())
                    Text(course.teacherName)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                NavigationLink(value: course) {
                    Text("Open")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.courseColor(course.colorName), in: Capsule())
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(course.progress * 100))%")
                        .font(.headline)
                        .foregroundStyle(Theme.courseColor(course.colorName))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.courseColor(course.colorName).opacity(0.15))
                        Capsule()
                            .fill(Theme.courseColor(course.colorName))
                            .frame(width: geo.size.width * min(course.progress, 1.0))
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Assignments for this course
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Assignments", icon: "doc.text.fill", effect: .wiggle)

                let courseAssignments = viewModel.upcomingAssignments.filter { $0.courseId == course.id }
                if courseAssignments.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("No upcoming assignments for this course")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard(cornerRadius: 14)
                } else {
                    ForEach(courseAssignments) { assignment in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(assignment.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                Text(assignment.dueDate, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Spacer()

                            Text("\(assignment.points) pts")
                                .font(.caption.bold())
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                }
            }
        }
    }

    // MARK: - iPad Due Soon (Right Panel Default)

    private var iPadDueSoonList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Due Soon", icon: "clock.badge.exclamationmark.fill", effect: .wiggle)
                Spacer()
                NavigationLink {
                    AssignmentsView(viewModel: viewModel)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            if viewModel.upcomingAssignments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                    Text("All caught up -- nothing due!")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 14)
            } else {
                ForEach(viewModel.upcomingAssignments.prefix(8)) { assignment in
                    NavigationLink {
                        AssignmentsView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(assignment.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                Text(assignment.courseName)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(assignment.dueDate, style: .relative)
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                Text("\(assignment.points) pts")
                                    .font(.caption2)
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - iPad Expanded Quick Links (Right Panel)

    private var iPadQuickLinksExpanded: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Quick Links", icon: "sparkles", effect: .wiggle)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                exploreLink(icon: "chart.bar.doc.horizontal.fill", title: "Grades", color: .green) {
                    GradesView(viewModel: viewModel)
                }
                exploreLink(icon: "calendar", title: "Calendar", color: .orange) {
                    AssignmentCalendarView(viewModel: viewModel)
                }
                exploreLink(icon: "clock.fill", title: "Schedule", color: .indigo) {
                    TimetableView(viewModel: viewModel)
                }
                exploreLink(icon: "person.badge.clock.fill", title: "Attendance", color: .teal) {
                    AttendanceHistoryView(viewModel: viewModel)
                }
                exploreLink(icon: "books.vertical.fill", title: "Catalog", color: .purple) {
                    CourseCatalogView(viewModel: viewModel)
                }
                exploreLink(icon: "map.fill", title: "Campus", color: .blue) {
                    CampusMapView()
                }
                exploreLink(icon: "sparkles", title: "AI Tutor", color: .purple) {
                    AIAssistantView()
                }
            }
        }
    }

    // MARK: - Content (iPhone)

    private var content: some View {
        VStack(spacing: 20) {
            if let dataError = viewModel.dataError {
                errorBanner(dataError)
                    .padding(.horizontal)
            }

            snapshotCard
                .padding(.horizontal)

            coursesCarousel

            dueSoonCarousel

            quickLinksGrid
                .padding(.horizontal)
        }
        .padding(.bottom, 24)
        .navigationDestination(for: Course.self) { course in
            CourseDetailView(course: course, viewModel: viewModel)
        }
    }

    // MARK: - Today Snapshot

    private var snapshotCard: some View {
        HStack(spacing: 0) {
            snapshotStat(
                icon: "book.fill",
                value: "\(viewModel.courses.count)",
                label: "Courses",
                color: .indigo
            )
            Divider().frame(height: 36)
            snapshotStat(
                icon: "checklist",
                value: "\(viewModel.upcomingAssignments.count)",
                label: "Due Soon",
                color: .orange
            )
            Divider().frame(height: 36)
            snapshotStat(
                icon: "chart.bar.fill",
                value: String(format: "%.1f", viewModel.gpa),
                label: "GPA",
                color: .green
            )
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.courses.count) courses, \(viewModel.upcomingAssignments.count) assignments due soon, GPA \(String(format: "%.1f", viewModel.gpa))")
    }

    private func snapshotStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Courses Carousel

    private var coursesCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("My Courses", icon: "graduationcap.fill", effect: .wiggle)
                .padding(.horizontal)

            if viewModel.courses.isEmpty {
                NavigationLink {
                    CourseCatalogView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.pulse, options: .repeat(.periodic(delay: 2)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse Courses")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                            Text("Find and enroll in your first course")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.courses) { course in
                            NavigationLink(value: course) {
                                courseCard(course)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(course.title), \(course.teacherName), \(Int(course.progress * 100)) percent complete")
                            .accessibilityHint("Double tap to open course")
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func courseCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon with color background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.courseColor(course.colorName).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: course.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.courseColor(course.colorName))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(course.teacherName)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(course.progress * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.courseColor(course.colorName))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.courseColor(course.colorName).opacity(0.15))
                        Capsule()
                            .fill(Theme.courseColor(course.colorName))
                            .frame(width: geo.size.width * min(course.progress, 1.0))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .frame(width: 160, height: 170)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Due Soon Carousel

    private var dueSoonCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Due Soon", icon: "clock.badge.exclamationmark.fill", effect: .wiggle)
                Spacer()
                NavigationLink {
                    AssignmentsView(viewModel: viewModel)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHint("Double tap to view all assignments")
            }
            .padding(.horizontal)

            if viewModel.upcomingAssignments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.bounce, options: .repeat(.periodic(delay: 3)))
                    Text("All caught up — nothing due!")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard(cornerRadius: 14)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.upcomingAssignments.prefix(5)) { assignment in
                            NavigationLink {
                                AssignmentsView(viewModel: viewModel)
                            } label: {
                                assignmentCard(assignment)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(assignment.title), \(assignment.courseName), \(assignment.points) points")
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func assignmentCard(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))

            Text(assignment.title)
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(assignment.courseName)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(1)

            Spacer()

            HStack {
                Text(assignment.dueDate, style: .relative)
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(assignment.points) pts")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .frame(width: 150, height: 155)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Quick Links Grid

    private var quickLinksGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Quick Links", icon: "sparkles", effect: .wiggle)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                exploreLink(icon: "chart.bar.doc.horizontal.fill", title: "Grades", color: .green) {
                    GradesView(viewModel: viewModel)
                }
                exploreLink(icon: "calendar", title: "Calendar", color: .orange) {
                    AssignmentCalendarView(viewModel: viewModel)
                }
                exploreLink(icon: "clock.fill", title: "Schedule", color: .indigo) {
                    TimetableView(viewModel: viewModel)
                }
                exploreLink(icon: "person.badge.clock.fill", title: "Attendance", color: .teal) {
                    AttendanceHistoryView(viewModel: viewModel)
                }
                exploreLink(icon: "books.vertical.fill", title: "Catalog", color: .purple) {
                    CourseCatalogView(viewModel: viewModel)
                }
                exploreLink(icon: "map.fill", title: "Campus", color: .blue) {
                    CampusMapView()
                }
            }
        }
    }

    private func exploreLink<D: View>(icon: String, title: String, color: Color, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
                    .frame(height: 24)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to open \(title)")
    }

    // MARK: - Helpers

    private enum SectionEffect {
        case wiggle, breathe, variableColor, none
    }

    private func sectionHeader(_ title: String, icon: String, effect: SectionEffect = .none) -> some View {
        Label {
            Text(title)
        } icon: {
            Group {
                switch effect {
                case .wiggle:
                    Image(systemName: icon)
                        .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
                case .breathe:
                    Image(systemName: icon)
                        .symbolEffect(.breathe, options: .repeat(.periodic(delay: 5)))
                case .variableColor:
                    Image(systemName: icon)
                        .symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: 3)))
                case .none:
                    Image(systemName: icon)
                }
            }
        }
        .font(.headline)
        .symbolRenderingMode(.hierarchical)
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            ShimmerLoadingView(rowCount: 4)
            LoadingStateView(
                icon: "graduationcap.fill",
                title: "Loading Dashboard",
                message: "Fetching your courses and assignments..."
            )
        }
        .padding(.horizontal)
        .padding(.top, 40)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2)))
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
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notificationButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                hapticTrigger.toggle()
                showNotifications = true
            } label: {
                Image(systemName: totalUnreadMessages > 0 ? "bell.badge.fill" : "bell.fill")
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.wiggle, value: totalUnreadMessages)
                    .symbolEffect(.bounce, value: totalUnreadMessages)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel(totalUnreadMessages > 0 ? "\(totalUnreadMessages) notifications" : "Notifications")
        }
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.announcements.isEmpty && viewModel.totalUnreadMessages == 0 {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash.fill",
                        description: Text("You're all caught up!")
                    )
                }

                if viewModel.totalUnreadMessages > 0 {
                    Section("Messages") {
                        Label {
                            Text("\(viewModel.totalUnreadMessages) unread message\(viewModel.totalUnreadMessages == 1 ? "" : "s")")
                        } icon: {
                            Image(systemName: "envelope.badge.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
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
