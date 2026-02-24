#if canImport(GroupActivities)
import SwiftUI
import GroupActivities
#if canImport(UIKit)
import UIKit
#endif

struct SharePlayView: View {
    let course: Course
    let lesson: Lesson?

    @State private var sharePlayService = SharePlayService()
    @State private var newAnnotationText = ""
    @State private var showAddAnnotation = false
    @State private var hapticTrigger = false
    @State private var showLeaveConfirmation = false
    @State private var selectedQuizAnswer: Int?

    private let sampleQuizOptions = [
        "Mitosis is cell division",
        "Photosynthesis produces oxygen",
        "Gravity pulls objects down",
        "Water boils at 100C"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                sessionStatusHeader
                if sharePlayService.isSessionActive {
                    participantAvatarsRow
                    lessonContentCard
                    pageNavigationControls
                    annotationsSection
                    quizModeSection
                    leaveSessionButton
                } else if sharePlayService.sessionStatus == .waiting {
                    waitingCard
                } else {
                    emptyStateCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("SharePlay Study")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Leave Session?", isPresented: $showLeaveConfirmation) {
            Button("Leave", role: .destructive) {
                Task { await sharePlayService.leaveSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will disconnect from the study group. Others can continue without you.")
        }
        .sheet(isPresented: $showAddAnnotation) {
            addAnnotationSheet
        }
        .overlay {
            if let error = sharePlayService.error {
                errorBanner(error)
            }
        }
    }

    // MARK: - Session Status Header

    private var sessionStatusHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: sharePlayService.sessionStatus == .waiting)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if sharePlayService.isSessionActive {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(sharePlayService.participantCount)")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.indigo.opacity(0.15), in: Capsule())
                    .foregroundStyle(.indigo)
                }
            }

            if sharePlayService.studyState.isQuizMode {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Quiz Mode Active")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.purple.opacity(0.12), in: Capsule())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Participant Avatars Row

    private var participantAvatarsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Participants")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sharePlayService.participants) { participant in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(avatarColor(for: participant.displayName).gradient)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Text(String(participant.displayName.prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 14, height: 14)
                                        .overlay {
                                            Circle()
                                                .stroke(.white, lineWidth: 2)
                                        }
                                }

                            Text(participant.id == sharePlayService.localParticipantId ? "You" : participant.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 56)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Lesson Content Card

