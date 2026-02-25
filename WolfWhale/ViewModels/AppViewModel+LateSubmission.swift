import Foundation

// MARK: - Late Submission Penalties & Resubmission Logic (Delegating to GradesViewModel)

extension AppViewModel {

    // MARK: - Late Penalty Calculation (delegates to sub-VM)

    func adjustedGradeWithLatePenalty(rawGradePercent: Double, for assignment: Assignment) -> Double {
        gradesVM.adjustedGradeWithLatePenalty(rawGradePercent: rawGradePercent, for: assignment)
    }

    func adjustedScoreWithLatePenalty(rawScore: Double, for assignment: Assignment) -> Double {
        gradesVM.adjustedScoreWithLatePenalty(rawScore: rawScore, for: assignment)
    }

    func latePenaltySummary(for assignment: Assignment) -> String? {
        gradesVM.latePenaltySummary(for: assignment)
    }

    // MARK: - Grade with Late Penalty (Teacher Flow)

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
            adjustedScore = gradesVM.adjustedScoreWithLatePenalty(rawScore: rawScore, for: assignment)
            let penaltySummary = gradesVM.latePenaltySummary(for: assignment) ?? ""
            let baseFeedback = feedback ?? ""
            adjustedFeedback = baseFeedback.isEmpty ? penaltySummary : "\(baseFeedback)\n\n\(penaltySummary)"
        } else {
            adjustedScore = rawScore
            adjustedFeedback = feedback
        }

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

    func resubmitAssignment(assignmentId: UUID, newText: String) {
        guard let index = assignments.firstIndex(where: { $0.id == assignmentId }) else { return }
        let assignment = assignments[index]

        guard assignment.canResubmit else { return }

        let previousSubmission = assignment.submission
        let previousGrade = assignment.grade
        let previousFeedback = assignment.feedback
        let previousIsSubmitted = assignment.isSubmitted
        let previousAttachmentURLs = assignment.attachmentURLs
        let previousResubmissionHistory = assignments[index].resubmissionHistory
        let previousResubmissionCount = assignments[index].resubmissionCount

        let historyEntry = ResubmissionHistoryEntry(
            id: UUID(),
            submissionText: assignment.submission,
            grade: assignment.grade,
            feedback: assignment.feedback,
            submittedAt: Date().addingTimeInterval(-1),
            gradedAt: Date()
        )
        assignments[index].resubmissionHistory.append(historyEntry)
        assignments[index].resubmissionCount += 1

        assignments[index].submission = newText
        assignments[index].grade = nil
        assignments[index].feedback = nil
        assignments[index].isSubmitted = true

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
                    if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) {
                        assignments[idx].submission = previousSubmission
                        assignments[idx].grade = previousGrade
                        assignments[idx].feedback = previousFeedback
                        assignments[idx].isSubmitted = previousIsSubmitted
                        assignments[idx].attachmentURLs = previousAttachmentURLs
                        assignments[idx].resubmissionHistory = previousResubmissionHistory
                        assignments[idx].resubmissionCount = previousResubmissionCount
                    }
                    submissionError = UserFacingError.sanitize(error).localizedDescription
                    #if DEBUG
                    print("[AppViewModel] resubmitAssignment failed: \(error)")
                    #endif
                }
            }
        }

        syncProfile()
    }

    // MARK: - Assignment Creation with Late Policy & Resubmission

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
