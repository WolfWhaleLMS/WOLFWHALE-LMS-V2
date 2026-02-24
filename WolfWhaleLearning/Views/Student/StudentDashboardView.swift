import SwiftUI

struct StudentDashboardView: View {
    let viewModel: AppViewModel
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

    private var totalUnreadMessages: Int {
        viewModel.totalUnreadMessages
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isDataLoading && viewModel.courses.isEmpty {
                    VStack(spacing: 20) {
                        ShimmerLoadingView(rowCount: 3)
                        LoadingStateView(
                            icon: "graduationcap.fill",
                            title: "Loading Dashboard",
                            message: "Fetching your courses and assignments..."
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        if let dataError = viewModel.dataError {
                            errorBanner(dataError)
                        }
                        coursesSection
                        upcomingSection
                        linksSection
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
    }

    // MARK: - Courses

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Courses")
                .font(.headline)

            if viewModel.courses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No courses yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard(cornerRadius: 16)
            } else {
                ForEach(viewModel.courses) { course in
                    NavigationLink(value: course) {
                        HStack(spacing: 14) {
                            Image(systemName: course.iconSystemName)
                                .font(.title3)
                                .foregroundStyle(Theme.courseColor(course.colorName))
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                Text(course.teacherName)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            Text("\(Int(course.progress * 100))%")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.courseColor(course.colorName))
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Upcoming Deadlines

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", value: "assignments")
                    .font(.subheadline)
            }

            if viewModel.upcomingAssignments.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassCard(cornerRadius: 12)
            } else {
                ForEach(viewModel.upcomingAssignments.prefix(3)) { assignment in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.orange.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption)
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
                        Text(assignment.dueDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                }
            }
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More")
                .font(.headline)

            linkRow(icon: "calendar.badge.clock", title: "Calendar", color: .orange) {
                AssignmentCalendarView(viewModel: viewModel)
            }
            linkRow(icon: "target", title: "Goals", color: .green) {
                ProgressGoalsView(viewModel: viewModel)
            }
            linkRow(icon: "calendar.day.timeline.leading", title: "Schedule", color: .indigo) {
                TimetableView(viewModel: viewModel)
            }
            linkRow(icon: "checkmark.shield.fill", title: "Attendance", color: .teal) {
                AttendanceHistoryView(viewModel: viewModel)
            }
            linkRow(icon: "book.and.wrench.fill", title: "Browse Courses", color: .purple) {
                CourseCatalogView(viewModel: viewModel)
            }
            linkRow(icon: "map.fill", title: "Campus Map", color: .blue) {
                CampusMapView()
            }

            // Radio & Widgets (sheets)
            Button {
                hapticTrigger.toggle()
                showRadio = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "radio.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    Text("Radio")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassCard(cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Button {
                hapticTrigger.toggle()
                showWidgetGallery = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .foregroundStyle(.cyan)
                        .frame(width: 28)
                    Text("Widgets")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassCard(cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    private func linkRow<Destination: View>(icon: String, title: String, color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Course Card (unused, kept for reference)

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
