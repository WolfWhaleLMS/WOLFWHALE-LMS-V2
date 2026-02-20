import SwiftUI

struct AdminDashboardView: View {
    let viewModel: AppViewModel

    private var metrics: SchoolMetrics {
        viewModel.schoolMetrics ?? SchoolMetrics(totalStudents: 0, totalTeachers: 0, totalCourses: 0, averageAttendance: 0, averageGPA: 0, activeUsers: 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    metricsGrid
                    attendanceCard
                    recentSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("School Overview")
            .refreshable {
                viewModel.refreshData()
            }
        }
    }

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            metricCard(icon: "person.fill", value: "\(metrics.totalStudents)", label: "Students", color: .purple)
            metricCard(icon: "person.crop.rectangle.fill", value: "\(metrics.totalTeachers)", label: "Teachers", color: .pink)
            metricCard(icon: "book.fill", value: "\(metrics.totalCourses)", label: "Courses", color: .blue)
            metricCard(icon: "checkmark.circle.fill", value: "\(Int(metrics.averageAttendance * 100))%", label: "Attendance", color: .green)
            metricCard(icon: "chart.bar.fill", value: String(format: "%.1f", metrics.averageGPA), label: "Avg GPA", color: .orange)
            metricCard(icon: "person.wave.2.fill", value: "\(metrics.activeUsers)", label: "Active", color: .teal)
        }
    }

    private func metricCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    private var attendanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance This Week")
                .font(.headline)

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { day in
                    VStack(spacing: 6) {
                        let rate = metrics.averageAttendance > 0 ? metrics.averageAttendance + Double.random(in: -0.03...0.03) : 0.94
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 80)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rate > 0.93 ? .green : .orange)
                                .frame(height: 80 * min(rate, 1.0))
                        }
                        .frame(maxWidth: .infinity)
                        Text(["Mon", "Tue", "Wed", "Thu", "Fri"][day])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Announcements")
                .font(.headline)

            if viewModel.announcements.isEmpty {
                HStack {
                    Image(systemName: "megaphone")
                        .foregroundStyle(.secondary)
                    Text("No announcements yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(viewModel.announcements) { announcement in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(announcement.isPinned ? .orange : .blue)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(announcement.title)
                                .font(.subheadline.bold())
                            Text(announcement.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }

            Button(role: .destructive) {
                viewModel.logout()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }
}
