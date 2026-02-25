import SwiftUI

struct CourseCatalogView: View {
    let viewModel: AppViewModel
    @State private var enrollmentService = EnrollmentService()
    @State private var searchText = ""
    @State private var selectedSubject = "All"
    @State private var showAvailableOnly = false
    @State private var hapticTrigger = false
    @State private var enrollConfirmCourse: CourseCatalogEntry?
    @State private var dropConfirmCourse: CourseCatalogEntry?
    @State private var waitlistConfirmCourse: CourseCatalogEntry?

    private let subjects = ["All", "Math", "Science", "English", "History", "Art", "Music", "Computer Science", "Physical Education"]

    /// Set of course IDs the student is already enrolled in (from AppViewModel.courses).
    private var enrolledCourseIds: Set<UUID> {
        Set(viewModel.courses.map(\.id))
    }

    private var filteredCourses: [CourseCatalogEntry] {
        var results: [CourseCatalogEntry]

        if searchText.isEmpty {
            results = enrollmentService.catalogCourses
        } else {
            results = enrollmentService.searchCatalog(query: searchText)
        }

        if selectedSubject != "All" {
            results = results.filter {
                $0.subject?.localizedStandardContains(selectedSubject) ?? false
            }
        }

        if showAvailableOnly {
            results = results.filter { $0.enrollmentStatus == nil && !$0.isFull }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            Group {
                if enrollmentService.isLoading && enrollmentService.catalogCourses.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading courses...")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading course catalog")
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            filterChips

                            LazyVStack(spacing: 14) {
                                ForEach(filteredCourses) { course in
                                    catalogCard(course)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .overlay {
                        if filteredCourses.isEmpty {
                            ContentUnavailableView(
                                "No Courses Found",
                                systemImage: "magnifyingglass",
                                description: Text("No courses match your search")
                            )
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Course Catalog")
            .searchable(text: $searchText, prompt: "Search courses")
            .refreshable {
                await loadCatalog()
            }
            .task {
                await loadCatalog()
            }
            .alert("Error", isPresented: .init(
                get: { enrollmentService.error != nil },
                set: { if !$0 { enrollmentService.error = nil } }
            )) {
                Button("OK", role: .cancel) { enrollmentService.error = nil }
            } message: {
                Text(enrollmentService.error ?? "")
            }
            .confirmationDialog(
                "Enroll in Course",
                isPresented: .init(
                    get: { enrollConfirmCourse != nil },
                    set: { if !$0 { enrollConfirmCourse = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let course = enrollConfirmCourse {
                    Button("Request to Join \(course.name)") {
                        hapticTrigger.toggle()
                        Task { await enroll(in: course) }
                    }
                    Button("Cancel", role: .cancel) { enrollConfirmCourse = nil }
                }
            } message: {
                if let course = enrollConfirmCourse {
                    Text("You will request enrollment in \(course.name) taught by \(course.teacherName). This may require teacher approval.")
                }
            }
            .confirmationDialog(
                "Drop Course",
                isPresented: .init(
                    get: { dropConfirmCourse != nil },
                    set: { if !$0 { dropConfirmCourse = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let course = dropConfirmCourse {
                    Button("Drop \(course.name)", role: .destructive) {
                        hapticTrigger.toggle()
                        Task { await dropCourse(course) }
                    }
                    Button("Cancel", role: .cancel) { dropConfirmCourse = nil }
                }
            } message: {
                Text("Are you sure you want to drop this course? You may need to re-enroll to rejoin.")
            }
            .confirmationDialog(
                "Join Waitlist",
                isPresented: .init(
                    get: { waitlistConfirmCourse != nil },
                    set: { if !$0 { waitlistConfirmCourse = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let course = waitlistConfirmCourse {
                    Button("Join Waitlist for \(course.name)") {
                        hapticTrigger.toggle()
                        Task { await joinWaitlist(for: course) }
                    }
                    Button("Cancel", role: .cancel) { waitlistConfirmCourse = nil }
                }
            } message: {
                Text("This course is full. You will be added to the waitlist and notified when a spot opens.")
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subjects, id: \.self) { subject in
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.smooth) {
                            selectedSubject = subject
                        }
                    } label: {
                        Text(subject)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedSubject == subject
                                    ? AnyShapeStyle(.indigo)
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .foregroundStyle(selectedSubject == subject ? .white : Color(.label))
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    hapticTrigger.toggle()
                    withAnimation(.smooth) {
                        showAvailableOnly.toggle()
                    }
                } label: {
                    Label("Available", systemImage: showAvailableOnly ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            showAvailableOnly
                                ? AnyShapeStyle(.green.opacity(0.8))
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundStyle(showAvailableOnly ? .white : Color(.label))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Catalog Card

    private func catalogCard(_ course: CourseCatalogEntry) -> some View {
        let accentColor = cardAccentColor(for: course)
        let isEnrolled = course.enrollmentStatus == .enrolled || enrolledCourseIds.contains(course.id)

        return VStack(alignment: .leading, spacing: 10) {
            // Header: icon, name, teacher, status badge
            HStack(alignment: .top, spacing: 12) {
                // Color accent icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: subjectIcon(for: course.subject))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)

                    Text(course.teacherName)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))

                    if let schedule = course.schedule {
                        Label(schedule, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                Spacer()

                if isEnrolled {
                    // Already enrolled: show checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce)
                        .accessibilityLabel("Enrolled")
                } else {
                    statusBadge(for: course)
                }
            }

            // Description
            Text(course.description)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(2)

            // Subject + Grade Level tags
            HStack(spacing: 6) {
                if let subject = course.subject {
                    Text(subject)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12))
                        .foregroundStyle(accentColor)
                        .clipShape(.capsule)
                }
                if let gradeLevel = course.gradeLevel {
                    Text(gradeLevel)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(.capsule)
                }
            }

            // Prerequisites info
            prerequisiteInfoView(for: course)

            // Enrolled count + capacity bar
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))

                EnrollmentCapacityBar(
                    current: course.currentEnrollment,
                    max: course.maxEnrollment
                )
            }

            // Action button (locked if prerequisites not met)
            if isEnrolled {
                Button(role: .destructive) {
                    dropConfirmCourse = course
                } label: {
                    Label("Drop Course", systemImage: "xmark.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            } else if !isEnrolled && !viewModel.hasCompletedPrerequisites(for: course.id) {
                lockedPrerequisiteButton(for: course)
            } else {
                actionButton(for: course)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.name), \(course.teacherName), \(course.currentEnrollment) of \(course.maxEnrollment) students, \(course.enrollmentStatus?.displayName ?? "Available")")
    }

    // MARK: - Status Badge

    private func statusBadge(for course: CourseCatalogEntry) -> some View {
        Group {
            if let status = course.enrollmentStatus {
                Label(status.displayName, systemImage: status.iconName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: status).opacity(0.15))
                    .foregroundStyle(statusColor(for: status))
                    .clipShape(.capsule)
            } else if course.isFull {
                Label("Full", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(.capsule)
            } else {
                Label("Available", systemImage: "checkmark.circle")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(.capsule)
            }
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(for course: CourseCatalogEntry) -> some View {
        switch course.enrollmentStatus {
        case .enrolled:
            Button(role: .destructive) {
                dropConfirmCourse = course
            } label: {
                Label("Drop Course", systemImage: "xmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

        case .pending:
            Label("Pending Approval...", systemImage: "clock.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondaryLabel).opacity(0.1), in: .rect(cornerRadius: 10))

        case .waitlisted:
            Label("On Waitlist", systemImage: "hourglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: .rect(cornerRadius: 10))

        case .dropped, .denied, nil:
            if course.isFull {
                Button {
                    waitlistConfirmCourse = course
                } label: {
                    Label("Join Waitlist", systemImage: "hourglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.orange.gradient, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    enrollConfirmCourse = course
                } label: {
                    Label("Request to Join", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.indigo.gradient, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Prerequisite Views

    /// Shows prerequisite info on a catalog card when the course has prerequisites.
    @ViewBuilder
    private func prerequisiteInfoView(for course: CourseCatalogEntry) -> some View {
        let meetsPrereqs = viewModel.hasCompletedPrerequisites(for: course.id)
        let missingNames = viewModel.missingPrerequisites(for: course.id)

        if !missingNames.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: meetsPrereqs ? "checkmark.seal.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(meetsPrereqs ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(meetsPrereqs ? "Prerequisites Met" : "Prerequisites Required")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(meetsPrereqs ? .green : .orange)

                    if !meetsPrereqs {
                        Text("Complete: \(missingNames.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(
                (meetsPrereqs ? Color.green : Color.orange).opacity(0.08),
                in: .rect(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder((meetsPrereqs ? Color.green : Color.orange).opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel(meetsPrereqs ? "Prerequisites met" : "Prerequisites required: \(missingNames.joined(separator: ", "))")
        }
    }

    /// Locked button shown when prerequisites are not met.
    private func lockedPrerequisiteButton(for course: CourseCatalogEntry) -> some View {
        let missingNames = viewModel.missingPrerequisites(for: course.id)

        return VStack(spacing: 4) {
            Label("Prerequisites Required", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.gray.gradient, in: .rect(cornerRadius: 10))

            if !missingNames.isEmpty {
                Text("Complete \(missingNames.joined(separator: " & ")) first")
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityLabel("Course locked. Complete prerequisites: \(missingNames.joined(separator: ", "))")
    }

    // MARK: - Helpers

    private func statusColor(for status: EnrollmentStatus) -> Color {
        Theme.courseColor(status.color)
    }

    /// Maps a subject string to a color accent for the card border and icon.
    private func cardAccentColor(for course: CourseCatalogEntry) -> Color {
        guard let subject = course.subject?.lowercased() else { return .indigo }
        switch subject {
        case let s where s.contains("math"): return .blue
        case let s where s.contains("science") || s.contains("bio") || s.contains("chem") || s.contains("physics"): return .green
        case let s where s.contains("english") || s.contains("literature") || s.contains("writing"): return .purple
        case let s where s.contains("history") || s.contains("social"): return .orange
        case let s where s.contains("art") || s.contains("design"): return .orange
        case let s where s.contains("music"): return .indigo
        case let s where s.contains("computer") || s.contains("tech") || s.contains("programming"): return .cyan
        case let s where s.contains("physical") || s.contains("pe") || s.contains("sport"): return .red
        default: return .indigo
        }
    }

    /// Maps a subject string to an SF Symbol icon name.
    private func subjectIcon(for subject: String?) -> String {
        guard let subject = subject?.lowercased() else { return "book.fill" }
        switch subject {
        case let s where s.contains("math"): return "function"
        case let s where s.contains("science") || s.contains("bio"): return "leaf.fill"
        case let s where s.contains("chem"): return "flask.fill"
        case let s where s.contains("physics"): return "atom"
        case let s where s.contains("english") || s.contains("literature"): return "text.book.closed.fill"
        case let s where s.contains("writing"): return "pencil.and.outline"
        case let s where s.contains("history"): return "globe.americas.fill"
        case let s where s.contains("art"): return "paintpalette.fill"
        case let s where s.contains("music"): return "music.note.list"
        case let s where s.contains("computer") || s.contains("programming"): return "desktopcomputer"
        case let s where s.contains("physical") || s.contains("pe"): return "figure.run"
        default: return "book.fill"
        }
    }

    private func loadCatalog() async {
        guard let user = viewModel.currentUser,
              let schoolId = user.schoolId,
              let tenantId = UUID(uuidString: schoolId) else { return }
        await enrollmentService.fetchCourseCatalog(tenantId: tenantId)
        await enrollmentService.enrichCatalogWithStudentStatus(studentId: user.id)
    }

    private func enroll(in course: CourseCatalogEntry) async {
        guard let user = viewModel.currentUser else { return }
        _ = await enrollmentService.requestEnrollment(courseId: course.id, studentId: user.id)
    }

    private func dropCourse(_ course: CourseCatalogEntry) async {
        guard let user = viewModel.currentUser else { return }
        if let enrollment = enrollmentService.myEnrollments.first(where: { $0.courseId == course.id }) {
            _ = await enrollmentService.dropCourse(enrollmentId: enrollment.id, studentId: user.id)
        } else {
            await enrollmentService.fetchMyEnrollments(studentId: user.id)
            if let enrollment = enrollmentService.myEnrollments.first(where: { $0.courseId == course.id }) {
                _ = await enrollmentService.dropCourse(enrollmentId: enrollment.id, studentId: user.id)
            }
        }
    }

    private func joinWaitlist(for course: CourseCatalogEntry) async {
        guard let user = viewModel.currentUser else { return }
        _ = await enrollmentService.joinWaitlist(courseId: course.id, studentId: user.id)
    }
}
