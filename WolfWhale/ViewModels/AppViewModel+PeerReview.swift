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

// MARK: - Peer Review & Assignment Templates/Cloning (Delegating to PeerReviewViewModel)

extension AppViewModel {

    // MARK: - Peer Review Storage (backward compatible)

    /// In-memory peer reviews. Populated from Supabase or demo data.
    /// This bridges to the sub-ViewModel while keeping the static storage for backward compatibility.
    var peerReviews: [PeerReview] {
        get { peerReviewVM.peerReviews }
        set { peerReviewVM.peerReviews = newValue }
    }

    // MARK: - Assignment Templates (Local)

    /// Saved assignment templates stored via UserDefaults.
    var assignmentTemplates: [AssignmentTemplate] {
        peerReviewVM.assignmentTemplates
    }

    // MARK: - Duplicate Assignment

    /// Duplicates an existing assignment, optionally into a different course.
    @discardableResult
    func duplicateAssignment(assignmentId: UUID, newCourseId: UUID? = nil) async throws -> Assignment? {
        guard let source = assignments.first(where: { $0.id == assignmentId }) else {
            dataError = "Assignment not found."
            return nil
        }

        let targetCourseId = newCourseId ?? source.courseId
        let targetCourseName = courses.first(where: { $0.id == targetCourseId })?.title ?? source.courseName
        let newDueDate = Date().addingTimeInterval(7 * 86400)

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

    // MARK: - Save as Template (delegates to sub-VM)

    func saveAssignmentAsTemplate(assignmentId: UUID, templateName: String) {
        peerReviewVM.saveAssignmentAsTemplate(assignmentId: assignmentId, templateName: templateName, assignments: assignments)
        if let error = peerReviewVM.dataError {
            dataError = error
        }
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
        peerReviewVM.deleteAssignmentTemplate(id: id)
    }

    // MARK: - Peer Review: Assign Reviewers (delegates to sub-VM)

    func assignPeerReviewers(assignmentId: UUID, reviewsPerSubmission: Int = 2) {
        peerReviewVM.assignPeerReviewers(
            assignmentId: assignmentId,
            reviewsPerSubmission: reviewsPerSubmission,
            assignments: assignments,
            isDemoMode: isDemoMode
        )
        if let error = peerReviewVM.dataError {
            dataError = error
        }
    }

    // MARK: - Peer Review: Load Reviews (delegates to sub-VM)

    func loadPeerReviews(assignmentId: UUID) {
        peerReviewVM.loadPeerReviews(assignmentId: assignmentId, isDemoMode: isDemoMode)
    }

    /// Loads peer reviews assigned TO the current student.
    func loadMyPeerReviews() {
        guard let userId = currentUser?.id else { return }
        peerReviewVM.loadMyPeerReviews(userId: userId, isDemoMode: isDemoMode)
    }

    // MARK: - Peer Review: Submit Review (delegates to sub-VM)

    func submitPeerReview(reviewId: UUID, score: Double, feedback: String, rubricScores: [UUID: Int]? = nil) {
        peerReviewVM.submitPeerReview(
            reviewId: reviewId,
            score: score,
            feedback: feedback,
            rubricScores: rubricScores,
            isDemoMode: isDemoMode
        )
        if let error = peerReviewVM.dataError {
            dataError = error
        }
    }

    // MARK: - Peer Review: Mark In Progress (delegates to sub-VM)

    func markPeerReviewInProgress(reviewId: UUID) {
        peerReviewVM.markPeerReviewInProgress(reviewId: reviewId, isDemoMode: isDemoMode)
    }
}
