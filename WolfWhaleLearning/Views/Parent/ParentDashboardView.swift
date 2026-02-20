import SwiftUI

struct ParentDashboardView: View {
    let viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading children data")
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(viewModel.children) { child in
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
                        if viewModel.children.isEmpty {
                            ContentUnavailableView("No Children Linked", systemImage: "person.2", description: Text("Linked children will appear here"))
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Children")
            .refreshable {
                viewModel.refreshData()
            }
        }
    }

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
                    Text(child.grade)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                parentStat(label: "GPA", value: String(format: "%.1f", child.gpa), color: Theme.gradeColor(child.gpa / 4.0 * 100))
                // TODO: attendanceRate is computed from real attendance records via DataService.fetchChildren.
                // If no attendance records exist for this child, the rate will be 0.0.
                // In demo/mock mode, this value comes from MockDataService.sampleChildren() and may be hardcoded.
                parentStat(label: "Attendance", value: "\(Int(child.attendanceRate * 100))%", color: child.attendanceRate > 0.9 ? .green : .orange)
                parentStat(label: "Courses", value: "\(child.courses.count)", color: .blue)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Course Grades")
                    .font(.subheadline.bold())

                ForEach(child.courses) { grade in
                    HStack(spacing: 12) {
                        Image(systemName: grade.courseIcon)
                            .foregroundStyle(Theme.courseColor(grade.courseColor))
                            .frame(width: 24)
                        Text(grade.courseName)
                            .font(.subheadline)
                        Spacer()
                        Text(grade.letterGrade)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.gradeColor(grade.numericGrade))
                        Text(String(format: "%.0f%%", grade.numericGrade))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !child.recentAssignments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upcoming Work")
                        .font(.subheadline.bold())

                    ForEach(child.recentAssignments) { assignment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(assignment.courseName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
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
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("School Announcements")
                .font(.headline)

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
                }
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }
}
