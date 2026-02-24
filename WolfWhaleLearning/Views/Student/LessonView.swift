import SwiftUI
import Combine

struct LessonView: View {
    let lesson: Lesson
    let course: Course
    let viewModel: AppViewModel
    @State private var isCompleted: Bool
    @State private var showConfetti = false
    @State private var currentSlide = 0
    @State private var arViewModel = ARLibraryViewModel()
    @State private var progressService = VideoProgressService()
    @State private var videoProgress: Double = 0
    @State private var videoCompletionTriggered = false
    @State private var hapticTrigger = false
    @Environment(\.dismiss) private var dismiss

    init(lesson: Lesson, course: Course, viewModel: AppViewModel) {
        self.lesson = lesson
        self.course = course
        self.viewModel = viewModel
        _isCompleted = State(initialValue: lesson.isCompleted)
    }

    /// Splits lesson content into slides using `---` as a separator.
    /// If no separators exist, splits by paragraphs (double newlines) grouping 2-3 per slide.
    private var slides: [String] {
        let raw = lesson.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return ["No content available."] }

        // First try splitting by --- (markdown horizontal rule)
        let bySeparator = raw.components(separatedBy: "\n---\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if bySeparator.count > 1 {
            return bySeparator
        }

        // Also try --- on its own line (without surrounding newlines on both sides)
        let byLooseSeparator = raw.components(separatedBy: "---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if byLooseSeparator.count > 1 {
            return byLooseSeparator
        }

        // Fall back to splitting by paragraphs, grouping ~2 per slide
        let paragraphs = raw.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.count <= 1 {
            return [raw]
        }

        // Group 2 paragraphs per slide
        var result: [String] = []
        var i = 0
        while i < paragraphs.count {
            let end = min(i + 2, paragraphs.count)
            let group = paragraphs[i..<end].joined(separator: "\n\n")
            result.append(group)
            i = end
        }
        return result
    }

    /// Resources attached to the current slide.
    private var currentSlideResources: [SlideResource] {
        lesson.slideResources.filter { $0.slideIndex == currentSlide }
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
        VStack(spacing: 0) {
            if isVideoLesson {
                videoLessonBody
            } else {
                slideLessonBody
            }
        }
        .background { HolographicBackground() }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showConfetti {
                confettiOverlay
            }
        }
        .onAppear {
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
            if updatedProgress >= 0.9, !videoCompletionTriggered {
                videoCompletionTriggered = true
                triggerCompletion()
            }
        }
        #if canImport(UIKit)
        .sensoryFeedback(.success, trigger: isCompleted)
        #endif
    }

    // MARK: - Slide-Based Lesson Body

    private var slideLessonBody: some View {
        let totalSlides = slides.count

        return VStack(spacing: 0) {
            // Progress bar at top
            slideProgressBar(current: currentSlide, total: totalSlides)

            // Slide content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    // Slide indicator
                    HStack {
                        Text("Slide \(currentSlide + 1) of \(totalSlides)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Current slide content
                    slideContentCard(text: slides[currentSlide])
                        .id(currentSlide) // force re-render for transition

                    // Slide resources (attached tools)
                    if !currentSlideResources.isEmpty {
                        slideResourcesRow
                    }

                    // Related AR section
                    relatedARSection

                    if isCompleted {
                        lessonCompleteBanner
                    }
                }
                .padding()
            }

            // Navigation buttons
            slideNavigationBar(current: currentSlide, total: totalSlides)
        }
    }

    // MARK: - Slide Progress Bar

    private func slideProgressBar(current: Int, total: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.courseColor(course.colorName), Theme.courseColor(course.colorName).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (Double(current + 1) / Double(total)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Slide Content Card

    private func slideContentCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.body)
                .foregroundStyle(Color(.label))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Slide Navigation Bar

    private func slideNavigationBar(current: Int, total: Int) -> some View {
        let isFirst = current == 0
        let isLast = current == total - 1
        let onlyOneSlide = total == 1

        return HStack(spacing: 12) {
            // Back button
            Button {
                hapticTrigger.toggle()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentSlide = max(0, currentSlide - 1)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .disabled(isFirst)
            .opacity(isFirst ? 0.4 : 1)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            // Next / Complete button
            if isLast || onlyOneSlide {
                Button {
                    hapticTrigger.toggle()
                    if !isCompleted {
                        triggerCompletion()
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "flag.checkered")
                        Text(isCompleted ? "Done" : "Complete")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCompleted ? .green : Theme.courseColor(course.colorName))
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            } else {
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentSlide = min(total - 1, currentSlide + 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.courseColor(course.colorName))
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Video Lesson Body

    private var videoLessonBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if let url = resolvedVideoURL {
                    VideoPlayerView(url: url, title: lesson.title, lessonId: lesson.id)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                }

                videoProgressCard

                // Show text content below video as supplementary notes
                if !lesson.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    supplementaryContentSection
                }

                relatedARSection

                if isCompleted {
                    lessonCompleteBanner
                }
            }
            .padding()
        }
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
        .glassCard(cornerRadius: 16)
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
        .glassCard(cornerRadius: 16)
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
        .glassCard(cornerRadius: 16)
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
                .glassCard(cornerRadius: 16)
            }
        }
    }

    // MARK: - Slide Resources Row

    private var slideResourcesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Slide Resources", systemImage: "book.and.wrench.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currentSlideResources) { resource in
                        NavigationLink {
                            resourceDestinationView(for: resource.resourceTitle)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: resource.resourceIcon)
                                    .font(.callout)
                                    .foregroundStyle(.purple)
                                Text(resource.resourceTitle)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(.label))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassCard(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Resource Destination View

    @ViewBuilder
    private func resourceDestinationView(for title: String) -> some View {
        switch title {
        case "Flashcard Creator": FlashcardCreatorView()
        case "Unit Converter": UnitConverterView()
        case "Typing Tutor": TypingTutorView()
        case "AI Study Assistant": AIAssistantView()
        case "Math Quiz": MathQuizView()
        case "Fraction Builder": FractionBuilderView()
        case "Geometry Explorer": GeometryExplorerView()
        case "Periodic Table": PeriodicTableView()
        case "Human Body": HumanBodyView()
        case "Word Builder": WordBuilderView()
        case "Spelling Bee": SpellingBeeView()
        case "Grammar Quest": GrammarQuestView()
        case "French Vocab": FrenchVocabView()
        case "French Verbs": FrenchVerbView()
        case "Canadian History": CanadianHistoryTimelineView()
        case "Canadian Geography": CanadianGeographyView()
        case "Indigenous Peoples": IndigenousPeoplesView()
        case "World Map Quiz": WorldMapQuizView()
        case "Chess": ChessGameView()
        default: Text("Coming Soon")
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

    // MARK: - Completion

    private func triggerCompletion() {
        guard !isCompleted else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isCompleted = true
            showConfetti = true
        }
        viewModel.completeLesson(lesson, in: course)
        if isVideoLesson {
            progressService.markAsWatched(lessonId: lesson.id)
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showConfetti = false
            }
        }
    }
}