    private var lessonContentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: lesson?.type.iconName ?? "book.fill")
                    .foregroundStyle(.indigo)
                Text(lesson?.title ?? course.title)
                    .font(.headline)
                Spacer()
                Text("Page \(sharePlayService.studyState.currentPage + 1)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.indigo.opacity(0.12), in: Capsule())
                    .foregroundStyle(.indigo)
            }

            Divider()

            Text(lesson?.content ?? course.description)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Page Navigation Controls

    private var pageNavigationControls: some View {
        HStack(spacing: 16) {
            Button {
                hapticTrigger.toggle()
                Task { await sharePlayService.previousPage() }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(sharePlayService.studyState.currentPage > 0 ? .indigo : .secondary)
            }
            .disabled(sharePlayService.studyState.currentPage <= 0)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Text("\(sharePlayService.studyState.currentPage + 1)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.indigo)
                .frame(width: 50)

            Button {
                hapticTrigger.toggle()
                Task { await sharePlayService.nextPage() }
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .font(.subheadline.bold())
                    .labelStyle(.trailingIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.indigo.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Annotations Section

    private var annotationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shared Notes")
                    .font(.headline)
                Spacer()
                Button {
                    hapticTrigger.toggle()
                    showAddAnnotation = true
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.indigo.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            if sharePlayService.currentPageAnnotations.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                    Text("No notes on this page yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(sharePlayService.currentPageAnnotations) { annotation in
                    annotationRow(annotation)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func annotationRow(_ annotation: SharedAnnotation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(avatarColor(for: annotation.authorName).gradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(annotation.authorName.prefix(1)).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(annotation.authorName)
                        .font(.caption.bold())
                    Spacer()
                    Text(annotation.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(annotation.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .background(.indigo.opacity(0.06), in: .rect(cornerRadius: 12))
    }

    // MARK: - Quiz Mode Section

    private var quizModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quiz Mode")
                    .font(.headline)
                Spacer()
                Button {
                    hapticTrigger.toggle()
                    Task { await sharePlayService.toggleQuizMode() }
                } label: {
                    Text(sharePlayService.studyState.isQuizMode ? "End Quiz" : "Start Quiz")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            sharePlayService.studyState.isQuizMode
                                ? AnyShapeStyle(.red.opacity(0.15))
                                : AnyShapeStyle(.purple.gradient),
                            in: Capsule()
                        )
                        .foregroundStyle(sharePlayService.studyState.isQuizMode ? .red : .white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            if sharePlayService.studyState.isQuizMode {
                VStack(spacing: 10) {
                    Text("Choose the correct answer:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(Array(sampleQuizOptions.enumerated()), id: \.offset) { index, option in
                        quizOptionButton(index: index, text: option)
                    }

                    // Results summary
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(.purple)
                        Text("\(sharePlayService.quizAnswerCount) of \(sharePlayService.participantCount) answered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if sharePlayService.hasSubmittedAnswer {
                            Label("Submitted", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top, 6)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.bubble.fill")
                        .foregroundStyle(.secondary)
                    Text("Start a quiz so everyone answers the same question together")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func quizOptionButton(index: Int, text: String) -> some View {
        let isSelected = selectedQuizAnswer == index
        let isSubmitted = sharePlayService.hasSubmittedAnswer

        return Button {
            guard !isSubmitted else { return }
            hapticTrigger.toggle()
            selectedQuizAnswer = index
            Task { await sharePlayService.submitQuizAnswer(answerIndex: index) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? Color.purple : Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(Character(UnicodeScalar(65 + index)!))")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                isSelected
                    ? AnyShapeStyle(.purple.opacity(0.1))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .purple : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitted)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Leave Session Button

    private var leaveSessionButton: some View {
        Button {
            hapticTrigger.toggle()
            showLeaveConfirmation = true
        } label: {
            Label("Leave Study Session", systemImage: "xmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.red.opacity(0.1), in: Capsule())
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    // MARK: - Waiting Card

    private var waitingCard: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.indigo)

            Text("Waiting for Others to Join")
                .font(.headline)

            Text("Share this session via FaceTime or Messages. Other participants will see the invite automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                hapticTrigger.toggle()
                Task { await sharePlayService.endSession() }
            } label: {
                Text("Cancel")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(30)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Empty State (No Session)

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "shareplay")
                .font(.system(size: 56))
                .foregroundStyle(.indigo.gradient)
                .symbolEffect(.pulse, isActive: false)

            Text("Study Together with SharePlay")
                .font(.title3.bold())

            Text("Start a FaceTime call and invite classmates to study \"\(course.title)\" together in real time. Everyone sees the same page, shares notes, and takes quizzes together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    hapticTrigger.toggle()
                    Task {
                        await sharePlayService.startSession(
                            courseId: course.id,
                            courseTitle: course.title,
                            lessonId: lesson?.id,
                            lessonTitle: lesson?.title
                        )
                    }
                } label: {
                    Label("Start SharePlay Session", systemImage: "shareplay")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.indigo.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .disabled(sharePlayService.isLoading)

                faceTimePrompt
            }

            if sharePlayService.isLoading {
                ProgressView("Preparing session...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - FaceTime Prompt

    private var faceTimePrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "video.fill")
                .foregroundStyle(.green)
            Text("Start a FaceTime call first, then tap Start SharePlay")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.green.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    // MARK: - Add Annotation Sheet

    private var addAnnotationSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo.gradient)

                Text("Add a Shared Note")
                    .font(.title3.bold())

                Text("Your note will appear on page \(sharePlayService.studyState.currentPage + 1) for all participants.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Write your note...", text: $newAnnotationText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))

                Button {
                    guard !newAnnotationText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    hapticTrigger.toggle()
                    let text = newAnnotationText
                    newAnnotationText = ""
                    showAddAnnotation = false
                    Task { await sharePlayService.addAnnotation(text: text) }
                } label: {
                    Label("Share Note", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.indigo.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .disabled(newAnnotationText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(30)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newAnnotationText = ""
                        showAddAnnotation = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    sharePlayService.error = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: sharePlayService.error)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch sharePlayService.sessionStatus {
        case .idle: .secondary
        case .waiting: .orange
        case .active: .indigo
        case .ended: .red
        }
    }

    private var statusIcon: String {
        switch sharePlayService.sessionStatus {
        case .idle: "shareplay"
        case .waiting: "clock.fill"
        case .active: "shareplay"
        case .ended: "xmark.circle.fill"
        }
    }

    private var statusTitle: String {
        switch sharePlayService.sessionStatus {
        case .idle: "No Active Session"
        case .waiting: "Waiting for Participants"
        case .active: "Study Session Active"
        case .ended: "Session Ended"
        }
    }

    private var statusSubtitle: String {
        switch sharePlayService.sessionStatus {
        case .idle: "Start a SharePlay session to study together"
        case .waiting: "Invite classmates via FaceTime"
        case .active: "\(sharePlayService.participantCount) participant\(sharePlayService.participantCount == 1 ? "" : "s") studying"
        case .ended: "The session has ended"
        }
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.indigo, .purple, .teal, .orange, .red, .cyan, .mint, .blue]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Trailing Icon Label Style

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
#endif
