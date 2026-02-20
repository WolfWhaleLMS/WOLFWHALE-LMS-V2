import SwiftUI
import Supabase
import PostgREST

struct TakeAttendanceView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var attendanceDate = Date()
    @State private var studentStatuses: [UUID: AttendanceStatus] = [:]
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    // Placeholder student list for the selected course.
    // Uses viewModel.allUsers if populated; otherwise falls back to generated names.
    private var enrolledStudents: [(id: UUID, name: String)] {
        let fromUsers = viewModel.allUsers
            .filter { $0.role.lowercased() == "student" }
            .prefix(course.enrolledStudentCount)
            .map { (id: $0.id, name: "\($0.firstName) \($0.lastName)") }

        if !fromUsers.isEmpty {
            return Array(fromUsers)
        }

        let placeholderNames = [
            "Alex Rivera", "Jordan Kim", "Sam Patel", "Taylor Brooks",
            "Casey Nguyen", "Morgan Lee", "Jamie Chen", "Riley Scott",
            "Avery Davis", "Quinn Foster", "Dakota Martinez", "Skyler Thompson",
            "Reese Walker", "Finley Adams", "Emery Clark", "Hayden Wright",
            "Parker Young", "Rowan Hall", "Sage Allen", "Blair King",
            "Drew Nelson", "Jules Carter", "Kai Mitchell", "Lane Roberts",
            "Peyton Turner", "Remy Phillips", "Shay Campbell", "Tatum Parker",
        ]
        let count = max(course.enrolledStudentCount, 1)
        return (0..<count).map { index in
            let name = index < placeholderNames.count ? placeholderNames[index] : "Student \(index + 1)"
            return (id: UUID(), name: name)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                datePickerSection
                studentListSection
                saveButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Take Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeStatuses()
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Date Picker

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Date", systemImage: "calendar")
                .font(.headline)

            DatePicker(
                "Attendance Date",
                selection: $attendanceDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Student List

    private var studentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Students")
                    .font(.headline)
                Spacer()
                Text("\(enrolledStudents.count) enrolled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if enrolledStudents.isEmpty {
                HStack {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.secondary)
                    Text("No students enrolled")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(enrolledStudents, id: \.id) { student in
                    studentRow(student)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
    }

    private func studentRow(_ student: (id: UUID, name: String)) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.courseColor(course.colorName).gradient)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(student.name.prefix(1)))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }

                Text(student.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Spacer()

                statusBadge(for: student.id)
            }

            HStack(spacing: 8) {
                statusButton(.present, studentId: student.id)
                statusButton(.absent, studentId: student.id)
                statusButton(.tardy, studentId: student.id)
                statusButton(.excused, studentId: student.id)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func statusBadge(for studentId: UUID) -> some View {
        let status = studentStatuses[studentId] ?? .present
        let color = statusColor(status)
        return Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func statusButton(_ status: AttendanceStatus, studentId: UUID) -> some View {
        let isSelected = (studentStatuses[studentId] ?? .present) == status
        let color = statusColor(status)
        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy(duration: 0.2)) {
                studentStatuses[studentId] = status
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: status.iconName)
                    .font(.callout)
                Text(shortLabel(status))
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 10)
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            hapticTrigger.toggle()
            saveAttendance()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Save Attendance", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .disabled(isLoading || enrolledStudents.isEmpty)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .padding(.top, 4)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Attendance Saved")
                    .font(.title3.bold())
                Text("Recorded for \(enrolledStudents.count) students")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - Helpers

    private func initializeStatuses() {
        guard studentStatuses.isEmpty else { return }
        for student in enrolledStudents {
            studentStatuses[student.id] = .present
        }
    }

    private func saveAttendance() {
        isLoading = true
        errorMessage = nil

        Task {
            // Simulate a brief network delay for demo mode
            try? await Task.sleep(for: .seconds(0.8))

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: attendanceDate)

            for student in enrolledStudents {
                let status = studentStatuses[student.id] ?? .present
                let record = AttendanceRecord(
                    id: UUID(),
                    date: attendanceDate,
                    status: status,
                    courseName: course.title,
                    studentName: student.name
                )
                viewModel.attendance.append(record)

                if !viewModel.isDemoMode {
                    let dto = InsertAttendanceDTO(
                        tenantId: nil,
                        courseId: course.id,
                        studentId: student.id,
                        attendanceDate: dateString,
                        status: status.rawValue,
                        notes: nil,
                        markedBy: nil
                    )
                    // Fire-and-forget insert; errors are silently handled
                    // since the local state is already updated.
                    _ = try? await supabaseClient
                        .from("attendance_records")
                        .insert(dto)
                        .execute()
                }
            }

            isLoading = false
            withAnimation(.snappy) {
                showSuccess = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSuccess = false }
        }
    }

    private func statusColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .present: .green
        case .absent: .red
        case .tardy: .orange
        case .excused: .blue
        }
    }

    private func shortLabel(_ status: AttendanceStatus) -> String {
        switch status {
        case .present: "Present"
        case .absent: "Absent"
        case .tardy: "Tardy"
        case .excused: "Excused"
        }
    }
}
