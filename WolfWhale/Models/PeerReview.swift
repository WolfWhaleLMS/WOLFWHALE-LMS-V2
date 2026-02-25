import Foundation

// MARK: - Peer Review Status

nonisolated enum PeerReviewStatus: String, CaseIterable, Sendable, Codable, Identifiable {
    case assigned = "assigned"
    case inProgress = "in_progress"
    case completed = "completed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .assigned: "Assigned"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .assigned: "clock.fill"
        case .inProgress: "pencil.circle.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .assigned: "orange"
        case .inProgress: "blue"
        case .completed: "green"
        }
    }
}

// MARK: - Peer Review

nonisolated struct PeerReview: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var assignmentId: UUID
    var reviewerId: UUID              // student doing the review
    var submissionOwnerId: UUID       // student whose work is being reviewed
    var score: Double?
    var feedback: String
    var rubricScores: [UUID: Int]?    // criterionId -> points awarded
    var status: PeerReviewStatus
    var createdDate: Date
    var completedDate: Date?

    // Resolved display names (not stored in DB, populated at read time)
    var reviewerName: String?
    var submissionOwnerName: String?
    var assignmentTitle: String?

    init(
        id: UUID = UUID(),
        assignmentId: UUID,
        reviewerId: UUID,
        submissionOwnerId: UUID,
        score: Double? = nil,
        feedback: String = "",
        rubricScores: [UUID: Int]? = nil,
        status: PeerReviewStatus = .assigned,
        createdDate: Date = Date(),
        completedDate: Date? = nil,
        reviewerName: String? = nil,
        submissionOwnerName: String? = nil,
        assignmentTitle: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.reviewerId = reviewerId
        self.submissionOwnerId = submissionOwnerId
        self.score = score
        self.feedback = feedback
        self.rubricScores = rubricScores
        self.status = status
        self.createdDate = createdDate
        self.completedDate = completedDate
        self.reviewerName = reviewerName
        self.submissionOwnerName = submissionOwnerName
        self.assignmentTitle = assignmentTitle
    }
}
