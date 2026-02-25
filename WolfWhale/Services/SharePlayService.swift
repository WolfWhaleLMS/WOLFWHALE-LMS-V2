#if canImport(GroupActivities)
import GroupActivities
import Observation
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class SharePlayService {

    // MARK: - Published State

    var error: String?
    var isLoading = false
    var sessionStatus: SharePlaySessionStatus = .idle
    var studyState = StudySessionState()
    var participants: [SharePlayParticipant] = []
    var localParticipantId = UUID()
    var localDisplayName: String = UIDevice.current.name

    var isSessionActive: Bool { sessionStatus == .active }
    var participantCount: Int { participants.count }

    // MARK: - Private Session State

    private var groupSession: GroupSession<StudySessionActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored nonisolated(unsafe) private var messageTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var sessionTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        observeGroupSessions()
    }

    deinit {
        messageTask?.cancel()
        sessionTask?.cancel()
    }

    // MARK: - Prepare & Activate

    /// Prepares and activates a study session activity for the given course and optional lesson.
    func startSession(courseId: UUID, courseTitle: String, lessonId: UUID? = nil, lessonTitle: String? = nil) async {
        isLoading = true
        error = nil

        let activity = StudySessionActivity(
            courseId: courseId,
            courseTitle: courseTitle,
            lessonId: lessonId,
            lessonTitle: lessonTitle
        )

        do {
            let activated = try await activity.prepareForActivation()
            switch activated {
            case .activationPreferred:
                _ = try await activity.activate()
                sessionStatus = .waiting
                #if DEBUG
                print("[SharePlay] Activity activated, waiting for participants")
                #endif
            case .activationDisabled:
                error = "SharePlay is not available. Start a FaceTime call first."
                sessionStatus = .idle
            case .cancelled:
                sessionStatus = .idle
            @unknown default:
                sessionStatus = .idle
            }
        } catch {
            self.error = "Failed to start SharePlay: \(error.localizedDescription)"
            sessionStatus = .idle
            #if DEBUG
            print("[SharePlay] Activation error: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Observe Group Sessions

    /// Listens for incoming group sessions from the system.
    private func observeGroupSessions() {
        sessionTask = Task { [weak self] in
            guard let self else { return }
            for await session in StudySessionActivity.sessions() {
                await self.configureSession(session)
            }
        }
    }

    /// Configures a newly received group session: joins, sets up messenger, and begins listening.
    private func configureSession(_ session: GroupSession<StudySessionActivity>) {
        // Clean up any previous session
        cleanup()

        groupSession = session
        let newMessenger = GroupSessionMessenger(session: session)
        messenger = newMessenger

        // Observe session state changes
        session.$state
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .waiting:
                        self.sessionStatus = .waiting
                    case .joined:
                        self.sessionStatus = .active
                        // Add self as participant
                        let localParticipant = SharePlayParticipant(
                            id: self.localParticipantId,
                            displayName: self.localDisplayName
                        )
                        if !self.participants.contains(where: { $0.id == localParticipant.id }) {
                            self.participants.append(localParticipant)
                        }
                        self.studyState.activeParticipantCount = self.participants.count
                    case .invalidated:
                        self.sessionStatus = .ended
                        self.cleanup()
                    @unknown default:
                        break
                    }
                }
            }
            .store(in: &subscriptions)

        // Observe active participants
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.studyState.activeParticipantCount = activeParticipants.count
                }
            }
            .store(in: &subscriptions)

        // Join the session
        session.join()
        sessionStatus = .active

        // Begin listening for messages
        listenForMessages(messenger: newMessenger)

        // Broadcast that we joined
        Task {
            await sendMessage(.participantJoined(name: localDisplayName))
        }

        #if DEBUG
        print("[SharePlay] Session configured and joined")
        #endif
    }

    // MARK: - Message Handling

    /// Listens for incoming SharePlay messages from other participants.
    private func listenForMessages(messenger: GroupSessionMessenger) {
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            for await (message, _) in messenger.messages(of: SharePlayMessage.self) {
                guard let self, !Task.isCancelled else { break }
                await self.handleMessage(message)
            }
        }
    }

    /// Processes a received message and updates local state accordingly.
    private func handleMessage(_ message: SharePlayMessage) {
        switch message {
        case .stateUpdate(let newState):
            studyState = newState

        case .annotationAdded(let annotation):
            if !studyState.annotations.contains(where: { $0.id == annotation.id }) {
                studyState.annotations.append(annotation)
            }

        case .pageChanged(let page):
            studyState.currentPage = page

        case .quizToggled(let isQuiz):
            studyState.isQuizMode = isQuiz
            if !isQuiz {
                studyState.quizAnswers.removeAll()
            }

        case .quizAnswerSubmitted(let participantId, let answerIndex):
            studyState.quizAnswers[participantId] = answerIndex

        case .participantJoined(let name):
            let newParticipant = SharePlayParticipant(displayName: name)
            if !participants.contains(where: { $0.displayName == name }) {
                participants.append(newParticipant)
            }
            studyState.activeParticipantCount = participants.count

        case .participantLeft(let name):
            participants.removeAll { $0.displayName == name }
            studyState.activeParticipantCount = participants.count
        }
    }

    /// Sends a message to all participants in the current group session.
    private func sendMessage(_ message: SharePlayMessage) async {
        guard let messenger else { return }
        do {
            try await messenger.send(message)
        } catch {
            #if DEBUG
            print("[SharePlay] Failed to send message: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Page Navigation

    /// Navigates to the specified page and syncs across all participants.
    func goToPage(_ page: Int) async {
        studyState.currentPage = page
        await sendMessage(.pageChanged(page))
    }

    /// Advances to the next page and syncs.
    func nextPage() async {
        await goToPage(studyState.currentPage + 1)
    }

    /// Goes back one page and syncs.
    func previousPage() async {
        guard studyState.currentPage > 0 else { return }
        await goToPage(studyState.currentPage - 1)
    }

    // MARK: - Annotations

    /// Adds a shared annotation visible to all participants.
    func addAnnotation(text: String) async {
        let annotation = SharedAnnotation(
            authorName: localDisplayName,
            text: text,
            pageIndex: studyState.currentPage
        )
        studyState.annotations.append(annotation)
        await sendMessage(.annotationAdded(annotation))
    }

    /// Returns annotations for the current page.
    var currentPageAnnotations: [SharedAnnotation] {
        studyState.annotations.filter { $0.pageIndex == studyState.currentPage }
    }

    // MARK: - Quiz Mode

    /// Toggles quiz mode for all participants.
    func toggleQuizMode() async {
        let newValue = !studyState.isQuizMode
        studyState.isQuizMode = newValue
        if !newValue {
            studyState.quizAnswers.removeAll()
        }
        await sendMessage(.quizToggled(newValue))
    }

    /// Submits a quiz answer and broadcasts to all participants.
    func submitQuizAnswer(answerIndex: Int) async {
        studyState.quizAnswers[localParticipantId] = answerIndex
        await sendMessage(.quizAnswerSubmitted(participantId: localParticipantId, answerIndex: answerIndex))
    }

    /// The number of participants who have answered the current quiz question.
    var quizAnswerCount: Int { studyState.quizAnswers.count }

    /// Whether the local participant has already submitted an answer.
    var hasSubmittedAnswer: Bool { studyState.quizAnswers[localParticipantId] != nil }

    // MARK: - Leave & End Session

    /// Leaves the current group session without ending it for others.
    func leaveSession() async {
        await sendMessage(.participantLeft(name: localDisplayName))
        groupSession?.leave()
        cleanup()
    }

    /// Ends the session for all participants.
    func endSession() async {
        await sendMessage(.participantLeft(name: localDisplayName))
        groupSession?.end()
        cleanup()
    }

    // MARK: - Cleanup

    /// Tears down all session state, subscriptions, and tasks.
    private func cleanup() {
        messageTask?.cancel()
        messageTask = nil
        subscriptions.removeAll()
        messenger = nil
        groupSession = nil
        participants.removeAll()
        studyState = StudySessionState()
        sessionStatus = .idle
        error = nil
    }

    // MARK: - Sync Full State

    /// Broadcasts the entire current study state to all participants. Useful after a
    /// significant local change or when a new participant needs to catch up.
    func broadcastFullState() async {
        await sendMessage(.stateUpdate(studyState))
    }
}
#endif
