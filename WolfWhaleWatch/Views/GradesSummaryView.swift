import SwiftUI

/// Compact course-by-course grade summary for the Apple Watch.
///
/// Shows:
///   - A Gauge view displaying the current GPA.
///   - Each course with its letter grade and numeric percentage.
struct GradesSummaryView: View {
    let grades: [WatchGrade]

    /// Average numeric grade across all courses, used as the GPA.
    private var gpa: Double {
        guard !grades.isEmpty else { return 0 }
        return grades.reduce(0) { $0 + $1.numericGrade } / Double(grades.count)
    }

    /// Converts a numeric percentage to a 4.0-scale GPA for the gauge.
    private var gpaOn4Scale: Double {
        switch gpa {
        case 93...: return 4.0
        case 90..<93: return 3.7
        case 87..<90: return 3.3
        case 83..<87: return 3.0
        case 80..<83: return 2.7
        case 77..<80: return 2.3
        case 73..<77: return 2.0
        case 70..<73: return 1.7
        case 67..<70: return 1.3
        case 60..<67: return 1.0
        default: return 0.0
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if grades.isEmpty {
                    emptyState
                } else {
                    gradeContent
                }
            }
            .navigationTitle("Grades")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(.purple)
            Text("No Grades Yet")
                .font(.headline)
            Text("Grades appear once\nassignments are graded")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gradeContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                gpaGauge
                courseList
            }
            .padding(.horizontal, 4)
        }
    }

    private var gpaGauge: some View {
        VStack(spacing: 4) {
            Gauge(value: gpaOn4Scale, in: 0...4.0) {
                Text("GPA")
                    .font(.caption2)
            } currentValueLabel: {
                Text(String(format: "%.1f", gpaOn4Scale))
                    .font(.system(.title3, design: .rounded, weight: .bold))
            } minimumValueLabel: {
                Text("0")
                    .font(.system(size: 10))
            } maximumValueLabel: {
                Text("4.0")
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gradeGradient)
            .frame(height: 70)

            Text(String(format: "%.1f%% Average", gpa))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GPA: \(String(format: "%.1f", gpaOn4Scale)) on a 4.0 scale, \(String(format: "%.1f", gpa)) percent average")
    }

    private var courseList: some View {
        ForEach(grades) { grade in
            courseRow(grade)
        }
    }

    private func courseRow(_ grade: WatchGrade) -> some View {
        HStack(spacing: 8) {
            // Course icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(courseColor(grade.courseColor).gradient)
                    .frame(width: 28, height: 28)

                Image(systemName: grade.courseIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
            }

            // Course name
            VStack(alignment: .leading, spacing: 1) {
                Text(grade.courseName)
                    .font(.caption)
                    .lineLimit(1)

                Text(String(format: "%.1f%%", grade.numericGrade))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            // Letter grade
            Text(grade.letterGrade)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(gradeColor(grade.numericGrade))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(grade.courseName): \(grade.letterGrade), \(String(format: "%.1f", grade.numericGrade)) percent")
    }

    // MARK: - Helpers

    private var gradeGradient: Gradient {
        Gradient(colors: [.red, .orange, .yellow, .green])
    }

    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }

    private func courseColor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        case "yellow": return .yellow
        case "brown": return .brown
        default: return .blue
        }
    }
}
