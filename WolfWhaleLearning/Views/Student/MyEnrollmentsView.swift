import SwiftUI

struct MyEnrollmentsView: View {
    let viewModel: AppViewModel
    @State private var enrollmentService = EnrollmentService()
    @State private var hapticTrigger = false
    @State private var cancelConfirmRequest: EnrollmentRequest?

    private var activeEnrollments: [EnrollmentRequest] {
        enrollmentService.myEnrollments.filter { $0.status == .enrolled }
    }

    private var pendingEnrollments: [EnrollmentRequest] {
        enrollmentService.myEnrollments.filter { $0.status == .pending }
    }

    private var waitlistedEnrollments: [EnrollmentRequest] {
        enrollmentService.myEnrollments.filter { $0.status == .waitlisted }
    }

    private var droppedOrDenied: [EnrollmentRequest] {
        enrollmentService.myEnrollments.filter { $0.status == .dropped || $0.status == .denied }
    }

    var body: some View {
        NavigationStack {
            Group {
                if enrollmentService.isLoading && enrollmentService.myEnrollments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading enrollments")
                } else {
                    List {
                        if !activeEnrollments.isEmpty {
                            Section {
                                ForEach(activeEnrollments) { request in
                                    enrollmentRow(request)
                                }
                            } header: {
                                sectionHeader(title: "Active", count: activeEnrollments.count, color: .green)
                            }
                        }

                        if !pendingEnrollments.isEmpty {
                            Section {
                                ForEach(pendingEnrollments) { request in
                                    enrollmentRow(request)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                cancelConfirmRequest = request
                                            } label: {
                                                Label("Cancel", systemImage: "xmark.circle")
                                            }
                                        }
                                }
                            } header: {
                                sectionHeader(title: "Pending Approval", count: pendingEnrollments.count, color: .orange)
                            }
                        }

                        if !waitlistedEnrollments.isEmpty {
                            Section {
                                ForEach(waitlistedEnrollments) { request in
                                    enrollmentRow(request)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                cancelConfirmRequest = request
                                            } label: {
                                                Label("Leave", systemImage: "xmark.circle")
                                            }
                                        }
                                }
                            } header: {
                                sectionHeader(title: "Waitlisted", count: waitlistedEnrollments.count, color: .yellow)
                            }
                        }

                        if !droppedOrDenied.isEmpty {
                            Section {
                                ForEach(droppedOrDenied) { request in
                                    enrollmentRow(request)
                                }
                            } header: {
                                sectionHeader(title: "Inactive", count: droppedOrDenied.count, color: .gray)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .overlay {
                        if enrollmentService.myEnrollments.isEmpty {
                            ContentUnavailableView(
                                "No Enrollments",
                                systemImage: "book.closed",
                                description: Text("You have not enrolled in any courses yet. Browse the Course Catalog to get started.")
                            )
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("My Enrollments")
            .refreshable {
                await loadEnrollments()
            }
            .task {
                await loadEnrollments()
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
                "Cancel Request",
                isPresented: .init(
                    get: { cancelConfirmRequest != nil },
                    set: { if !$0 { cancelConfirmRequest = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let request = cancelConfirmRequest {
                    Button("Cancel Request for \(request.courseName)", role: .destructive) {
                        hapticTrigger.toggle()
                        Task {
                            guard let user = viewModel.currentUser else { return }
                            _ = await enrollmentService.dropCourse(
                                enrollmentId: request.id,
                                studentId: user.id
                            )
                        }
                    }
                    Button("Keep Request", role: .cancel) { cancelConfirmRequest = nil }
                }
            } message: {
                Text("This will remove your enrollment request. You can re-enroll from the Course Catalog.")
            }
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(count)")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .clipShape(.capsule)
        }
    }

    // MARK: - Enrollment Row

    private func enrollmentRow(_ request: EnrollmentRequest) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: request.status.iconName)
                .font(.title3)
                .foregroundStyle(Theme.courseColor(request.status.color))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(request.courseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(request.status.displayName, systemImage: request.status.iconName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.courseColor(request.status.color))

                    Text(request.requestDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let note = request.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Date indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text(request.requestDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.courseName), \(request.status.displayName)")
    }

    // MARK: - Data Loading

    private func loadEnrollments() async {
        guard let user = viewModel.currentUser else { return }
        await enrollmentService.fetchMyEnrollments(studentId: user.id)
    }
}
