import SwiftUI

struct StudentDashboardView: View {
    let viewModel: AppViewModel
    @State private var showNotifications = false
    @State private var hapticTrigger = false

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
            ScrollView {
                if viewModel.isDataLoading && viewModel.courses.isEmpty {
                    loadingState
                } else {
                    content
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

    // MARK: - Content

    private var content: some View {
        LazyVStack(spacing: 20) {
            if let dataError = viewModel.dataError {
                errorBanner(dataError)
            }

            snapshotCard
            coursesSection
            dueSoonSection
            gradesCard
            exploreGrid
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
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
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - My Courses

    private var coursesSection: some View {
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
            } else {
                ForEach(viewModel.courses) { course in
                    NavigationLink(value: course) {
                        HStack(spacing: 14) {
                            // Course icon with color
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.courseColor(course.colorName).opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: course.iconSystemName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.courseColor(course.colorName))
                                    .symbolRenderingMode(.hierarchical)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                Text(course.teacherName)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            // Progress pill
                            Text("\(Int(course.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.courseColor(course.colorName))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.courseColor(course.colorName).opacity(0.12), in: Capsule())
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(course.title), \(course.teacherName), \(Int(course.progress * 100)) percent complete")
                    .accessibilityHint("Double tap to open course")
                }
            }
        }
        .navigationDestination(for: Course.self) { course in
            CourseDetailView(course: course, viewModel: viewModel)
        }
    }

    // MARK: - Due Soon

    private var dueSoonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Due Soon", icon: "clock.badge.exclamationmark.fill", effect: .breathe)
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
            } else {
                ForEach(viewModel.upcomingAssignments.prefix(3)) { assignment in
                    NavigationLink {
                        AssignmentsView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.orange.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.orange)
                                    .symbolRenderingMode(.hierarchical)
                            }

                            VStack(alignment: .leading, spacing: 3) {
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
                    .accessibilityLabel("\(assignment.title), \(assignment.courseName), \(assignment.points) points")
                }
            }
        }
    }

    // MARK: - Grades

    private var gradesCard: some View {
        NavigationLink {
            GradesView(viewModel: viewModel)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.green.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("My Grades")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("GPA \(String(format: "%.1f", viewModel.gpa)) · \(viewModel.overallLetterGrade)")
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
        .accessibilityLabel("My Grades, GPA \(String(format: "%.1f", viewModel.gpa)), \(viewModel.overallLetterGrade)")
        .accessibilityHint("Double tap to view all grades")
    }

    // MARK: - Explore Grid

    private var exploreGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Explore", icon: "sparkles", effect: .variableColor)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                exploreLink(icon: "calendar", title: "Calendar", color: .orange) {
                    AssignmentCalendarView(viewModel: viewModel)
                }
                exploreLink(icon: "clock.fill", title: "Schedule", color: .indigo) {
                    TimetableView(viewModel: viewModel)
                }
                exploreLink(icon: "person.badge.clock.fill", title: "Attendance", color: .teal) {
                    AttendanceHistoryView(viewModel: viewModel)
                }
                exploreLink(icon: "scope", title: "Goals", color: .green) {
                    ProgressGoalsView(viewModel: viewModel)
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
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.badge.fill")
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.wiggle, value: totalUnreadMessages)
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
