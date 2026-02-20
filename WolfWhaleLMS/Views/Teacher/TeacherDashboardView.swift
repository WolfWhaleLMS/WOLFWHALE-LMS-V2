import SwiftUI

struct TeacherDashboardView: View {
    let viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    overviewCards
                    quickActions
                    recentActivity
                    announcementsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
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
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                quickActionButton(icon: "plus.circle.fill", label: "New Course", color: .pink) {}
                quickActionButton(icon: "doc.badge.plus", label: "Assignment", color: .blue) {}
                quickActionButton(icon: "questionmark.circle.fill", label: "Quiz", color: .purple) {}
                quickActionButton(icon: "megaphone.fill", label: "Announce", color: .orange) {}
            }
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Submissions")
                .font(.headline)

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
                            .lineLimit(1)
                        Text(assignment.courseName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if assignment.grade != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Grade")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Announcements")
                .font(.headline)

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
