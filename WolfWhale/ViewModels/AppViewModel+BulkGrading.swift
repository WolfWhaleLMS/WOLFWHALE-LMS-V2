import Foundation

// MARK: - Teacher: Bulk Grading & CSV Export (Delegating CSV export to GradesViewModel)

extension AppViewModel {

    // MARK: - Bulk Grade Submissions

    /// Grades multiple submissions at once. Each entry contains the assignment id, student id,
    /// raw score (points earned, NOT percentage), and optional feedback text.
    /// Returns the number of successfully graded submissions.
    /// Throws if ALL submissions fail; partial failures are reported via gradeError.
    ///
    /// Note: This method stays in the AppViewModel extension because it relies heavily on
    /// `gradeSubmission`, `refreshData`, `assignments`, `currentUser`, and `isDemoMode`,
    /// which are all owned by AppViewModel.
    func bulkGradeSubmissions(grades: [(assignmentId: UUID, studentId: UUID?, score: Double, feedback: String)]) async throws -> Int {
        isLoading = true
        gradeError = nil
        defer { isLoading = false }

        var successCount = 0
        var failedCount = 0
        var failedStudentNames: [String] = []
        let service = DataService.shared
        let audit = AuditLogService()

        for entry in grades {
            guard let assignment = assignments.first(where: { $0.id == entry.assignmentId && $0.studentId == entry.studentId }) ??
                  assignments.first(where: { $0.id == entry.assignmentId }) else {
                continue
            }

            let maxPossible = Double(assignment.points)
            guard entry.score >= 0, entry.score <= maxPossible else { continue }

            let percentage = maxPossible > 0 ? (entry.score / maxPossible) * 100 : 0
            let letterGrade = gradeService.letterGrade(from: percentage)
            let trimmedFeedback = entry.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedStudentId = entry.studentId ?? assignment.studentId ?? currentUser?.id ?? UUID()

            if isDemoMode {
                if let index = assignments.firstIndex(where: { $0.id == entry.assignmentId && $0.studentId == entry.studentId }) ??
                   assignments.firstIndex(where: { $0.id == entry.assignmentId }) {
                    assignments[index].grade = percentage
                    assignments[index].feedback = trimmedFeedback.isEmpty ? nil : trimmedFeedback
                }
                successCount += 1
                continue
            }

            do {
                try await service.gradeSubmission(
                    studentId: resolvedStudentId,
                    courseId: assignment.courseId,
                    assignmentId: entry.assignmentId,
                    score: entry.score,
                    maxScore: maxPossible,
                    letterGrade: letterGrade,
                    feedback: trimmedFeedback.isEmpty ? "" : trimmedFeedback
                )
                successCount += 1

                await audit.log(
                    AuditAction.gradeChange,
                    entityType: AuditEntityType.grade,
                    entityId: entry.assignmentId.uuidString,
                    details: [
                        "student_id": resolvedStudentId.uuidString,
                        "score": "\(entry.score)",
                        "max_score": "\(maxPossible)",
                        "letter_grade": letterGrade,
                        "graded_by": currentUser?.id.uuidString ?? "unknown",
                        "bulk_grade": "true"
                    ]
                )
            } catch {
                failedCount += 1
                failedStudentNames.append(assignment.studentName ?? "Unknown Student")
                #if DEBUG
                print("[AppViewModel] Bulk grade failed for assignment \(entry.assignmentId): \(error)")
                #endif
            }
        }

        if successCount > 0 {
            refreshData()
        }

        // Surface partial failures so the teacher knows which grades were NOT saved
        if failedCount > 0 {
            let names = failedStudentNames.prefix(3).joined(separator: ", ")
            let extra = failedCount > 3 ? " and \(failedCount - 3) more" : ""
            gradeError = "\(failedCount) grade(s) failed to save (e.g. \(names)\(extra)). \(successCount) succeeded."
            if successCount == 0 {
                throw NSError(domain: "AppViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "All bulk grade submissions failed."])
            }
        }

        return successCount
    }

    // MARK: - Export Grades to CSV (delegates to GradesViewModel)

    /// Generates a CSV file with graded assignment data for a given course.
    /// Columns: Student Name, Assignment, Grade, Letter Grade, Submitted Date, Feedback
    /// Returns the file URL in the temporary directory, or nil if no data.
    func exportGradesToCSV(courseId: UUID, startDate: Date? = nil, endDate: Date? = nil) -> URL? {
        gradesVM.exportGradesToCSV(
            courseId: courseId,
            assignments: assignments,
            courses: courses,
            startDate: startDate,
            endDate: endDate
        )
    }
}
