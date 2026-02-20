import SwiftUI

struct GradebookView: View {
    let course: Course
    let viewModel: AppViewModel
    @State private var showAddAssignment = false
    @State private var showCreateModule = false
    @State private var showCreateQuiz = false
    @State private var selectedModuleForLesson: Module?
    @State private var newTitle = ""
    @State private var newInstructions = ""
    @State private var newDueDate = Date().addingTimeInterval(7 * 86400)
    @State private var newPoints: Int = 100
    @State private var isCreating = false

    private var courseAssignments: [Assignment] {
        viewModel.assignments.filter { $0.courseName == course.title || $0.courseId == course.id }
    }

    private var submittedCount: Int {
        courseAssignments.filter(\.isSubmitted).count
    }

    private var pendingCount: Int {
        courseAssignments.filter { $0.isSubmitted && $0.grade == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseHeader
                statsSection
                contentActionsSection
                courseContentSection
                enrolledStudentsSection
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
        .sheet(isPresented: $showCreateModule) {
            NavigationStack {
                CreateModuleView(viewModel: viewModel, course: course)
            }
        }
        .sheet(isPresented: $showCreateQuiz) {
            NavigationStack {
                CreateQuizView(viewModel: viewModel, course: course)
            }
        }
        .sheet(item: $selectedModuleForLesson) { module in
            NavigationStack {
                CreateLessonView(viewModel: viewModel, course: course, module: module)
            }
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
            statCard(label: "Assignments", value: "\(courseAssignments.count)", color: .blue)
            statCard(label: "Submitted", value: "\(submittedCount)", color: .green)
            statCard(label: "Pending", value: "\(pendingCount)", color: .orange)
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

    // MARK: - Content Actions

    private var contentActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Content")
                .font(.headline)

            HStack(spacing: 10) {
                contentActionButton(icon: "folder.fill.badge.plus", label: "Add Module", color: .purple) {
                    showCreateModule = true
                }
                contentActionButton(icon: "questionmark.circle.fill", label: "Create Quiz", color: .orange) {
                    showCreateQuiz = true
                }
            }
        }
    }

    private func contentActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Course Content (Modules & Lessons)

    private var courseContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                Text("\(course.modules.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if course.modules.isEmpty {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text("No modules yet. Add a module to start building content.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(course.modules) { module in
                    moduleRow(module)
                }
            }
        }
    }

    private func moduleRow(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Theme.courseColor(course.colorName))
                Text(module.title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(module.lessons.count) lessons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !module.lessons.isEmpty {
                ForEach(module.lessons) { lesson in
                    HStack(spacing: 8) {
                        Image(systemName: lesson.type.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(lesson.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(lesson.duration) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }

            Button {
                selectedModuleForLesson = module
            } label: {
                Label("Add Lesson", systemImage: "plus.circle")
                    .font(.caption.bold())
            }
            .tint(.pink)
            .padding(.top, 2)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private var enrolledStudentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Enrolled Students")
                    .font(.headline)
                Spacer()
                Text("\(course.enrolledStudentCount) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if course.enrolledStudentCount == 0 {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No students enrolled yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text("Share class code **\(course.classCode)** with students to enroll them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Assignments Section

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
                    assignmentRow(assignment)
                }
            }
        }
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title)
                        .font(.subheadline.bold())
                    Text("Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(assignment.points) pts")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if assignment.isSubmitted {
                        if let grade = assignment.grade {
                            Text("Graded: \(Int(grade))%")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("Submitted")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Grade button for submitted but ungraded assignments
            if assignment.isSubmitted && assignment.grade == nil {
                Divider()
                    .padding(.vertical, 8)

                NavigationLink {
                    GradeSubmissionView(viewModel: viewModel, assignment: assignment)
                } label: {
                    Label("Grade Submission", systemImage: "pencil.and.list.clipboard")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Add Assignment Sheet

    private var addAssignmentSheet: some View {
        NavigationStack {
            Form {
                Section("Assignment Details") {
                    TextField("Title", text: $newTitle)
                    TextField("Instructions", text: $newInstructions, axis: .vertical)
                        .lineLimit(3...)
                    DatePicker("Due Date", selection: $newDueDate, displayedComponents: .date)
                    Stepper("Points: \(newPoints)", value: $newPoints, in: 10...500, step: 10)
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetAssignmentForm()
                        showAddAssignment = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createAssignment()
                    }
                    .fontWeight(.semibold)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func createAssignment() {
        isCreating = true
        Task {
            do {
                try await viewModel.createAssignment(
                    courseId: course.id,
                    title: newTitle.trimmingCharacters(in: .whitespaces),
                    instructions: newInstructions.trimmingCharacters(in: .whitespaces),
                    dueDate: newDueDate,
                    points: newPoints
                )
                resetAssignmentForm()
                showAddAssignment = false
            } catch {
            }
            isCreating = false
        }
    }

    private func resetAssignmentForm() {
        newTitle = ""
        newInstructions = ""
        newDueDate = Date().addingTimeInterval(7 * 86400)
        newPoints = 100
    }
}
