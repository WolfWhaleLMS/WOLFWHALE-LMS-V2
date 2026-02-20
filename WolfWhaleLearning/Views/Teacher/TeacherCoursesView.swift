import SwiftUI

struct TeacherCoursesView: View {
    let viewModel: AppViewModel
    @State private var showCreateCourse = false
    @State private var newCourseTitle = ""
    @State private var newCourseDescription = ""
    @State private var newCourseColor = "blue"
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.courses) { course in
                        NavigationLink(value: course) {
                            teacherCourseRow(course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Course", systemImage: "plus") {
                        showCreateCourse = true
                    }
                }
            }
            .navigationDestination(for: Course.self) { course in
                GradebookView(course: course, viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateCourse) {
                createCourseSheet
            }
            .overlay {
                if viewModel.courses.isEmpty {
                    ContentUnavailableView("No Courses", systemImage: "book.fill", description: Text("Create your first course to get started"))
                }
            }
        }
    }

    private func teacherCourseRow(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.courseColor(course.colorName).gradient)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: course.iconSystemName)
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.headline)
                    Text("\(course.enrolledStudentCount) students enrolled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                Label(course.classCode, systemImage: "number")
                Label("\(course.modules.count) modules", systemImage: "folder.fill")
                Label("\(course.totalLessons) lessons", systemImage: "doc.text.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var createCourseSheet: some View {
        NavigationStack {
            Form {
                Section("Course Details") {
                    TextField("Course Title", text: $newCourseTitle)
                    TextField("Description", text: $newCourseDescription, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Settings") {
                    Picker("Color", selection: $newCourseColor) {
                        Text("Blue").tag("blue")
                        Text("Green").tag("green")
                        Text("Orange").tag("orange")
                        Text("Purple").tag("purple")
                        Text("Pink").tag("pink")
                        Text("Red").tag("red")
                    }
                }
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetCourseForm()
                        showCreateCourse = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCourse()
                    }
                    .fontWeight(.semibold)
                    .disabled(newCourseTitle.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating course...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func createCourse() {
        isCreating = true
        Task {
            do {
                try await viewModel.createCourse(
                    title: newCourseTitle.trimmingCharacters(in: .whitespaces),
                    description: newCourseDescription.trimmingCharacters(in: .whitespaces),
                    colorName: newCourseColor
                )
                resetCourseForm()
                showCreateCourse = false
            } catch {
            }
            isCreating = false
        }
    }

    private func resetCourseForm() {
        newCourseTitle = ""
        newCourseDescription = ""
        newCourseColor = "blue"
    }
}
