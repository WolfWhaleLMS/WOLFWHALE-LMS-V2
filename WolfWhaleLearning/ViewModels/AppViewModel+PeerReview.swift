import Foundation
import Supabase

// MARK: - Peer Review Backing Store
// Swift extensions cannot add stored properties.
// We use a MainActor-isolated static dictionary keyed by ObjectIdentifier
// to associate peer review data with each AppViewModel instance.

@MainActor
private enum PeerReviewStore {
    /// Peer reviews keyed by the AppViewModel's ObjectIdentifier.
    static var reviews: [ObjectIdentifier: [PeerReview]] = [:]

    static func get(for vm: AppViewModel) -> [PeerReview] {
        reviews[ObjectIdentifier(vm)] ?? []
    }

    static func set(_ value: [PeerReview], for vm: AppViewModel) {
        reviews[ObjectIdentifier(vm)] = value
    }
}

// MARK: - Peer Review & Assignment Templates/Cloning

extension AppViewModel {

    // MARK: - Peer Review Storage

    /// In-memory peer reviews. Populated from Supabase or demo data.
    var peerReviews: [PeerReview] {
        get { PeerReviewStore.get(for: self) }
        set { PeerReviewStore.set(newValue, for: self) }
    }

    // MARK: - Assignment Templates (Local)

    /// Saved assignment templates stored via UserDefaults.
    var assignmentTemplates: [AssignmentTemplate] {
        AssignmentTemplateStore.loadTemplates()
    }

    // MARK: - Duplicate Assignment

    /// Duplicates an existing assignment, optionally into a different course.
    /// Copies all fields except: id (new UUID), dueDate (set one week from now),
    /// submissions, grades, studentId, studentName.
    /// Returns the new Assignment on success, nil on failure.
    @discardableResult
    func duplicateAssignment(assignmentId: UUID, newCourseId: UUID? = nil) async throws -> Assignment? {
        guard let source = assignments.first(where: { $0.id == assignmentId }) else {
            dataError = "Assignment not found."
            return nil
        }

        let targetCourseId = newCourseId ?? source.courseId
        let targetCourseName = courses.first(where: { $0.id == targetCourseId })?.title ?? source.courseName
        let newDueDate = Date().addingTimeInterval(7 * 86400) // one week from now

        let duplicated = Assignment(
            id: UUID(),
            title: "\(source.title) (Copy)",
            courseId: targetCourseId,
            courseName: targetCourseName,
            instructions: source.instructions,
            dueDate: newDueDate,
            points: source.points,
            isSubmitted: false,
            submission: nil,
            grade: nil,
            feedback: nil,
            xpReward: source.xpReward,
            attachmentURLs: nil,
            rubricId: source.rubricId,
            studentId: nil,
            studentName: nil
        )

        if !isDemoMode {
            guard let user = currentUser else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                tenantId: nil,
                courseId: targetCourseId,
                title: duplicated.title,
                description: nil,
                instructions: duplicated.instructions,
                type: nil,
                createdBy: user.id,
                dueDate: formatter.string(from: newDueDate),
                availableDate: nil,
                maxPoints: duplicated.points,
                submissionType: nil,
                allowLateSubmission: nil,
                lateSubmissionDays: nil,
                status: nil
            )
            try await DataService.shared.createAssignment(dto)
            let courseIds = courses.map(\.id)
            assignments = try await DataService.shared.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
        } else {
            assignments.append(duplicated)
        }

