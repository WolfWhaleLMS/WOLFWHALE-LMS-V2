#if canImport(GroupActivities)
import GroupActivities
import Foundation

// MARK: - Group Activity Definition

nonisolated struct StudySessionActivity: GroupActivity {
    let courseId: UUID
    let courseTitle: String
    let lessonId: UUID?
    let lessonTitle: String?

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Study: \(courseTitle)"
        if let lessonTitle {
            meta.subtitle = lessonTitle
        }
        meta.type = .generic
        meta.supportsContinuationOnTV = false
        return meta
    }
}

// MARK: - Shared Session State

nonisolated struct StudySessionState: Codable, Sendable {
    var currentPage: Int
    var annotations: [SharedAnnotation]
    var activeParticipantCount: Int
    var isQuizMode: Bool
    var quizAnswers: [UUID: Int] // participantId -> answer index

    init(
        currentPage: Int = 0,
        annotations: [SharedAnnotation] = [],
        activeParticipantCount: Int = 1,
        isQuizMode: Bool = false,
        quizAnswers: [UUID: Int] = [:]
    ) {
        self.currentPage = currentPage
        self.annotations = annotations
        self.activeParticipantCount = activeParticipantCount
        self.isQuizMode = isQuizMode
        self.quizAnswers = quizAnswers
    }
}

// MARK: - Shared Annotation

nonisolated struct SharedAnnotation: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let authorName: String
    let text: String
    let timestamp: Date
    let pageIndex: Int

    init(
        id: UUID = UUID(),
        authorName: String,
        text: String,
        timestamp: Date = Date(),
        pageIndex: Int
    ) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.timestamp = timestamp
        self.pageIndex = pageIndex
    }
}

// MARK: - Session Status

nonisolated enum SharePlaySessionStatus: Sendable {
    case idle
    case waiting
    case active
    case ended
}

// MARK: - SharePlay Message Types

nonisolated enum SharePlayMessage: Codable, Sendable {
    case stateUpdate(StudySessionState)
    case annotationAdded(SharedAnnotation)
    case pageChanged(Int)
    case quizToggled(Bool)
    case quizAnswerSubmitted(participantId: UUID, answerIndex: Int)
    case participantJoined(name: String)
    case participantLeft(name: String)
}

// MARK: - Participant Info

nonisolated struct SharePlayParticipant: Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let joinedAt: Date

    init(id: UUID = UUID(), displayName: String, joinedAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = joinedAt
    }
}
#endif
