import SwiftUI

struct StudentSubmissionsView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var selectedStudentForNotes: (id: UUID, name: String)?
    @State private var showStudentNotes = false
    @State private var hapticTrigger = false

    private var courseAssignments: [Assignment] {
        viewModel.assignments.filter { $0.courseId == course.id }
    }

    private var submittedAssignments: [Assignment] {
        courseAssignments.filter { $0.isSubmitted }
    }

    private var groupedByStudent: [(studentName: String, studentId: UUID?, assignments: [Assignment])] {
        var grouped: [String: (studentId: UUID?, assignments: [Assignment])] = [:]
        for assignment in submittedAssignments {
            let name = assignment.studentName ?? "Unknown Student"
            if grouped[name] == nil {
                grouped[name] = (studentId: assignment.studentId, assignments: [])
            }
            grouped[name]?.assignments.append(assignment)
        }
        return grouped.map { (studentName: $0.key, studentId: $0.value.studentId, assignments: $0.value.assignments) }
            .sorted { $0.studentName.localizedStandardCompare($1.studentName) == .orderedAscending }
    }

    private var ungradedCount: Int {
        submittedAssignments.filter { $0.grade == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                statsRow
                studentListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Student Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStudentNotes) {
            if let student = selectedStudentForNotes {
                NavigationStack {
                    StudentNotesView(
                        viewModel: viewModel,
                        studentId: student.id,
                        studentName: student.name,
                        courseId: course.id,
                        courseName: course.title
                    )
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: course.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                Text("Submissions by student")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(label: "Students", value: "\(groupedByStudent.count)", color: .blue)
            statCard(label: "Submitted", value: "\(submittedAssignments.count)", color: .green)
            statCard(label: "Ungraded", value: "\(ungradedCount)", color: .orange)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Student List Section

    private var studentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Student")
                .font(.headline)

            if groupedByStudent.isEmpty {
                emptyState
            } else {
                ForEach(groupedByStudent, id: \.studentName) { group in
                    studentCard(name: group.studentName, assignments: group.assignments)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No submissions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("When students submit assignments for this course, they will appear here grouped by student.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func studentCard(name: String, assignments: [Assignment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Student header
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.bold())
                    let graded = assignments.filter { $0.grade != nil }.count
                    Text("\(assignments.count) submitted, \(graded) graded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Notes button
                if let studentId = assignments.first?.studentId {
                    let noteCount = viewModel.noteCount(forStudent: studentId, inCourse: course.id)
                    Button {
                        hapticTrigger.toggle()
                        selectedStudentForNotes = (id: studentId, name: name)
                        showStudentNotes = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                            if noteCount > 0 {
                                Text("\(noteCount)")
                                    .font(.caption2.bold())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("\(noteCount) note\(noteCount == 1 ? "" : "s") for \(name)")
                    .accessibilityHint("Double tap to view and add notes")
                }

                // Average grade badge
                let gradedAssignments = assignments.filter { $0.grade != nil }
                if !gradedAssignments.isEmpty {
                    let avg = gradedAssignments.reduce(0.0) { $0 + ($1.grade ?? 0) } / Double(gradedAssignments.count)
                    Text("\(Int(avg))%")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.gradeColor(avg).opacity(0.15), in: .capsule)
                        .foregroundStyle(Theme.gradeColor(avg))
                }
            }

            Divider()

            // Assignment list for this student
            ForEach(Array(assignments.enumerated()), id: \.offset) { _, assignment in
                submissionRow(assignment)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel({
            let graded = assignments.filter { $0.grade != nil }.count
            let gradedAssignments = assignments.filter { $0.grade != nil }
            let avgText = gradedAssignments.isEmpty ? "" : ", average grade \(Int(gradedAssignments.reduce(0.0) { $0 + ($1.grade ?? 0) } / Double(gradedAssignments.count))) percent"
            return "\(name): \(assignments.count) submitted, \(graded) graded\(avgText)"
        }())
    }

    private func submissionRow(_ assignment: Assignment) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: assignment.grade != nil ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(assignment.grade != nil ? .green : .orange)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title)
                        .font(.caption.bold())
                    Text("Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if let grade = assignment.grade {
                    Text("\(Int(grade))%")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.gradeColor(grade))
                } else {
                    NavigationLink {
                        GradeSubmissionView(viewModel: viewModel, assignment: assignment)
                    } label: {
                        Text("Grade")
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.orange.opacity(0.15), in: .capsule)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
