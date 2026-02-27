import SwiftUI
import Charts

// MARK: - Sample Data Models

private struct DailyActiveUsers: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct DailySubmissions: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct DailyAttendance: Identifiable {
    let id = UUID()
    let date: Date
    let percentage: Double
}

// MARK: - Analytics Dashboard View

struct AnalyticsDashboardView: View {
    let viewModel: AppViewModel

    @State private var selectedPeriod: TimePeriod = .thirtyDays
    @State private var activeUsersData: [DailyActiveUsers] = []
    @State private var submissionsData: [DailySubmissions] = []
    @State private var attendanceData: [DailyAttendance] = []
    @State private var totalMessages: Int = 0
    @State private var assignmentsCreated: Int = 0
    @State private var quizAttempts: Int = 0
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    enum TimePeriod: String, CaseIterable, Identifiable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
        case ninetyDays = "90 Days"

        var id: String { rawValue }

        var dayCount: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading analytics...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 20) {
                        timePeriodPicker
                        activeUsersChart
                        submissionsTrendChart
                        engagementSummary
                        attendanceTrendChart
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadSampleData() }
            .onChange(of: selectedPeriod) { _, _ in loadSampleData() }
        }
    }

    // MARK: - Time Period Picker

    private var timePeriodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Period")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Picker("Time Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Active Users Chart

    private var activeUsersChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Active Users")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            } icon: {
                Image(systemName: "person.wave.2.fill")
                    .foregroundStyle(Theme.brandBlue)
                    .symbolRenderingMode(.hierarchical)
            }

            Chart(activeUsersData) { item in
                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Users", item.count)
                )
                .foregroundStyle(Theme.brandBlue)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Users", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.brandBlue.opacity(0.25), Theme.brandBlue.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel("Users")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let avg = activeUsersData.isEmpty ? 0 : activeUsersData.map(\.count).reduce(0, +) / activeUsersData.count
            let peak = activeUsersData.map(\.count).max() ?? 0
            return "Active Users chart over \(selectedPeriod.rawValue). Average \(avg) users per day, peak \(peak) users."
        }())
    }

    // MARK: - Submissions Trend Chart

    private var submissionsTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Submissions Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            } icon: {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Theme.brandPurple)
                    .symbolRenderingMode(.hierarchical)
            }

            Chart(submissionsData) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Submissions", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.brandPurple, Theme.brandBlue],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .chartYAxisLabel("Submissions")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let total = submissionsData.map(\.count).reduce(0, +)
            let avg = submissionsData.isEmpty ? 0 : total / submissionsData.count
            return "Submissions Trend chart over \(selectedPeriod.rawValue). Total \(total) submissions, average \(avg) per day."
        }())
    }

    // MARK: - Engagement Summary

    private var engagementSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Engagement Summary")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            } icon: {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .foregroundStyle(Theme.brandGreen)
                    .symbolRenderingMode(.hierarchical)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                engagementCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    value: "\(totalMessages)",
                    label: "Messages",
                    color: .blue
                )
                engagementCard(
                    icon: "doc.badge.plus",
                    value: "\(assignmentsCreated)",
                    label: "Assignments",
                    color: Theme.brandPurple
                )
                engagementCard(
                    icon: "questionmark.circle.fill",
                    value: "\(quizAttempts)",
                    label: "Quiz Attempts",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func engagementCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Attendance Trend Chart

    private var attendanceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Attendance Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.brandGreen)
                    .symbolRenderingMode(.hierarchical)
            }

            Chart(attendanceData) { item in
                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Attendance", item.percentage)
                )
                .foregroundStyle(Theme.brandGreen)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Attendance", item.percentage)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.brandGreen.opacity(0.25), Theme.brandGreen.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                RuleMark(y: .value("Target", 90))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("90% target")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
            .chartYAxisLabel("Attendance %")
            .chartYScale(domain: 60...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let avg = attendanceData.isEmpty ? 0.0 : attendanceData.map(\.percentage).reduce(0, +) / Double(attendanceData.count)
            let min = attendanceData.map(\.percentage).min() ?? 0
            let max = attendanceData.map(\.percentage).max() ?? 0
            return "Attendance Trend chart over \(selectedPeriod.rawValue). Average \(Int(avg)) percent, range \(Int(min)) to \(Int(max)) percent, with 90 percent target line."
        }())
    }

    // MARK: - Helpers

    private var xAxisStride: Int {
        switch selectedPeriod {
        case .sevenDays: return 1
        case .thirtyDays: return 5
        case .ninetyDays: return 14
        }
    }

    // MARK: - Sample Data Generation

    private func loadSampleData() {
        isLoading = true
        let calendar = Calendar.current
        let today = Date()
        let dayCount = selectedPeriod.dayCount

        // Generate sample active users data
        activeUsersData = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let base = 40 + Int.random(in: 0...30)
            let weekday = calendar.component(.weekday, from: date)
            let weekendDrop = (weekday == 1 || weekday == 7) ? -20 : 0
            return DailyActiveUsers(date: date, count: max(5, base + weekendDrop))
        }.reversed()

        // Generate sample submissions data
        submissionsData = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let count = isWeekend ? Int.random(in: 0...5) : Int.random(in: 8...35)
            return DailySubmissions(date: date, count: count)
        }.reversed()

        // Generate sample attendance data
        attendanceData = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let pct = isWeekend ? 0.0 : Double.random(in: 82...98)
            return pct > 0 ? DailyAttendance(date: date, percentage: pct) : nil
        }.reversed()

        // Engagement summary sample values
        totalMessages = Int.random(in: 200...800) * (dayCount / 7)
        assignmentsCreated = Int.random(in: 15...60) * (dayCount / 7)
        quizAttempts = Int.random(in: 40...150) * (dayCount / 7)

        isLoading = false
    }
}
