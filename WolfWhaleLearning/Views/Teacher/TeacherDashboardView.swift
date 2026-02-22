import SwiftUI

struct TeacherDashboardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var liveActivityService: LiveActivityService?
    @State private var showCreateCourse = false
    @State private var showCreateAssignment = false
    @State private var showCreateAnnouncement = false
    @State private var showAttendancePicker = false
    @State private var showAttendanceReport = false
    @State private var showBulkGrading = false
    @State private var showGradeExport = false
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isDataLoading && viewModel.courses.isEmpty {
                    VStack(spacing: 20) {
                        ShimmerLoadingView(rowCount: 4)
                        LoadingStateView(
                            icon: "person.crop.rectangle.stack.fill",
                            title: "Loading Dashboard",
                            message: "Fetching your courses, submissions, and announcements..."
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                } else {
                    GlassEffectContainer {
                        LazyVStack(spacing: 16) {
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
                            overviewCards
                            enrollmentRequestsBanner
                            liveActivityBanner
                            quickActions
                            recentActivity
                            announcementsSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .task {
                if liveActivityService == nil {
                    liveActivityService = LiveActivityService()
                }
                await viewModel.loadEnrollmentRequests()
            }
            .refreshable {
                await viewModel.loadData()
                await viewModel.loadEnrollmentRequests()
            }
        }
    }

    @ViewBuilder
    private var enrollmentRequestsBanner: some View {
        if viewModel.pendingEnrollmentCount > 0 {
            NavigationLink {
                EnrollmentRequestsView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "person.badge.clock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enrollment Requests")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        Text("\(viewModel.pendingEnrollmentCount) pending approval\(viewModel.pendingEnrollmentCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    Text("\(viewModel.pendingEnrollmentCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(.red, in: Circle())

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
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
            .accessibilityLabel("Enrollment Requests: \(viewModel.pendingEnrollmentCount) pending")
            .accessibilityHint("Double tap to review enrollment requests")
        }
    }

    @ViewBuilder
    private var liveActivityBanner: some View {
        if let firstCourse = viewModel.courses.first, let liveActivityService {
            LiveActivityBanner(
                liveActivityService: liveActivityService,
                courseName: firstCourse.title,
                teacherName: viewModel.currentUser?.fullName ?? "Teacher"
            )
        }
    }

    private var overviewCards: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            dashCard(icon: "book.fill", value: "\(viewModel.courses.count)", label: "Courses", color: .pink)
            dashCard(icon: "person.3.fill", value: "\(viewModel.courses.reduce(0) { $0 + $1.enrolledStudentCount })", label: "Students", color: .blue)
            dashCard(icon: "doc.text.fill", value: "\(viewModel.pendingGradingCount)", label: "Needs Grading", color: .orange)
            dashCard(icon: "chart.bar.fill", value: String(format: "%.1f%%", viewModel.gpa), label: "Avg Grade", color: .green)
        }
    }

    private func dashCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                quickActionButton(icon: "plus.circle.fill", label: "New Course", color: .pink) {
                    showCreateCourse = true
                }
                quickActionButton(icon: "megaphone.fill", label: "Announce", color: .orange) {
                    showCreateAnnouncement = true
                }
                quickActionButton(icon: "checklist", label: "Attendance", color: .green) {
                    showAttendancePicker = true
                }
            }

            HStack(spacing: 12) {
                quickActionButton(icon: "chart.bar.doc.horizontal.fill", label: "Report", color: .teal) {
                    showAttendanceReport = true
                }
                quickActionButton(icon: "pencil.and.list.clipboard", label: "Bulk Grade", color: .purple) {
                    showBulkGrading = true
                }
                quickActionButton(icon: "arrow.down.doc.fill", label: "Export", color: .indigo) {
                    showGradeExport = true
                }
            }
        }
        .sheet(isPresented: $showBulkGrading) {
            BulkGradingView(viewModel: viewModel)
        }
        .sheet(isPresented: $showGradeExport) {
            GradeExportView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCreateCourse) {
            EnhancedCourseCreationView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCreateAnnouncement) {
            CreateAnnouncementSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAttendancePicker) {
            AttendanceCoursePickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAttendanceReport) {
            NavigationStack {
                AttendanceAnalyticsView(viewModel: viewModel, isAdmin: false)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showAttendanceReport = false
                            }
                        }
                    }
            }
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(label)")
        .accessibilityHint("Double tap to \(label.lowercased())")
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Submissions")
                .font(.headline)

            if viewModel.assignments.filter(\.isSubmitted).isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No submissions yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(viewModel.assignments.filter(\.isSubmitted).prefix(3)) { assignment in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.blue.gradient)
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
                        if assignment.grade != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Grade")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(assignment.title) for \(assignment.courseName), \(assignment.grade != nil ? "graded" : "needs grading")")
                }
            }
        }
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Announcements")
                .font(.headline)

            if viewModel.announcements.isEmpty {
                HStack {
                    Image(systemName: "megaphone")
                        .foregroundStyle(.secondary)
                    Text("No announcements")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(viewModel.announcements.prefix(2)) { announcement in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if announcement.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(announcement.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text(announcement.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        Text(announcement.content)
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct CreateCourseSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false
    @State private var title = ""
    @State private var description = ""
    @State private var colorName = "blue"
    @State private var isCreating = false
    @State private var createError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Course Details") {
                    TextField("Course Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Settings") {
                    Picker("Color", selection: $colorName) {
                        Text("Blue").tag("blue")
                        Text("Green").tag("green")
                        Text("Orange").tag("orange")
                        Text("Purple").tag("purple")
                    }
                }
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        hapticTrigger.toggle()
                        isCreating = true
                        createError = nil
                        Task {
                            do {
                                try await viewModel.createCourse(title: title, description: description, colorName: colorName)
                                isCreating = false
                                dismiss()
                            } catch {
                                createError = "Failed to create course. Please try again."
                                isCreating = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(createError ?? "")
            }
        }
    }
}

struct CreateAnnouncementSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false
    @State private var title = ""
    @State private var content = ""
    @State private var isPinned = false
    @State private var isCreating = false
    @State private var createError: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Content", text: $content, axis: .vertical)
                    .lineLimit(4...)
                Toggle("Pin to top", isOn: $isPinned)
            }
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        hapticTrigger.toggle()
                        isCreating = true
                        createError = nil
                        Task {
                            do {
                                try await viewModel.createAnnouncement(title: title, content: content, isPinned: isPinned)
                                isCreating = false
                                dismiss()
                            } catch {
                                createError = "Failed to post announcement. Please try again."
                                isCreating = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(createError ?? "")
            }
        }
    }
}

struct AttendanceCoursePickerSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.courses.isEmpty {
                    ContentUnavailableView("No Courses", systemImage: "book.fill", description: Text("Create a course first to take attendance"))
                } else {
                    List(viewModel.courses) { course in
                        NavigationLink(value: course) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.courseColor(course.colorName).gradient)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: course.iconSystemName)
                                            .font(.callout)
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.title)
                                        .font(.subheadline.bold())
                                    Text("\(course.enrolledStudentCount) students")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .navigationDestination(for: Course.self) { course in
                TakeAttendanceView(viewModel: viewModel, course: course)
            }
        }
    }
}
