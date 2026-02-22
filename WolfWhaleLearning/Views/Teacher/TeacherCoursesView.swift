import SwiftUI

struct TeacherCoursesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showCreateCourse = false
    @State private var hapticTrigger = false

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
            .refreshable {
                await viewModel.refreshCourses()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Course", systemImage: "plus") {
                        hapticTrigger.toggle()
                        showCreateCourse = true
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Create new course")
                    .accessibilityHint("Double tap to create a new course")
                }
            }
            .navigationDestination(for: Course.self) { course in
                GradebookView(course: course, viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateCourse) {
                EnhancedCourseCreationView(viewModel: viewModel)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.title), \(course.enrolledStudentCount) students, code \(course.classCode), \(course.modules.count) modules, \(course.totalLessons) lessons")
        .accessibilityHint("Double tap to open gradebook")
    }
}
