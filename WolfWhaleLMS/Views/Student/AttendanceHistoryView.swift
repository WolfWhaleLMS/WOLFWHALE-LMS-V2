import SwiftUI

struct AttendanceHistoryView: View {
    @Bindable var viewModel: AppViewModel

    @State private var selectedCourse: String = "All"
    @State private var selectedMonth: Date = Date()

    // MARK: - Computed Properties

    private var courseNames: [String] {
        let names = Set(viewModel.attendance.map(\.courseName))
        return ["All"] + names.sorted()
    }

    private var filteredRecords: [AttendanceRecord] {
        if selectedCourse == "All" {
            return viewModel.attendance
        }
        return viewModel.attendance.filter { $0.courseName == selectedCourse }
    }

    private var presentCount: Int {
        filteredRecords.filter { $0.status == .present }.count
    }

    private var absentCount: Int {
        filteredRecords.filter { $0.status == .absent }.count
    }

    private var tardyCount: Int {
        filteredRecords.filter { $0.status == .tardy }.count
    }

    private var excusedCount: Int {
        filteredRecords.filter { $0.status == .excused }.count
    }

    private var totalCount: Int {
        filteredRecords.count
    }

    private var attendanceRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(presentCount) / Double(totalCount)
    }

    private var currentStreak: Int {
        let sorted = filteredRecords
            .sorted { $0.date > $1.date }
        var streak = 0
        for record in sorted {
            if record.status == .present {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Calendar Helpers

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }

    private var firstWeekday: Int {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return 0
        }
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    private func attendanceStatus(for date: Date) -> AttendanceStatus? {
        let dayComponent = calendar.dateComponents([.year, .month, .day], from: date)
        return filteredRecords.first { record in
            let recordDay = calendar.dateComponents([.year, .month, .day], from: record.date)
            return recordDay == dayComponent
        }?.status
    }

    private func statusColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .present: .green
        case .absent: .red
        case .tardy: .orange
        case .excused: .gray
        }
    }

    // MARK: - Weekly Grouping

    private var recordsByWeek: [(String, [AttendanceRecord])] {
        let sorted = filteredRecords.sorted { $0.date > $1.date }
        let formatter = DateFormatter()
        formatter.dateFormat = "'Week of' MMM d"

        var grouped: [(String, [AttendanceRecord])] = []
        var currentWeekLabel = ""
        var currentWeekRecords: [AttendanceRecord] = []

        for record in sorted {
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: record.date)?.start ?? record.date
            let label = formatter.string(from: startOfWeek)

            if label != currentWeekLabel {
                if !currentWeekRecords.isEmpty {
                    grouped.append((currentWeekLabel, currentWeekRecords))
                }
                currentWeekLabel = label
                currentWeekRecords = [record]
            } else {
                currentWeekRecords.append(record)
            }
        }
        if !currentWeekRecords.isEmpty {
            grouped.append((currentWeekLabel, currentWeekRecords))
        }

        return grouped
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filteredRecords.isEmpty && viewModel.attendance.isEmpty {
                    ContentUnavailableView(
                        "No Attendance Records Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Your attendance history will appear here once records are available.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            courseFilterPicker
                            statsSection
                            calendarSection
                            recentRecordsSection
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Attendance History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Course Filter

    private var courseFilterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by Course")
                .font(.subheadline.bold())
            Picker("Course", selection: $selectedCourse) {
                ForEach(courseNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 16) {
            // Attendance Rate Ring
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(attendanceRate, 1.0))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(attendanceRate * 100))%")
                            .font(.title3.bold())
                        Text("Rate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

            // Streak + Breakdown
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(currentStreak) Day Streak")
                        .font(.subheadline.bold())
                }

                HStack(spacing: 10) {
                    miniStat(value: presentCount, label: "Present", color: .green)
                    miniStat(value: absentCount, label: "Absent", color: .red)
                    miniStat(value: tardyCount, label: "Tardy", color: .orange)
                    miniStat(value: excusedCount, label: "Excused", color: .gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    private func miniStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month Navigation
            HStack {
                Button {
                    withAnimation(.snappy) {
                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                }

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                }
            }

            // Weekday Headers
            let weekdaySymbols = calendar.veryShortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                // Empty cells for offset
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 32)
                }

                // Day cells
                ForEach(daysInMonth, id: \.self) { date in
                    let status = attendanceStatus(for: date)
                    let dayNumber = calendar.component(.day, from: date)

                    ZStack {
                        if let status {
                            Circle()
                                .fill(statusColor(status).opacity(0.25))
                            Circle()
                                .stroke(statusColor(status), lineWidth: 1.5)
                        }
                        Text("\(dayNumber)")
                            .font(.caption2.bold())
                            .foregroundStyle(status != nil ? statusColor(status!) : .primary)
                    }
                    .frame(height: 32)
                }
            }

            // Legend
            HStack(spacing: 12) {
                legendItem(color: .green, label: "Present")
                legendItem(color: .red, label: "Absent")
                legendItem(color: .orange, label: "Tardy")
                legendItem(color: .gray, label: "Excused")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Records")
                .font(.headline)

            if filteredRecords.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No records for this filter")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(recordsByWeek, id: \.0) { weekLabel, records in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(weekLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        ForEach(records) { record in
                            attendanceRecordRow(record)
                        }
                    }
                }
            }
        }
    }

    private func attendanceRecordRow(_ record: AttendanceRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.subheadline.bold())
                Text(record.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(record.status.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor(record.status).opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor(record.status))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }
}
