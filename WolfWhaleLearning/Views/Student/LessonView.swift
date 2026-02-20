import SwiftUI

struct LessonView: View {
    let lesson: Lesson
    let course: Course
    let viewModel: AppViewModel
    @State private var isCompleted: Bool
    @State private var showConfetti = false
    @State private var arViewModel = ARLibraryViewModel()
    @Environment(\.dismiss) private var dismiss

    init(lesson: Lesson, course: Course, viewModel: AppViewModel) {
        self.lesson = lesson
        self.course = course
        self.viewModel = viewModel
        _isCompleted = State(initialValue: lesson.isCompleted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                contentSection
                relatedARSection

                if !isCompleted {
                    completeButton
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showConfetti {
                confettiOverlay
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: lesson.type.iconName)
                .font(.title2)
                .foregroundStyle(Theme.courseColor(course.colorName))
                .frame(width: 48, height: 48)
                .background(Theme.courseColor(course.colorName).opacity(0.15), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.type.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.courseColor(course.colorName))
                Text(course.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(lesson.duration) min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("+\(lesson.xpReward) XP")
                }
                .font(.caption.bold())
                .foregroundStyle(.purple)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lesson.content)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var completeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isCompleted = true
                showConfetti = true
            }
            viewModel.completeLesson(lesson, in: course)
            Task {
                try? await Task.sleep(for: .seconds(2))
                showConfetti = false
            }
        } label: {
            Label("Mark as Complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .sensoryFeedback(.success, trigger: isCompleted)
    }

    private var relatedARSection: some View {
        let keywords = lesson.title.split(separator: " ").map(String.init) + [course.title]
        let matched = arViewModel.resourcesMatching(keywords: keywords)
        return Group {
            if !matched.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Related AR Experiences", systemImage: "arkit")
                        .font(.headline)
                    ForEach(matched) { resource in
                        NavigationLink(value: resource) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.courseColor(resource.colorName).gradient)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: resource.iconSystemName)
                                            .font(.body)
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.title)
                                        .font(.subheadline.bold())
                                    Text(resource.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Theme.courseColor(resource.colorName).opacity(0.08), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
        }
    }

    private var confettiOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: showConfetti)
            Text("Lesson Complete!")
                .font(.title2.bold())
            Text("+\(lesson.xpReward) XP")
                .font(.headline)
                .foregroundStyle(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity)
    }
}
