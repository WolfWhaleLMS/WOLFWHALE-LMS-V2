import SwiftUI

struct TimetableView: View {
    let viewModel: AppViewModel

    // MARK: - Constants

    /// The timetable spans 8 AM (480 min) to 4 PM (960 min).
    private let startOfDay = 480   // 8:00 AM in minutes
    private let endOfDay   = 960   // 4:00 PM in minutes
    private let hourHeight: CGFloat = 80
    private let columnWidth: CGFloat = 160
    private let timeGutterWidth: CGFloat = 54

    private var totalHeight: CGFloat {
        CGFloat(endOfDay - startOfDay) / 60.0 * hourHeight
    }

    private var todayWeekday: DayOfWeek? {
        DayOfWeek.from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
    }

    var body: some View {
        ScrollView(.horizontal) {
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    // Background grid
                    gridBackground

                    // Time gutter labels
                    timeGutter

                    // Day columns with course blocks
                    HStack(alignment: .top, spacing: 0) {
                        // Spacer for time gutter
                        Color.clear
                            .frame(width: timeGutterWidth)

                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            dayColumn(for: day)
                                .frame(width: columnWidth)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.visible)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly Schedule")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines
            ForEach(0..<9, id: \.self) { hourIndex in
                Rectangle()
                    .fill(Color(.separator).opacity(0.3))
                    .frame(height: 0.5)
                    .offset(y: headerHeight + CGFloat(hourIndex) * hourHeight)
            }
        }
        .frame(
            width: timeGutterWidth + columnWidth * CGFloat(DayOfWeek.allCases.count),
            height: headerHeight + totalHeight
        )
    }

    private var headerHeight: CGFloat { 52 }

    // MARK: - Time Gutter

    private var timeGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Header spacer
            Color.clear.frame(height: headerHeight)

            ZStack(alignment: .topTrailing) {
                ForEach(8..<16, id: \.self) { hour in
                    let label = formatHour(hour)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .offset(y: CGFloat(hour - 8) * hourHeight - 6)
                }
            }
            .frame(height: totalHeight)
        }
        .frame(width: timeGutterWidth)
    }

    // MARK: - Day Column

    private func dayColumn(for day: DayOfWeek) -> some View {
        let isToday = day == todayWeekday
        let schedulesForDay = viewModel.courseSchedules
            .filter { $0.dayOfWeek == day }
            .sorted { $0.startMinute < $1.startMinute }

        return VStack(spacing: 0) {
            // Day header
            VStack(spacing: 2) {
                Text(day.shortName)
                    .font(.caption.bold())
                    .foregroundStyle(isToday ? .white : .secondary)
                Text(dayDate(for: day))
                    .font(.system(size: 10))
                    .foregroundStyle(isToday ? Color.white.opacity(0.8) : Color(UIColor.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .frame(height: headerHeight)
            .background(isToday ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 2)

            // Time slot area
            ZStack(alignment: .top) {
                // Column background highlight for today
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.04))
                        .frame(height: totalHeight)
                }

                // Course blocks
                ForEach(schedulesForDay) { schedule in
                    courseBlock(for: schedule)
                }

                // Current time indicator
                if isToday {
                    currentTimeIndicator
                }
            }
            .frame(height: totalHeight)
        }
    }

    // MARK: - Course Block

    @ViewBuilder
    private func courseBlock(for schedule: CourseSchedule) -> some View {
        let course = viewModel.courses.first { $0.id == schedule.courseId }
        let color = Theme.courseColor(course?.colorName ?? "blue")
        let yOffset = CGFloat(schedule.startMinute - startOfDay) / 60.0 * hourHeight
        let blockHeight = CGFloat(schedule.durationMinutes) / 60.0 * hourHeight

        let blockContent = VStack(alignment: .leading, spacing: 3) {
            Text(course?.title ?? "Course")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(schedule.roomNumber)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(schedule.timeRangeString)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight - 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.3), radius: 3, y: 2)
        .padding(.horizontal, 3)

        if let course {
            NavigationLink {
                CourseDetailView(course: course, viewModel: viewModel)
            } label: {
                blockContent
            }
            .buttonStyle(.plain)
            .offset(y: yOffset + 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(course.title), \(schedule.dayOfWeek.fullName), \(schedule.timeRangeString), \(schedule.roomNumber)")
            .accessibilityHint("Double tap to open course detail")
        } else {
            blockContent
                .offset(y: yOffset + 2)
        }
    }

    // MARK: - Current Time Indicator

    @ViewBuilder
    private var currentTimeIndicator: some View {
        let now = Date()
        let calendar = Calendar.current
        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        if currentMinute >= startOfDay && currentMinute <= endOfDay {
            let yOffset = CGFloat(currentMinute - startOfDay) / 60.0 * hourHeight
            HStack(spacing: 0) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(.red)
                    .frame(height: 1.5)
            }
            .offset(y: yOffset)
        }
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : hour
        return "\(displayHour) \(period)"
    }

    /// Returns the date string (e.g. "17") for a given day of the current week.
    private func dayDate(for day: DayOfWeek) -> String {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        // Calendar weekday: 1=Sun, 2=Mon, ... Map DayOfWeek rawValue (Mon=1) to calendar weekday (Mon=2)
        let targetCalendarWeekday = day.rawValue + 1
        let dayDifference = targetCalendarWeekday - currentWeekday
        guard let date = calendar.date(byAdding: .day, value: dayDifference, to: today) else {
            return ""
        }
        let dayNum = calendar.component(.day, from: date)
        return "\(dayNum)"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimetableView(viewModel: {
            let vm = AppViewModel()
            vm.courses = MockDataService.shared.sampleCourses()
            vm.courseSchedules = [
                CourseSchedule(id: UUID(), courseId: vm.courses[0].id, dayOfWeek: .monday, startMinute: 480, endMinute: 530, roomNumber: "Room 204"),
                CourseSchedule(id: UUID(), courseId: vm.courses[0].id, dayOfWeek: .wednesday, startMinute: 480, endMinute: 530, roomNumber: "Room 204"),
                CourseSchedule(id: UUID(), courseId: vm.courses[0].id, dayOfWeek: .friday, startMinute: 480, endMinute: 530, roomNumber: "Room 204"),
                CourseSchedule(id: UUID(), courseId: vm.courses[1].id, dayOfWeek: .tuesday, startMinute: 540, endMinute: 615, roomNumber: "Lab 112"),
                CourseSchedule(id: UUID(), courseId: vm.courses[1].id, dayOfWeek: .thursday, startMinute: 540, endMinute: 615, roomNumber: "Lab 112"),
                CourseSchedule(id: UUID(), courseId: vm.courses[2].id, dayOfWeek: .monday, startMinute: 630, endMinute: 680, roomNumber: "Room 310"),
                CourseSchedule(id: UUID(), courseId: vm.courses[2].id, dayOfWeek: .wednesday, startMinute: 630, endMinute: 680, roomNumber: "Room 310"),
                CourseSchedule(id: UUID(), courseId: vm.courses[2].id, dayOfWeek: .friday, startMinute: 630, endMinute: 680, roomNumber: "Room 310"),
                CourseSchedule(id: UUID(), courseId: vm.courses[3].id, dayOfWeek: .tuesday, startMinute: 780, endMinute: 855, roomNumber: "Room 105"),
                CourseSchedule(id: UUID(), courseId: vm.courses[3].id, dayOfWeek: .thursday, startMinute: 780, endMinute: 855, roomNumber: "Room 105"),
            ]
            return vm
        }())
    }
}