        return duplicated
    }

    // MARK: - Save as Template

    /// Saves an assignment as a reusable template in local storage.
    func saveAssignmentAsTemplate(assignmentId: UUID, templateName: String) {
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

    /// Creates a new assignment from a template in the given course.
    @discardableResult
    func createAssignmentFromTemplate(_ template: AssignmentTemplate, courseId: UUID, dueDate: Date) async throws -> Assignment? {
        let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"

        let newAssignment = Assignment(
            id: UUID(),
            title: template.title,
            courseId: courseId,
            courseName: courseName,
            instructions: template.instructions,
            dueDate: dueDate,
            points: template.points,
            isSubmitted: false,
            submission: nil,
            grade: nil,
            feedback: nil,
            xpReward: template.points / 2,
            attachmentURLs: nil,
            rubricId: template.rubricId,
            studentId: nil,
            studentName: nil
        )

        if !isDemoMode {
            guard let user = currentUser else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                tenantId: nil,
                courseId: courseId,
                title: template.title,
                description: nil,
                instructions: template.instructions,
                type: nil,
                createdBy: user.id,
                dueDate: formatter.string(from: dueDate),
                availableDate: nil,
                maxPoints: template.points,
                submissionType: nil,
                allowLateSubmission: nil,
                lateSubmissionDays: nil,
                status: nil
            )
            try await DataService.shared.createAssignment(dto)
            let courseIds = courses.map(\.id)
            assignments = try await DataService.shared.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
        } else {
            assignments.append(newAssignment)
        }

        return newAssignment
    }

    /// Removes a template from local storage.
    func deleteAssignmentTemplate(id: UUID) {
        AssignmentTemplateStore.removeTemplate(id: id)
    }

    // MARK: - Peer Review: Assign Reviewers

    /// Randomly assigns peer reviewers for an assignment.
    /// Each submission gets `reviewsPerSubmission` reviewers, and no student reviews their own work.
    func assignPeerReviewers(assignmentId: UUID, reviewsPerSubmission: Int = 2) {
        // Gather students who have submitted this assignment
        let submitted = assignments.filter { $0.id == assignmentId && $0.isSubmitted }
        let submitterIds: [(studentId: UUID, studentName: String?)] = submitted.compactMap { a in
            guard let studentId = a.studentId else { return nil }
            return (studentId: studentId, studentName: a.studentName)
        }

        // Deduplicate by studentId
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
            // Pick reviewers: everyone except the submitter, shuffled
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

        // Remove existing reviews for this assignment, then add new ones
        var current = peerReviews
        current.removeAll { $0.assignmentId == assignmentId }
        current.append(contentsOf: newReviews)
        peerReviews = current

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
                        print("[AppViewModel] Failed to insert peer review: \(error)")
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - Peer Review: Load Reviews

    /// Loads peer reviews for a specific assignment (teacher view).
    func loadPeerReviews(assignmentId: UUID) {
        if isDemoMode {
            // Demo reviews are already in memory from assignPeerReviewers
            return
        }

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

                var current = peerReviews
                current.removeAll { $0.assignmentId == assignmentId }
                current.append(contentsOf: reviews)
                peerReviews = current
            } catch {
                #if DEBUG
                print("[AppViewModel] loadPeerReviews failed: \(error)")
                #endif
            }
        }
    }

    /// Loads peer reviews assigned TO the current student.
    func loadMyPeerReviews() {
        guard let userId = currentUser?.id else { return }

        if isDemoMode {
            // In demo mode, reviews are already in memory
            return
        }

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

                // Replace only reviews for this reviewer
                var current = peerReviews
                current.removeAll { $0.reviewerId == userId }
                current.append(contentsOf: reviews)
                peerReviews = current
            } catch {
                #if DEBUG
                print("[AppViewModel] loadMyPeerReviews failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Peer Review: Submit Review

    /// Submits a peer review with score and feedback.
    func submitPeerReview(reviewId: UUID, score: Double, feedback: String, rubricScores: [UUID: Int]? = nil) {
        var current = peerReviews
        guard let idx = current.firstIndex(where: { $0.id == reviewId }) else {
            dataError = "Peer review not found."
            return
        }

        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else {
            dataError = "Please provide feedback for your peer review."
            return
        }

        current[idx].score = score
        current[idx].feedback = trimmedFeedback
        current[idx].rubricScores = rubricScores
        current[idx].status = .completed
        current[idx].completedDate = Date()
        peerReviews = current

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
                    // Revert on failure
                    var reverted = peerReviews
                    if let idx = reverted.firstIndex(where: { $0.id == reviewId }) {
                        reverted[idx].score = nil
                        reverted[idx].feedback = ""
                        reverted[idx].status = .assigned
                        reverted[idx].completedDate = nil
                        peerReviews = reverted
                    }
                    dataError = "Failed to submit peer review. Please try again."
                    #if DEBUG
                    print("[AppViewModel] submitPeerReview failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Peer Review: Mark In Progress

    /// Marks a peer review as in progress when the student starts reviewing.
    func markPeerReviewInProgress(reviewId: UUID) {
        var current = peerReviews
        guard let idx = current.firstIndex(where: { $0.id == reviewId }) else { return }
        guard current[idx].status == .assigned else { return }

        current[idx].status = .inProgress
        peerReviews = current

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
                    print("[AppViewModel] markPeerReviewInProgress failed: \(error)")
                    #endif
                }
            }
        }
    }
}
