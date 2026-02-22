import Foundation

// MARK: - Late Submission Penalties & Resubmission Logic

extension AppViewModel {

    // MARK: - Late Penalty Calculation

    /// Calculates the adjusted grade after applying the late penalty for an assignment.
    /// - Parameters:
    ///   - rawGradePercent: The raw grade as a percentage (0-100) before penalty.
    ///   - assignment: The assignment to check late penalty rules against.
    /// - Returns: The adjusted grade percentage after applying late penalties.
    func adjustedGradeWithLatePenalty(rawGradePercent: Double, for assignment: Assignment) -> Double {
        guard assignment.latePenaltyType != .none else { return rawGradePercent }

        let daysLate = assignment.daysLate
        guard daysLate > 0 else { return rawGradePercent }

        // If past max late days, no credit
        if daysLate > assignment.maxLateDays {
            return 0
        }

        switch assignment.latePenaltyType {
        case .none:
            return rawGradePercent
        case .percentPerDay:
            let penalty = Double(daysLate) * assignment.latePenaltyPerDay
            return max(rawGradePercent - penalty, 0)
        case .flatDeduction:
            let maxPts = Double(assignment.points)
            guard maxPts > 0 else { return rawGradePercent }
            let flatDeduction = Double(daysLate) * assignment.latePenaltyPerDay
            let deductionPercent = (flatDeduction / maxPts) * 100
            return max(rawGradePercent - deductionPercent, 0)
        case .noCredit:
            return 0
        }
    }

    /// Calculates the late penalty as raw points deducted from a score.
    /// - Parameters:
    ///   - rawScore: The raw score (points, not percentage) before penalty.
    ///   - assignment: The assignment with late policy rules.
    /// - Returns: The adjusted score after applying late penalties.
    func adjustedScoreWithLatePenalty(rawScore: Double, for assignment: Assignment) -> Double {
        let maxPts = Double(assignment.points)
        guard maxPts > 0 else { return rawScore }

        let rawPercent = (rawScore / maxPts) * 100
        let adjustedPercent = adjustedGradeWithLatePenalty(rawGradePercent: rawPercent, for: assignment)
        return (adjustedPercent / 100) * maxPts
    }

    /// Returns a human-readable summary of the late penalty applied to an assignment.
    /// - Parameter assignment: The assignment to describe.
    /// - Returns: A display string or nil if no penalty applies.
    func latePenaltySummary(for assignment: Assignment) -> String? {
        guard assignment.latePenaltyType != .none, assignment.daysLate > 0 else { return nil }

        let daysLate = assignment.daysLate
        let dayLabel = daysLate == 1 ? "day" : "days"

        if daysLate > assignment.maxLateDays {
            return "Submission is \(daysLate) \(dayLabel) late (exceeds \(assignment.maxLateDays)-day limit). No credit awarded."
        }

        switch assignment.latePenaltyType {
        case .none:
            return nil
        case .percentPerDay:
            let penalty = min(Double(daysLate) * assignment.latePenaltyPerDay, 100)
            return "Late penalty: -\(Int(penalty))% (\(daysLate) \(dayLabel) x \(Int(assignment.latePenaltyPerDay))% per day)"
        case .flatDeduction:
            let deduction = Double(daysLate) * assignment.latePenaltyPerDay
            return "Late penalty: -\(Int(deduction)) points (\(daysLate) \(dayLabel) x \(Int(assignment.latePenaltyPerDay)) pts per day)"
        case .noCredit:
            return "Late submission receives no credit."
        }
    }

    // MARK: - Grade with Late Penalty (Teacher Flow)

    /// Grades a submission with automatic late penalty application.
    /// This wraps the existing gradeSubmission flow, applying late deductions before saving.
    /// - Parameters:
    ///   - assignmentId: The assignment being graded.
    ///   - studentId: The student being graded (optional, resolved from assignment if nil).
    ///   - rawScore: The raw score before late penalty (points, not percentage).
    ///   - letterGrade: The letter grade (will be recalculated after penalty if needed).
    ///   - feedback: Teacher feedback text.
    ///   - applyLatePenalty: Whether to automatically apply the late penalty. Default true.
    func gradeWithLatePenalty(
        assignmentId: UUID,
        studentId: UUID?,
        rawScore: Double,
        letterGrade: String,
        feedback: String?,
        applyLatePenalty: Bool = true
    ) async throws {
        guard let assignment = assignments.first(where: { $0.id == assignmentId && $0.studentId == studentId }) ??
              assignments.first(where: { $0.id == assignmentId }) else {
            gradeError = "Assignment not found"
            throw NSError(domain: "AppViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Assignment not found"])
        }

