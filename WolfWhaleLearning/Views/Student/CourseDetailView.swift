import SwiftUI

struct CourseDetailView: View {
    let courseId: UUID
    let viewModel: AppViewModel

    /// Use the live version from the viewModel so lesson-completion updates are reflected
    /// immediately (progress bar, lesson checkmarks). Falls back to an empty course if removed.
    private var course: Course {
        viewModel.courses.first(where: { $0.id == courseId }) ?? Course(
            id: courseId, title: "Course", description: "", teacherName: "",
            iconSystemName: "book.fill", colorName: "blue", modules: [],
            enrolledStudentCount: 0, progress: 0, classCode: ""
        )
    }

    init(course: Course, viewModel: AppViewModel) {
        self.courseId = course.id
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                discussionLink
                modulesSection
            }
        }
        .background { HolographicBackground() }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(height: 120)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: course.iconSystemName)
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                        Text(course.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

            HStack(spacing: 20) {
                infoChip(icon: "person.fill", text: course.teacherName)
                infoChip(icon: "person.3.fill", text: "\(course.enrolledStudentCount) students")
            }
            .padding(.horizontal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.subheadline.bold())
                    Text("\(course.completedLessons) of \(course.totalLessons) lessons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatRing(progress: course.progress, color: Theme.courseColor(course.colorName), lineWidth: 5, size: 44)
            }
            .padding(16)
            .glassCard(cornerRadius: 14)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var discussionLink: some View {
        NavigationLink {
            DiscussionForumView(course: course, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Discussion Forum")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Ask questions and share ideas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityLabel("Discussion Forum")
        .accessibilityHint("Double tap to open course discussions")
    }

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Modules")
                .font(.headline)
                .padding(.horizontal)

            if course.modules.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No modules yet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Course content will appear here once the teacher adds modules.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal)
            }

            ForEach(course.modules) { module in
                VStack(alignment: .leading, spacing: 10) {
                    Text(module.title)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 4)

                    ForEach(module.lessons) { lesson in
                        NavigationLink(value: LessonNav(lesson: lesson, course: course)) {
                            lessonRow(lesson)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 20)
        .navigationDestination(for: LessonNav.self) { nav in
            LessonView(lesson: nav.lesson, course: nav.course, viewModel: viewModel)
        }
        .navigationDestination(for: ARResource.self) { resource in
            ARResourceDetailView(resource: resource, viewModel: viewModel)
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack(spacing: 12) {
            Image(systemName: lesson.type.iconName)
                .font(.subheadline)
                .foregroundStyle(lesson.isCompleted ? .green : .secondary)
                .frame(width: 32, height: 32)
                .background(lesson.isCompleted ? Color.green.opacity(0.15) : Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(lesson.type.rawValue)
                    Text("·")
                    Text("\(lesson.duration) min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()

            if lesson.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lesson.title), \(lesson.type.rawValue), \(lesson.duration) minutes\(lesson.isCompleted ? ", completed" : "")")
        .accessibilityHint(lesson.isCompleted ? "" : "Double tap to open lesson")
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

nonisolated struct LessonNav: Hashable, Sendable {
    let lesson: Lesson
    let course: Course
}
