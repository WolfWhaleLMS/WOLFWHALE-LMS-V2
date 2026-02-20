import SwiftUI

struct CoursesListView: View {
    let viewModel: AppViewModel
    @State private var searchText = ""

    private var filteredCourses: [Course] {
        if searchText.isEmpty { return viewModel.courses }
        return viewModel.courses.filter {
            $0.title.localizedStandardContains(searchText) ||
            $0.teacherName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(filteredCourses) { course in
                        NavigationLink(value: course) {
                            courseRow(course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Courses")
            .searchable(text: $searchText, prompt: "Search courses")
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(course: course, viewModel: viewModel)
            }
        }
    }

    private func courseRow(_ course: Course) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
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
                Text(course.teacherName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ProgressView(value: course.progress)
                        .tint(Theme.courseColor(course.colorName))
                    Text("\(Int(course.progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
