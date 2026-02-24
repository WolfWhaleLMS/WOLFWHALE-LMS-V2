import Foundation
import Supabase

// MARK: - PeerReviewViewModel
/// Manages peer review state and logic: assigning reviewers, loading reviews,
/// submitting reviews, and assignment template management.
/// Extracted from AppViewModel+PeerReview.swift to reduce god-class complexity.

@Observable
@MainActor
class PeerReviewViewModel {

    // MARK: - Data

    /// In-memory peer reviews. Populated from Supabase or demo data.
    var peerReviews: [PeerReview] = []

    /// Error surfaced to the UI.
    var dataError: String?

    // MARK: - Assignment Templates (Local)

    /// Saved assignment templates stored via UserDefaults.
    var assignmentTemplates: [AssignmentTemplate] {
        AssignmentTemplateStore.loadTemplates()
    }

    // MARK: - Assign Peer Reviewers

    /// Randomly assigns peer reviewers for an assignment.
    /// Each submission gets `reviewsPerSubmission` reviewers, and no student reviews their own work.
    func assignPeerReviewers(assignmentId: UUID, reviewsPerSubmission: Int = 2, assignments: [Assignment], isDemoMode: Bool) {
        let submitted = assignments.filter { $0.id == assignmentId && $0.isSubmitted }
        let submitterIds: [(studentId: UUID, studentName: String?)] = submitted.compactMap { a in
            guard let studentId = a.studentId else { return nil }
            return (studentId: studentId, studentName: a.studentName)
        }

        var seen = Set<UUID>()
        let uniqueSubmitters = submitterIds.filter { seen.insert($0.studentId).inserted }

        guard uniqueSubmitters.count >= 2 else {
            dataError = "Need at least 2 student submissions to assign peer reviews."
            return
        }

        let assignmentTitle = submitted.first?.title ?? "Assignment"
        var newReviews: [PeerReview] = []
        let allStudentIds = uniqueSubmitters.map(\.studentId)

        for submitter in uniqueSubmitters {
            let candidates = allStudentIds.filter { $0 != submitter.studentId }.shuffled()
            let count = min(reviewsPerSubmission, candidates.count)
            let selectedReviewers = Array(candidates.prefix(count))

            for reviewerId in selectedReviewers {
                let reviewerName = uniqueSubmitters.first(where: { $0.studentId == reviewerId })?.studentName

                let review = PeerReview(
                    assignmentId: assignmentId,
                    reviewerId: reviewerId,
                    submissionOwnerId: submitter.studentId,
                    status: .assigned,
                    reviewerName: reviewerName,
                    submissionOwnerName: submitter.studentName,
                    assignmentTitle: assignmentTitle
                )
                newReviews.append(review)
            }
        }

        peerReviews.removeAll { $0.assignmentId == assignmentId }
        peerReviews.append(contentsOf: newReviews)

        if !isDemoMode {
            Task {
                for review in newReviews {
                    do {
                        try await supabaseClient
                            .from("peer_reviews")
                            .insert([
                                "id": review.id.uuidString,
                                "assignment_id": review.assignmentId.uuidString,
                                "reviewer_id": review.reviewerId.uuidString,
                                "submission_owner_id": review.submissionOwnerId.uuidString,
                                "feedback": "",
                                "status": PeerReviewStatus.assigned.rawValue
                            ])
                            .execute()
                    } catch {
                        #if DEBUG
                        print("[PeerReviewViewModel] Failed to insert peer review: \(error)")
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - Load Peer Reviews (Teacher View)

    func loadPeerReviews(assignmentId: UUID, isDemoMode: Bool) {
        if isDemoMode { return }

        Task {
            do {
                struct PeerReviewDTO: Decodable {
                    let id: UUID
                    let assignmentId: UUID
                    let reviewerId: UUID
                    let submissionOwnerId: UUID
                    let score: Double?
                    let feedback: String
                    let status: String
                    let createdAt: String
                    let completedAt: String?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case assignmentId = "assignment_id"
                        case reviewerId = "reviewer_id"
                        case submissionOwnerId = "submission_owner_id"
                        case score, feedback, status
                        case createdAt = "created_at"
                        case completedAt = "completed_at"
                    }
                }

                let dtos: [PeerReviewDTO] = try await supabaseClient
                    .from("peer_reviews")
                    .select()
                    .eq("assignment_id", value: assignmentId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                let formatter = ISO8601DateFormatter()
                let reviews = dtos.map { dto in
                    PeerReview(
                        id: dto.id,
                        assignmentId: dto.assignmentId,
                        reviewerId: dto.reviewerId,
                        submissionOwnerId: dto.submissionOwnerId,
                        score: dto.score,
                        feedback: dto.feedback,
                        status: PeerReviewStatus(rawValue: dto.status) ?? .assigned,
                        createdDate: formatter.date(from: dto.createdAt) ?? Date(),
                        completedDate: dto.completedAt.flatMap { formatter.date(from: $0) }
                    )
                }

                peerReviews.removeAll { $0.assignmentId == assignmentId }
                peerReviews.append(contentsOf: reviews)
            } catch {
                #if DEBUG
                print("[PeerReviewViewModel] loadPeerReviews failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Load My Peer Reviews (Student View)

    func loadMyPeerReviews(userId: UUID, isDemoMode: Bool) {
        if isDemoMode { return }

        Task {
            do {
                struct PeerReviewDTO: Decodable {
                    let id: UUID
                    let assignmentId: UUID
                    let reviewerId: UUID
                    let submissionOwnerId: UUID
                    let score: Double?
                    let feedback: String
                    let status: String
                    let createdAt: String
                    let completedAt: String?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case assignmentId = "assignment_id"
                        case reviewerId = "reviewer_id"
                        case submissionOwnerId = "submission_owner_id"
                        case score, feedback, status
                        case createdAt = "created_at"
                        case completedAt = "completed_at"
                    }
                }

                let dtos: [PeerReviewDTO] = try await supabaseClient
                    .from("peer_reviews")
                    .select()
                    .eq("reviewer_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                let formatter = ISO8601DateFormatter()
                let reviews = dtos.map { dto in
                    PeerReview(
                        id: dto.id,
                        assignmentId: dto.assignmentId,
                        reviewerId: dto.reviewerId,
                        submissionOwnerId: dto.submissionOwnerId,
                        score: dto.score,
                        feedback: dto.feedback,
                        status: PeerReviewStatus(rawValue: dto.status) ?? .assigned,
                        createdDate: formatter.date(from: dto.createdAt) ?? Date(),
                        completedDate: dto.completedAt.flatMap { formatter.date(from: $0) }
                    )
                }

                peerReviews.removeAll { $0.reviewerId == userId }
                peerReviews.append(contentsOf: reviews)
            } catch {
                #if DEBUG
                print("[PeerReviewViewModel] loadMyPeerReviews failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Submit Peer Review

    func submitPeerReview(reviewId: UUID, score: Double, feedback: String, rubricScores: [UUID: Int]? = nil, isDemoMode: Bool) {
        guard let idx = peerReviews.firstIndex(where: { $0.id == reviewId }) else {
            dataError = "Peer review not found."
            return
        }

        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else {
            dataError = "Please provide feedback for your peer review."
            return
        }

        peerReviews[idx].score = score
        peerReviews[idx].feedback = trimmedFeedback
        peerReviews[idx].rubricScores = rubricScores
        peerReviews[idx].status = .completed
        peerReviews[idx].completedDate = Date()

        if !isDemoMode {
            Task {
                do {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    try await supabaseClient
                        .from("peer_reviews")
                        .update([
                            "score": "\(score)",
                            "feedback": trimmedFeedback,
                            "status": PeerReviewStatus.completed.rawValue,
                            "completed_at": formatter.string(from: Date())
                        ])
                        .eq("id", value: reviewId.uuidString)
                        .execute()
                } catch {
                    if let idx = peerReviews.firstIndex(where: { $0.id == reviewId }) {
                        peerReviews[idx].score = nil
                        peerReviews[idx].feedback = ""
                        peerReviews[idx].status = .assigned
                        peerReviews[idx].completedDate = nil
                    }
                    dataError = "Failed to submit peer review. Please try again."
                    #if DEBUG
                    print("[PeerReviewViewModel] submitPeerReview failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Mark Peer Review In Progress

    func markPeerReviewInProgress(reviewId: UUID, isDemoMode: Bool) {
        guard let idx = peerReviews.firstIndex(where: { $0.id == reviewId }) else { return }
        guard peerReviews[idx].status == .assigned else { return }

        peerReviews[idx].status = .inProgress

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("peer_reviews")
                        .update(["status": PeerReviewStatus.inProgress.rawValue])
                        .eq("id", value: reviewId.uuidString)
                        .execute()
                } catch {
                    #if DEBUG
                    print("[PeerReviewViewModel] markPeerReviewInProgress failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Template Management

    func saveAssignmentAsTemplate(assignmentId: UUID, templateName: String, assignments: [Assignment]) {
        guard let source = assignments.first(where: { $0.id == assignmentId }) else {
            dataError = "Assignment not found."
            return
        }

        let template = AssignmentTemplate(
            name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
            title: source.title,
            instructions: source.instructions,
            points: source.points,
            rubricId: source.rubricId,
            courseName: source.courseName
        )

        AssignmentTemplateStore.addTemplate(template)
    }

    func deleteAssignmentTemplate(id: UUID) {
        AssignmentTemplateStore.removeTemplate(id: id)
    }
}
