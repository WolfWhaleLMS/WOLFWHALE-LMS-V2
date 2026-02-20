import SwiftUI

struct GradebookView: View {
    let course: Course
    let viewModel: AppViewModel
    @State private var showAddAssignment = false

    private var courseAssignments: [Assignment] {
        viewModel.assignments.filter { $0.courseName == course.title }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseHeader
                statsSection
                studentsSection
                assignmentsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") {
                    showAddAssignment = true
                }
            }
        }
        .sheet(isPresented: $showAddAssignment) {
            addAssignmentSheet
        }
    }

    private var courseHeader: some View {
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
                HStack(spacing: 8) {
                    Label("Code: \(course.classCode)", systemImage: "number")
                    Label("\(course.enrolledStudentCount) students", systemImage: "person.3.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(label: "Avg Grade", value: "88%", color: .green)
            statCard(label: "Completion", value: "\(Int(course.progress * 100))%", color: .blue)
            statCard(label: "Pending", value: "\(viewModel.pendingGradingCount)", color: .orange)
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
    }

    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Student Roster")
                .font(.headline)

            ForEach(Array(sampleStudents.enumerated()), id: \.offset) { index, student in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(student.prefix(1)))
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple)
                        }
                    Text(student)
                        .font(.subheadline)
                    Spacer()
                    Text(sampleGrades[index])
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gradeColor(sampleNumericGrades[index]))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignments")
                .font(.headline)

            if courseAssignments.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("No assignments yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(courseAssignments) { assignment in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.title)
                                .font(.subheadline.bold())
                            Text("Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(assignment.points) pts")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private var addAssignmentSheet: some View {
        NavigationStack {
            Form {
                Section("Assignment Details") {
                    TextField("Title", text: .constant(""))
                    TextField("Instructions", text: .constant(""), axis: .vertical)
                        .lineLimit(3...)
                    DatePicker("Due Date", selection: .constant(Date()), displayedComponents: .date)
                    Stepper("Points: 100", value: .constant(100), in: 10...500, step: 10)
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddAssignment = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { showAddAssignment = false }
                }
            }
        }
    }

    private let sampleStudents = ["Alex Rivera", "Jordan Kim", "Sam Patel", "Taylor Brooks", "Casey Nguyen"]
    private let sampleGrades = ["A-", "B+", "A", "B", "A-"]
    private let sampleNumericGrades: [Double] = [91, 87, 95, 83, 90]
}