        let adjustedScore: Double
        let adjustedFeedback: String?

        if applyLatePenalty && assignment.latePenaltyType != .none && assignment.daysLate > 0 {
            adjustedScore = adjustedScoreWithLatePenalty(rawScore: rawScore, for: assignment)
            let penaltySummary = latePenaltySummary(for: assignment) ?? ""
            let baseFeedback = feedback ?? ""
            adjustedFeedback = baseFeedback.isEmpty ? penaltySummary : "\(baseFeedback)\n\n\(penaltySummary)"
        } else {
            adjustedScore = rawScore
            adjustedFeedback = feedback
        }

        // Recalculate letter grade based on adjusted score
        let maxPts = Double(assignment.points)
        let adjustedPercent = maxPts > 0 ? (adjustedScore / maxPts) * 100 : 0
        let adjustedLetterGrade = gradeService.letterGrade(from: adjustedPercent)

        try await gradeSubmission(
            assignmentId: assignmentId,
            studentId: studentId,
            score: adjustedScore,
            letterGrade: adjustedLetterGrade,
            feedback: adjustedFeedback
        )
    }

    // MARK: - Resubmission Logic

    /// Handles a resubmission for a previously graded assignment.
    /// Archives the current submission/grade into resubmission history, then resets submission state.
    /// - Parameters:
    ///   - assignmentId: The assignment being resubmitted.
    ///   - newText: The new submission text.
    func resubmitAssignment(assignmentId: UUID, newText: String) {
        guard let index = assignments.firstIndex(where: { $0.id == assignmentId }) else { return }
        let assignment = assignments[index]

        // Verify resubmission is allowed
        guard assignment.canResubmit else { return }

        // Save previous state for rollback
        let previousSubmission = assignment.submission
        let previousGrade = assignment.grade
        let previousFeedback = assignment.feedback
        let previousIsSubmitted = assignment.isSubmitted
        let previousAttachmentURLs = assignment.attachmentURLs
        let previousResubmissionHistory = assignments[index].resubmissionHistory
        let previousResubmissionCount = assignments[index].resubmissionCount

        // Archive current submission into history
        let historyEntry = ResubmissionHistoryEntry(
            id: UUID(),
            submissionText: assignment.submission,
            grade: assignment.grade,
            feedback: assignment.feedback,
            submittedAt: Date().addingTimeInterval(-1), // approximate original submission time
            gradedAt: Date()
        )
        assignments[index].resubmissionHistory.append(historyEntry)
        assignments[index].resubmissionCount += 1

        // Reset submission state for re-grading
        assignments[index].submission = newText
        assignments[index].grade = nil
        assignments[index].feedback = nil
        assignments[index].isSubmitted = true

        // Extract and store attachment URLs from the new submission text
        let urls = Assignment.extractAttachmentURLs(from: newText)
        if !urls.isEmpty {
            assignments[index].attachmentURLs = urls
        } else {
            assignments[index].attachmentURLs = nil
        }

        if !isDemoMode, let user = currentUser {
            Task {
                do {
                    try await dataService.submitAssignment(assignmentId: assignmentId, studentId: user.id, content: newText)
                } catch {
                    // Revert all optimistic updates — resubmission was NOT persisted
                    if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) {
                        assignments[idx].submission = previousSubmission
                        assignments[idx].grade = previousGrade
                        assignments[idx].feedback = previousFeedback
                        assignments[idx].isSubmitted = previousIsSubmitted
                        assignments[idx].attachmentURLs = previousAttachmentURLs
                        assignments[idx].resubmissionHistory = previousResubmissionHistory
                        assignments[idx].resubmissionCount = previousResubmissionCount
                    }
                    submissionError = "Failed to resubmit assignment: \(error.localizedDescription)"
                    #if DEBUG
                    print("[AppViewModel] resubmitAssignment failed: \(error)")
                    #endif
                }
            }
        }

        syncProfile()
    }

    // MARK: - Assignment Creation with Late Policy & Resubmission

    /// Creates an assignment with late penalty and resubmission settings.
    /// This extends the existing createAssignment by including late policy and resubmission options.
    func createAssignmentWithPolicy(
        courseId: UUID,
        title: String,
        instructions: String,
        dueDate: Date,
        points: Int,
        latePenaltyType: LatePenaltyType,
        latePenaltyPerDay: Double,
        maxLateDays: Int,
        allowResubmission: Bool,
        maxResubmissions: Int,
        resubmissionDeadline: Date?
    ) async throws {
        guard let user = currentUser else { return }

        // Input validation
        let sanitizedTitle = InputValidator.sanitizeText(title)
        let titleResult = InputValidator.validateAssignmentTitle(sanitizedTitle)
        guard titleResult.valid else {
            dataError = titleResult.message
            throw ValidationError.invalidInput(titleResult.message)
        }
        guard InputValidator.validatePoints(points) else {
            dataError = "Points must be between 0 and 1000."
            throw ValidationError.invalidInput("Points must be between 0 and 1000.")
        }
        let dueDateResult = InputValidator.validateDueDate(dueDate)
        guard dueDateResult.valid else {
            dataError = dueDateResult.message
            throw ValidationError.invalidInput(dueDateResult.message)
        }
        let sanitizedInstructions = InputValidator.sanitizeHTML(InputValidator.sanitizeText(instructions))

        let xpReward = points / 2
        let allowLate = latePenaltyType != .noCredit
        let lateDays = latePenaltyType == .none ? nil : maxLateDays

        if !isDemoMode {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                tenantId: nil,
                courseId: courseId,
                title: sanitizedTitle,
                description: nil,
                instructions: sanitizedInstructions,
                type: nil,
                createdBy: user.id,
                dueDate: formatter.string(from: dueDate),
                availableDate: nil,
                maxPoints: points,
                submissionType: nil,
                allowLateSubmission: allowLate,
                lateSubmissionDays: lateDays,
                status: nil
            )
            try await dataService.createAssignment(dto)
            let courseIds = courses.map(\.id)
            var fetched = try await dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)

            // Apply local-only late policy & resubmission fields to newly created assignment
            for i in fetched.indices where fetched[i].title == sanitizedTitle && fetched[i].courseId == courseId {
                fetched[i].latePenaltyType = latePenaltyType
                fetched[i].latePenaltyPerDay = latePenaltyPerDay
                fetched[i].maxLateDays = maxLateDays
                fetched[i].allowResubmission = allowResubmission
                fetched[i].maxResubmissions = maxResubmissions
                fetched[i].resubmissionDeadline = resubmissionDeadline
            }
            assignments = fetched
        } else {
            let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"
            var newAssignment = Assignment(
                id: UUID(), title: sanitizedTitle, courseId: courseId, courseName: courseName,
                instructions: sanitizedInstructions, dueDate: dueDate, points: points,
                isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: xpReward,
                studentId: nil, studentName: nil
            )
            newAssignment.latePenaltyType = latePenaltyType
            newAssignment.latePenaltyPerDay = latePenaltyPerDay
            newAssignment.maxLateDays = maxLateDays
            newAssignment.allowResubmission = allowResubmission
            newAssignment.maxResubmissions = maxResubmissions
            newAssignment.resubmissionDeadline = resubmissionDeadline
            assignments.append(newAssignment)
        }
    }

    // MARK: - Update Late Policy on Existing Assignment

    /// Updates the late policy and resubmission settings on an existing assignment (local state).
    func updateAssignmentPolicy(
        assignmentId: UUID,
        latePenaltyType: LatePenaltyType,
        latePenaltyPerDay: Double,
        maxLateDays: Int,
        allowResubmission: Bool,
        maxResubmissions: Int,
        resubmissionDeadline: Date?
    ) {
        for index in assignments.indices where assignments[index].id == assignmentId {
            assignments[index].latePenaltyType = latePenaltyType
            assignments[index].latePenaltyPerDay = latePenaltyPerDay
            assignments[index].maxLateDays = maxLateDays
            assignments[index].allowResubmission = allowResubmission
            assignments[index].maxResubmissions = maxResubmissions
            assignments[index].resubmissionDeadline = resubmissionDeadline
        }
    }
}
