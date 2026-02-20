import SwiftUI

struct TeacherCoursesView: View {
    let viewModel: AppViewModel
    @State private var showCreateCourse = false

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
                    TextField("Course Title", text: .constant(""))
                    TextField("Description", text: .constant(""), axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Settings") {
                    Picker("Color", selection: .constant("blue")) {
                        Text("Blue").tag("blue")
                        Text("Green").tag("green")
                        Text("Orange").tag("orange")
                        Text("Purple").tag("purple")
                    }
                }
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateCourse = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { showCreateCourse = false }
                }
            }
        }
    }
}
