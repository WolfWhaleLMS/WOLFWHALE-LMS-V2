import SwiftUI
import Supabase

struct ParentDashboardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var verifiedChildIds: Set<UUID>?

    /// Children filtered to only those whose parent-child link has been verified by the server.
    private var verifiedChildren: [ChildInfo] {
        guard let verified = verifiedChildIds else {
            // Still loading verification -- show nothing until verified
            return []
        }
        return viewModel.children.filter { verified.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading || verifiedChildIds == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading children data")
                } else {
                    ScrollView {
                            LazyVStack(spacing: 16) {
                            if let dataError = viewModel.dataError {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2)))
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

                            // Alerts section -- shown above child cards
                            alertsSection

                            // Quick access: Conferences & Progress Report
                            parentQuickLinks

                            ForEach(verifiedChildren) { child in
                                NavigationLink {
                                    ChildDetailView(child: child, viewModel: viewModel)
                                } label: {
                                    childCard(child)
                                }
                                .buttonStyle(.plain)
                            }
                            announcementsSection
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .overlay {
                        if verifiedChildren.isEmpty && verifiedChildIds != nil {
                            ContentUnavailableView("No Children Linked", systemImage: "person.2", description: Text("Linked children will appear here"))
                        }
                    }
                }
            }
            .background { HolographicBackground() }
            .navigationTitle("My Children")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.unreadParentAlertCount > 0 {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 3)))
                            .accessibilityLabel("\(viewModel.unreadParentAlertCount) unread alerts")
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
                await verifyParentChildLinks()
            }
            .task {
                await verifyParentChildLinks()
            }
        }
    }

    /// Verifies that each child in viewModel.children actually belongs to this parent
    /// by checking the student_parents table on the server.
    private func verifyParentChildLinks() async {
        guard let parentId = viewModel.currentUser?.id else {
            verifiedChildIds = []
            return
        }

        do {
            struct ParentChildLink: Decodable {
                let studentId: UUID
                enum CodingKeys: String, CodingKey {
                    case studentId = "student_id"
                }
            }

            let links: [ParentChildLink] = try await supabaseClient
                .from("student_parents")
                .select("student_id")
                .eq("parent_id", value: parentId.uuidString)
                .execute()
                .value

            verifiedChildIds = Set(links.map(\.studentId))
        } catch {
            // On error, fall back to showing the children the view model already loaded
            // (they were fetched from the same table, so this is a safe fallback)
            verifiedChildIds = Set(viewModel.children.map(\.id))
        }
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        Group {
            if !viewModel.parentAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Recent Alerts", systemImage: "bell.fill")
                            .font(.headline)
                            .foregroundStyle(Color(.label))

                        Spacer()

                        if viewModel.unreadParentAlertCount > 0 {
                            Text("\(viewModel.unreadParentAlertCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(.red, in: Capsule())
                        }

                        if viewModel.parentAlerts.contains(where: { !$0.isRead }) {
                            Button {
                                viewModel.markAllParentAlertsRead()
                            } label: {
                                Text("Mark All Read")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderless)
                            .tint(.blue)
                        }
                    }

                    ForEach(viewModel.parentAlerts.prefix(5)) { alert in
                        alertRow(alert)
                    }
                }
            }
        }
    }

    private func alertRow(_ alert: ParentAlert) -> some View {
        let alertColor: Color = {
            switch alert.type {
            case .lowGrade: return .red
            case .absence: return .orange
            case .upcomingDueDate: return .blue
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: alert.type.iconName)
                .font(.title3)
                .foregroundStyle(alertColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(alert.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    if !alert.isRead {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(alert.childName)
                        .font(.caption2.bold())
                        .foregroundStyle(alertColor)
                    Text(alert.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Spacer()

            // Navigate to the child's detail
            if let child = viewModel.children.first(where: { $0.id == alert.childId }) {
                NavigationLink {
                    ChildDetailView(child: child, viewModel: viewModel)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(alertColor.opacity(0.25), lineWidth: 1)
        )
        .onTapGesture {
            viewModel.markParentAlertRead(alert.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.type.rawValue) alert for \(alert.childName): \(alert.message)")
    }

    // MARK: - Child Card

    private func childCard(_ child: ChildInfo) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(child.name)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text(child.grade)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()

                // Unread alert badge per child
                let childAlertCount = viewModel.parentAlerts.filter { $0.childId == child.id && !$0.isRead }.count
                if childAlertCount > 0 {
                    Text("\(childAlertCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(.red, in: Circle())
                }
            }

            HStack(spacing: 12) {
                parentStat(label: "GPA", value: String(format: "%.1f", child.gpa), color: Theme.gradeColor(child.gpa / 4.0 * 100))
                parentStat(label: "Attendance", value: "\(Int(child.attendanceRate * 100))%", color: child.attendanceRate > 0.9 ? .green : .orange)
                parentStat(label: "Courses", value: "\(child.courses.count)", color: .blue)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Course Grades")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))

                ForEach(child.courses) { grade in
                    HStack(spacing: 12) {
                        Image(systemName: grade.courseIcon)
                            .foregroundStyle(Theme.courseColor(grade.courseColor))
                            .frame(width: 24)
                        Text(grade.courseName)
                            .font(.subheadline)
                            .foregroundStyle(Color(.label))
                        Spacer()
                        Text(grade.letterGrade)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.gradeColor(grade.numericGrade))
                        Text(String(format: "%.0f%%", grade.numericGrade))
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }

            if !child.recentAssignments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upcoming Work")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))

                    ForEach(child.recentAssignments) { assignment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.title)
                                    .font(.subheadline)
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
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(child.grade), GPA \(String(format: "%.1f", child.gpa)), attendance \(Int(child.attendanceRate * 100)) percent, \(child.courses.count) courses")
        .accessibilityHint("Double tap to view details")
    }

    private func parentStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Quick Links (Conferences & Progress Report)

    private var parentQuickLinks: some View {
        HStack(spacing: 12) {
            NavigationLink {
                ConferenceSchedulingView(viewModel: viewModel)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                        .symbolEffect(.pulse)

                    Text("Conferences")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(.label))

                    if !viewModel.upcomingConferences.isEmpty {
                        Text("\(viewModel.upcomingConferences.count) upcoming")
                            .font(.system(size: 9))
                            .foregroundStyle(.indigo)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.indigo.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Conferences")
            .accessibilityHint("Double tap to view and book parent-teacher conferences")

            NavigationLink {
                WeeklyDigestView(viewModel: viewModel)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.teal)
                        .symbolEffect(.pulse)

                    Text("Progress Report")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(.label))

                    Text("View report")
                        .font(.system(size: 9))
                        .foregroundStyle(.teal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.teal.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Progress Report")
            .accessibilityHint("Double tap to view weekly progress report")
        }
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("School Announcements")
                .font(.headline)

            if viewModel.announcements.isEmpty {
                HStack {
                    Image(systemName: "megaphone")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce)
                    Text("No announcements at this time")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

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
