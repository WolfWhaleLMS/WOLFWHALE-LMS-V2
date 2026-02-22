import SwiftUI
import Combine

struct LessonView: View {
    let lesson: Lesson
    let course: Course
    let viewModel: AppViewModel
    @State private var isCompleted: Bool
    @State private var showConfetti = false
    @State private var reachedEnd = false
    @State private var arViewModel = ARLibraryViewModel()
    @State private var progressService = VideoProgressService()
    @State private var videoProgress: Double = 0
    @State private var videoCompletionTriggered = false
    @Environment(\.dismiss) private var dismiss

    init(lesson: Lesson, course: Course, viewModel: AppViewModel) {
        self.lesson = lesson
        self.course = course
        self.viewModel = viewModel
        _isCompleted = State(initialValue: lesson.isCompleted)
    }

    /// Whether this lesson should display as a video lesson.
    private var isVideoLesson: Bool {
        lesson.type == .video && resolvedVideoURL != nil
    }

    /// Parses the lesson's `videoURL` string into a `URL`, if valid.
    private var resolvedVideoURL: URL? {
        guard let urlString = lesson.videoURL,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if isVideoLesson {
                    videoSection
                    videoProgressCard
                } else {
                    contentSection
                }

                // Show text content below video when available as supplementary notes
                if isVideoLesson && !lesson.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    supplementaryContentSection
                }

                relatedARSection

                if isCompleted {
                    lessonCompleteBanner
                }

                // Invisible marker at the very end of content (non-video completion trigger)
                if !isVideoLesson {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            guard !isCompleted && !reachedEnd else { return }
                            reachedEnd = true
                            Task {
                                try? await Task.sleep(for: .seconds(1))
                                guard !isCompleted else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    isCompleted = true
                                    showConfetti = true
                                }
                                viewModel.completeLesson(lesson, in: course)
                                try? await Task.sleep(for: .seconds(2))
                                showConfetti = false
                            }
                        }
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
        .onAppear {
            // Restore saved video progress on appear
            if isVideoLesson {
                videoProgress = progressService.getCompletionPercentage(lessonId: lesson.id)
            }
        }
        .onReceive(
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        ) { _ in
            guard isVideoLesson, !isCompleted else { return }
            let updatedProgress = progressService.getCompletionPercentage(lessonId: lesson.id)
            withAnimation(.easeInOut(duration: 0.3)) {
                videoProgress = updatedProgress
            }
            // Auto-complete when video is >90% watched
            if updatedProgress >= 0.9, !videoCompletionTriggered {
                videoCompletionTriggered = true
                triggerVideoCompletion()
            }
        }
        #if canImport(UIKit)
        .sensoryFeedback(.success, trigger: isCompleted)
        #endif
    }

    // MARK: - Header Card

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
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("\(lesson.duration) min")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Video Section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = resolvedVideoURL {
                VideoPlayerView(url: url, title: lesson.title, lessonId: lesson.id)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - Video Progress Card

    private var videoProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(Theme.courseColor(course.colorName))
                Text("Video Progress")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(videoProgress * 100))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(videoProgress >= 0.9 ? .green : Theme.courseColor(course.colorName))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            videoProgress >= 0.9
                                ? Color.green
                                : Theme.courseColor(course.colorName)
                        )
                        .frame(width: geometry.size.width * min(videoProgress, 1.0), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: videoProgress)
                }
            }
            .frame(height: 6)

            if videoProgress >= 0.9 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Video watched — lesson complete!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Text("Watch at least 90% to complete this lesson")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    // MARK: - Text Content Section (primary, for non-video lessons)

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lesson.content)
                .font(.body)
                .foregroundStyle(Color(.label))
                .lineSpacing(4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Supplementary Content (text notes below video)

    private var supplementaryContentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lesson Notes", systemImage: "doc.text")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))
            Text(lesson.content)
                .font(.body)
                .foregroundStyle(Color(.label))
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    // MARK: - Lesson Complete Banner

    private var lessonCompleteBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Lesson Complete!")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("Well done!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.green.opacity(0.1), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.green.opacity(0.3), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Related AR Section

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

    // MARK: - Confetti Overlay

    private var confettiOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: showConfetti)
            Text("Lesson Complete!")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity)
    }

    // MARK: - Video Completion

    private func triggerVideoCompletion() {
        guard !isCompleted else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isCompleted = true
            showConfetti = true
        }
        viewModel.completeLesson(lesson, in: course)
        progressService.markAsWatched(lessonId: lesson.id)
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showConfetti = false
            }
        }
    }
}
