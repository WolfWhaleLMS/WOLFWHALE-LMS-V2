import SwiftUI

/// Dashboard analytics widget showing grades, attendance, and activity summary.
struct DashboardAnalyticsWidget: View {
    let gpa: Double
    let attendanceRate: Double
    let assignmentsCompleted: Int
    let totalAssignments: Int
    let coursesEnrolled: Int
    let currentStreak: Int

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("My Dashboard")
                    .font(.headline)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
            }

            // GPA ring
            HStack(spacing: 16) {
                // GPA circular progress
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: min(gpa / 4.0, 1.0))
                        .stroke(
                            LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", gpa))
                            .font(.system(.body, design: .rounded, weight: .bold))
                        Text("GPA")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }

                // Stats grid
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        statItem(icon: "checkmark.circle.fill", value: "\(Int(attendanceRate * 100))%", label: "Attend.", color: .green)
                        statItem(icon: "doc.fill", value: "\(assignmentsCompleted)/\(totalAssignments)", label: "Done", color: .blue)
                    }
                    HStack(spacing: 12) {
                        statItem(icon: "book.fill", value: "\(coursesEnrolled)", label: "Courses", color: .purple)
                        statItem(icon: "flame.fill", value: "\(currentStreak)d", label: "Streak", color: .orange)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular.tint(.purple), in: RoundedRectangle(cornerRadius: 20))
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.bold())
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 60, alignment: .leading)
    }
}
