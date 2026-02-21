import SwiftUI

struct AttendanceReportView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel

    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var showExportSheet = false
    @State private var hapticTrigger = false

    // MARK: - Computed Properties

    private var courseRecords: [AttendanceRecord] {
        viewModel.attendance.filter { record in
            record.courseName == course.title &&
            record.date >= startDate &&
            record.date <= endDate
        }
    }

    private var studentNames: [String] {
        let names = Set(courseRecords.compactMap(\.studentName))
        return names.sorted()
    }

    private var studentSummaries: [StudentAttendanceSummary] {
        studentNames.map { name in
            let records = courseRecords.filter { $0.studentName == name }
            let present = records.filter { $0.status == .present }.count
            let absent = records.filter { $0.status == .absent }.count
            let tardy = records.filter { $0.status == .tardy }.count
            let excused = records.filter { $0.status == .excused }.count
            let total = records.count
            let rate = total > 0 ? Double(present) / Double(total) : 0.0

            return StudentAttendanceSummary(
                name: name,
                present: present,
                absent: absent,
                tardy: tardy,
                excused: excused,
                total: total,
                rate: rate
            )
        }
        .sorted { $0.rate < $1.rate }
    }

    private var overallRate: Double {
        let total = courseRecords.count
        guard total > 0 else { return 0 }
        let present = courseRecords.filter { $0.status == .present }.count
        return Double(present) / Double(total)
    }

    private var exportText: String {
        var lines: [String] = []
        lines.append("Attendance Report: \(course.title)")
        lines.append("Date Range: \(formatDate(startDate)) - \(formatDate(endDate))")
        lines.append("Overall Attendance Rate: \(Int(overallRate * 100))%")
        lines.append("")
        lines.append("Student | Present | Absent | Tardy | Excused | Rate")
        lines.append(String(repeating: "-", count: 60))

        for summary in studentSummaries {
            lines.append("\(summary.name) | \(summary.present) | \(summary.absent) | \(summary.tardy) | \(summary.excused) | \(Int(summary.rate * 100))%")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dateRangeSection
                overviewSection
                studentListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Attendance Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticTrigger.toggle()
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Export Report")
                .accessibilityHint("Double tap to export attendance data")
            }
        }
        .sheet(isPresented: $showExportSheet) {
            exportView
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date Range", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Course Overview")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                overviewStat(
                    icon: "person.3.fill",
                    value: "\(studentNames.count)",
                    label: "Students",
                    color: .blue
                )
                overviewStat(
                    icon: "checkmark.circle.fill",
                    value: "\(Int(overallRate * 100))%",
                    label: "Avg Rate",
                    color: rateColor(overallRate)
                )
                overviewStat(
                    icon: "calendar",
                    value: "\(courseRecords.count)",
                    label: "Records",
                    color: .purple
                )
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func overviewStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
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

    // MARK: - Student List Section

    private var studentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Student Attendance")
                    .font(.headline)
                Spacer()
                Text("Sorted by risk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if studentSummaries.isEmpty {
                HStack {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.secondary)
                    Text("No attendance data for this date range")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(studentSummaries, id: \.name) { summary in
                    studentSummaryRow(summary)
                }
            }
        }
    }

    private func studentSummaryRow(_ summary: StudentAttendanceSummary) -> some View {
        let color = rateColor(summary.rate)

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(summary.name.prefix(1)))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.subheadline.bold())
                    Text("\(summary.total) records")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(summary.rate * 100))%")
                    .font(.headline)
                    .foregroundStyle(color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.quaternarySystemFill))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * min(summary.rate, 1.0))
                }
            }
            .frame(height: 6)

            // Breakdown
            HStack(spacing: 16) {
                breakdownPill(value: summary.present, label: "Present", color: .green)
                breakdownPill(value: summary.absent, label: "Absent", color: .red)
                breakdownPill(value: summary.tardy, label: "Tardy", color: .orange)
                breakdownPill(value: summary.excused, label: "Excused", color: .gray)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.name), attendance rate \(Int(summary.rate * 100)) percent, \(summary.present) present, \(summary.absent) absent, \(summary.tardy) tardy, \(summary.excused) excused, out of \(summary.total) total records")
    }

    private func breakdownPill(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(value)")
                .font(.caption2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Export View

    private var exportView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Attendance Report")
                        .font(.title2.bold())

                    Text(course.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hapticTrigger.toggle()
                        showExportSheet = false
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Helpers

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.9...: .green
        case 0.7..<0.9: .orange
        default: .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Student Summary Model

private struct StudentAttendanceSummary {
    let name: String
    let present: Int
    let absent: Int
    let tardy: Int
    let excused: Int
    let total: Int
    let rate: Double
}
