import Foundation

// MARK: - Teacher: Bulk Grading & CSV Export

extension AppViewModel {

    // MARK: - Bulk Grade Submissions

    /// Grades multiple submissions at once. Each entry contains the assignment id, student id,
    /// raw score (points earned, NOT percentage), and optional feedback text.
    /// Returns the number of successfully graded submissions.
    func bulkGradeSubmissions(grades: [(assignmentId: UUID, studentId: UUID?, score: Double, feedback: String)]) async throws -> Int {
        isLoading = true
        gradeError = nil
        defer { isLoading = false }

        var successCount = 0
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
                #if DEBUG
                print("[AppViewModel] Bulk grade failed for assignment \(entry.assignmentId): \(error)")
                #endif
            }
        }

        if successCount > 0 {
            refreshData()
        }

        return successCount
    }

    // MARK: - Export Grades to CSV

    /// Generates a CSV file with graded assignment data for a given course.
    /// Columns: Student Name, Assignment, Grade, Letter Grade, Submitted Date, Feedback
    /// Returns the file URL in the temporary directory, or nil if no data.
    func exportGradesToCSV(courseId: UUID, startDate: Date? = nil, endDate: Date? = nil) -> URL? {
        let courseAssignments = assignments.filter { $0.courseId == courseId && $0.isSubmitted }

        let filtered: [Assignment]
        if let start = startDate, let end = endDate {
            filtered = courseAssignments.filter { $0.dueDate >= start && $0.dueDate <= end }
        } else if let start = startDate {
            filtered = courseAssignments.filter { $0.dueDate >= start }
        } else if let end = endDate {
            filtered = courseAssignments.filter { $0.dueDate <= end }
        } else {
            filtered = courseAssignments
        }

        guard !filtered.isEmpty else { return nil }

        let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Course"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var csv = "Student Name,Assignment,Grade,Letter Grade,Submitted Date,Feedback\n"

        for assignment in filtered {
            let studentName = (assignment.studentName ?? "Unknown Student")
                .replacingOccurrences(of: ",", with: " ")
            let title = assignment.title
                .replacingOccurrences(of: ",", with: " ")
            let gradeStr: String
            let letterGrade: String
            if let grade = assignment.grade {
                gradeStr = String(format: "%.1f%%", grade)
                letterGrade = gradeService.letterGrade(from: grade)
            } else {
                gradeStr = "Not Graded"
                letterGrade = "--"
            }
            let dateStr = dateFormatter.string(from: assignment.dueDate)
            let feedbackStr = (assignment.feedback ?? "")
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")

            csv += "\(studentName),\(title),\(gradeStr),\(letterGrade),\(dateStr),\(feedbackStr)\n"
        }

        let sanitizedName = courseName.replacingOccurrences(of: " ", with: "_")
        let fileName = "Grades_\(sanitizedName)_\(dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "_")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            #if DEBUG
            print("[AppViewModel] CSV export failed: \(error)")
            #endif
            return nil
        }
    }
}
