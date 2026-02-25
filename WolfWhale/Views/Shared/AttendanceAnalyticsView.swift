import SwiftUI

struct AttendanceAnalyticsView: View {
    let viewModel: AppViewModel
    let isAdmin: Bool

    private var verifiedIsAdmin: Bool {
        viewModel.currentUser?.role == .admin || viewModel.currentUser?.role == .superAdmin
    }

    @State private var selectedCourseId: String? = nil
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var report: AttendanceReport?
    @State private var hapticTrigger = false

    private var csvData: String {
        report?.toCSV() ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                filtersSection
                if let report {
                    summarySection(report: report)
                    chartSection(report: report)
                    studentListSection(report: report)
                    exportSection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Attendance Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateReport()
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if !verifiedIsAdmin {
                // Teacher: course picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Course")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Picker("Course", selection: $selectedCourseId) {
                        Text("All Courses").tag(String?.none)
                        ForEach(viewModel.courses) { course in
                            Text(course.title).tag(Optional(course.id.uuidString))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(.label))
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("End")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()
            }

            Button {
                hapticTrigger.toggle()
                generateReport()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Generate Report")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel("Generate attendance report")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary Stats

    private func summarySection(report: AttendanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(Color(.label))

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                statCard(
                    label: "Total Days",
                    value: "\(report.totalDays)",
                    color: .blue
                )
                statCard(
                    label: "Records",
                    value: "\(report.totalRecords)",
                    color: .purple
                )
                statCard(
                    label: "Overall Rate",
                    value: String(format: "%.1f%%", report.overallRate),
                    color: rateColor(report.overallRate)
                )
                statCard(
                    label: "Present",
                    value: String(format: "%.1f%%", report.presentPercent),
                    color: .green
                )
                statCard(
                    label: "Absent",
                    value: String(format: "%.1f%%", report.absentPercent),
                    color: .red
                )
                statCard(
                    label: "Tardy",
                    value: String(format: "%.1f%%", report.tardyPercent),
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attendance summary")
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Bar Chart

    private func chartSection(report: AttendanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Attendance")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if report.dailyRates.isEmpty {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(.secondary)
                    Text("No daily data available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Legend
                HStack(spacing: 16) {
                    legendItem(color: .green, label: "> 93%")
                    legendItem(color: .orange, label: "85-93%")
                    legendItem(color: .red, label: "< 85%")
                }
                .font(.caption2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(report.dailyRates) { daily in
                            VStack(spacing: 4) {
                                Text(String(format: "%.0f%%", daily.rate))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))

                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 100)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(rateColor(daily.rate).gradient)
                                        .frame(height: max(4, 100 * min(daily.rate / 100.0, 1.0)))
                                }
                                .frame(width: barWidth(for: report.dailyRates.count))

                                Text(shortDateLabel(daily.date))
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(fullDateLabel(daily.date)): \(String(format: "%.0f", daily.rate)) percent")
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 140)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily attendance chart")
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    private func barWidth(for count: Int) -> CGFloat {
        if count <= 7 { return 36 }
        if count <= 14 { return 28 }
        if count <= 30 { return 20 }
        return 14
    }

    // MARK: - Student List

    private func studentListSection(report: AttendanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Student Breakdown")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if report.studentBreakdowns.isEmpty {
                HStack {
                    Image(systemName: "person.3")
                        .foregroundStyle(.secondary)
                    Text("No student data available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(report.studentBreakdowns) { student in
                    studentRow(student: student)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func studentRow(student: StudentAttendanceBreakdown) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(rateColor(student.attendanceRate))

                VStack(alignment: .leading, spacing: 2) {
                    Text(student.studentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("\(student.totalRecords) records")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Text(String(format: "%.1f%%", student.attendanceRate))
                    .font(.headline)
                    .foregroundStyle(rateColor(student.attendanceRate))
            }

            // Mini breakdown bar
            GeometryReader { geometry in
                let total = CGFloat(max(student.totalRecords, 1))
                HStack(spacing: 1) {
                    if student.presentCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(student.presentCount) / total)
                    }
                    if student.tardyCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(student.tardyCount) / total)
                    }
                    if student.excusedCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(student.excusedCount) / total)
                    }
                    if student.absentCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: geometry.size.width * CGFloat(student.absentCount) / total)
                    }
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            HStack(spacing: 12) {
                miniStat(label: "Present", count: student.presentCount, color: .green)
                miniStat(label: "Tardy", count: student.tardyCount, color: .orange)
                miniStat(label: "Excused", count: student.excusedCount, color: .blue)
                miniStat(label: "Absent", count: student.absentCount, color: .red)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(student.studentName), attendance rate \(String(format: "%.1f", student.attendanceRate)) percent, \(student.presentCount) present, \(student.absentCount) absent, \(student.tardyCount) tardy, \(student.excusedCount) excused")
    }

    private func miniStat(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.headline)
                .foregroundStyle(Color(.label))

            ShareLink(
                item: csvData,
                subject: Text("Attendance Report"),
                message: Text("Attendance report generated from WolfWhale LMS")
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export as CSV")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export attendance report as CSV")
            .accessibilityHint("Opens a share sheet to export the report data")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Report Generated")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Select filters and tap Generate Report to view attendance data.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func generateReport() {
        let courseIdArg: String? = verifiedIsAdmin ? nil : selectedCourseId
        report = viewModel.generateAttendanceReport(
            courseId: courseIdArg,
            startDate: startDate,
            endDate: endDate
        )
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate > 93 { return .green }
        if rate >= 85 { return .orange }
        return .red
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func fullDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
