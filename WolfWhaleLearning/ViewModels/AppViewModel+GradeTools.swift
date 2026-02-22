import Foundation

// MARK: - Grade Curve/Scaling + Plagiarism Detection

extension AppViewModel {

    // MARK: - Grade Statistics

    /// Computes grade statistics for a specific assignment across all student submissions.
    func gradeStatistics(for assignmentId: UUID) -> GradeStatistics {
        let assignmentSubmissions = assignments.filter {
            $0.id == assignmentId && $0.isSubmitted && $0.grade != nil
        }
        let scores = assignmentSubmissions.compactMap(\.grade)
        return GradeStatistics(scores: scores)
    }

    /// Computes grade statistics for all graded submissions in a course for a specific assignment title.
    func gradeStatisticsForAssignment(title: String, courseId: UUID) -> GradeStatistics {
        let matchingSubmissions = assignments.filter {
            $0.courseId == courseId && $0.title == title && $0.isSubmitted && $0.grade != nil
        }
        let scores = matchingSubmissions.compactMap(\.grade)
        return GradeStatistics(scores: scores)
    }

    // MARK: - Apply Flat Curve

    /// Adds a flat number of points to all graded submissions for the given assignment.
    /// Scores are capped at 100.
    func applyFlatCurve(assignmentTitle: String, courseId: UUID, points: Double) async {
        isLoading = true
        defer { isLoading = false }

        // Snapshot grades before modification for rollback
        let previousGrades: [UUID: Double?] = Dictionary(
            assignments.enumerated()
                .filter { $0.element.courseId == courseId && $0.element.title == assignmentTitle && $0.element.isSubmitted && $0.element.grade != nil }
                .map { ($0.element.id, $0.element.grade) },
            uniquingKeysWith: { first, _ in first }
        )

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(currentGrade + points, 100.0)
            assignments[i].grade = max(newGrade, 0)

            if !isDemoMode {
                let score = (assignments[i].grade ?? 0) / 100.0 * Double(assignments[i].points)
                let letter = gradeService.letterGrade(from: assignments[i].grade ?? 0)
                do {
                    try await gradeSubmission(
                        assignmentId: assignments[i].id,
                        studentId: assignments[i].studentId,
                        score: score,
                        letterGrade: letter,
                        feedback: assignments[i].feedback
                    )
                } catch {
                    // Revert ALL grades to pre-curve state on any failure
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply flat curve: \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Percentage Boost

    /// Multiplies all graded submissions by a factor (e.g., 1.1 = 10% boost).
    /// Scores are capped at 100.
    func applyPercentageBoost(assignmentTitle: String, courseId: UUID, factor: Double) async {
        isLoading = true
        defer { isLoading = false }

        // Snapshot grades before modification for rollback
        let previousGrades: [UUID: Double?] = Dictionary(
            assignments.enumerated()
                .filter { $0.element.courseId == courseId && $0.element.title == assignmentTitle && $0.element.isSubmitted && $0.element.grade != nil }
                .map { ($0.element.id, $0.element.grade) },
            uniquingKeysWith: { first, _ in first }
        )

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(currentGrade * factor, 100.0)
            assignments[i].grade = max(newGrade, 0)

            if !isDemoMode {
                let score = (assignments[i].grade ?? 0) / 100.0 * Double(assignments[i].points)
                let letter = gradeService.letterGrade(from: assignments[i].grade ?? 0)
                do {
                    try await gradeSubmission(
                        assignmentId: assignments[i].id,
                        studentId: assignments[i].studentId,
                        score: score,
                        letterGrade: letter,
                        feedback: assignments[i].feedback
                    )
                } catch {
                    // Revert ALL grades to pre-curve state on any failure
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply percentage boost: \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Square Root Curve

    /// Applies sqrt curve: newScore = sqrt(original) * 10.
    /// Original is treated as a percentage (0-100), result is capped at 100.
    func applySquareRootCurve(assignmentTitle: String, courseId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Snapshot grades before modification for rollback
        let previousGrades: [UUID: Double?] = Dictionary(
            assignments.enumerated()
                .filter { $0.element.courseId == courseId && $0.element.title == assignmentTitle && $0.element.isSubmitted && $0.element.grade != nil }
                .map { ($0.element.id, $0.element.grade) },
            uniquingKeysWith: { first, _ in first }
        )

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(sqrt(currentGrade) * 10.0, 100.0)
            assignments[i].grade = max(newGrade, 0)

            if !isDemoMode {
                let score = (assignments[i].grade ?? 0) / 100.0 * Double(assignments[i].points)
                let letter = gradeService.letterGrade(from: assignments[i].grade ?? 0)
                do {
                    try await gradeSubmission(
                        assignmentId: assignments[i].id,
                        studentId: assignments[i].studentId,
                        score: score,
                        letterGrade: letter,
                        feedback: assignments[i].feedback
                    )
                } catch {
                    // Revert ALL grades to pre-curve state on any failure
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply square root curve: \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Bell Curve

    /// Scales grades to a target mean and standard deviation using z-score normalization.
    /// New score = targetMean + (z * targetStdDev), clamped to [0, 100].
    func applyBellCurve(assignmentTitle: String, courseId: UUID, targetMean: Double, targetStdDev: Double) async {
        isLoading = true
        defer { isLoading = false }

        let matchingIndices = assignments.indices.filter {
            assignments[$0].courseId == courseId &&
            assignments[$0].title == assignmentTitle &&
            assignments[$0].isSubmitted &&
            assignments[$0].grade != nil
        }

        let scores = matchingIndices.compactMap { assignments[$0].grade }
        guard scores.count >= 2 else { return }

        let currentMean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0.0) { $0 + pow($1 - currentMean, 2) } / Double(scores.count)
        let currentStdDev = sqrt(variance)

        guard currentStdDev > 0 else { return }

        // Snapshot grades before modification for rollback
        let previousGrades: [UUID: Double?] = Dictionary(
            matchingIndices.map { (assignments[$0].id, assignments[$0].grade) },
            uniquingKeysWith: { first, _ in first }
        )

        for i in matchingIndices {
            guard let currentGrade = assignments[i].grade else { continue }
            let zScore = (currentGrade - currentMean) / currentStdDev
            let newGrade = min(max(targetMean + (zScore * targetStdDev), 0), 100)
            assignments[i].grade = newGrade

            if !isDemoMode {
                let score = newGrade / 100.0 * Double(assignments[i].points)
                let letter = gradeService.letterGrade(from: newGrade)
                do {
                    try await gradeSubmission(
                        assignmentId: assignments[i].id,
                        studentId: assignments[i].studentId,
                        score: score,
                        letterGrade: letter,
                        feedback: assignments[i].feedback
                    )
                } catch {
                    // Revert ALL grades to pre-curve state on any failure
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply bell curve: \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Plagiarism Check

    /// Runs plagiarism detection on all text submissions for a given assignment title in a course.
    func runPlagiarismCheck(assignmentTitle: String, courseId: UUID) -> PlagiarismReport {
        let matchingSubmissions = assignments.filter {
            $0.courseId == courseId &&
            $0.title == assignmentTitle &&
            $0.isSubmitted &&
            $0.submission != nil
        }

        let submissionData: [(studentId: UUID, studentName: String, text: String)] = matchingSubmissions.compactMap { assignment in
            guard let text = Assignment.cleanSubmissionText(assignment.submission),
                  !text.isEmpty else { return nil }
            let studentId = assignment.studentId ?? UUID()
            let studentName = assignment.studentName ?? "Unknown Student"
            return (studentId: studentId, studentName: studentName, text: text)
        }

        let assignmentId = matchingSubmissions.first?.id ?? UUID()

        return PlagiarismService.shared.checkSubmissions(
            submissions: submissionData,
            assignmentId: assignmentId,
            assignmentTitle: assignmentTitle
        )
    }
}

// MARK: - Grade Statistics Model

nonisolated struct GradeStatistics: Sendable {
    let count: Int
    let mean: Double
    let median: Double
    let min: Double
    let max: Double
    let standardDeviation: Double

    /// Distribution buckets for histogram: [0-10), [10-20), ..., [90-100]
    let distribution: [Int]

    init(scores: [Double]) {
        let sorted = scores.sorted()
        self.count = sorted.count

        if sorted.isEmpty {
            self.mean = 0
            self.median = 0
            self.min = 0
            self.max = 0
            self.standardDeviation = 0
            self.distribution = Array(repeating: 0, count: 10)
            return
        }

        let calculatedMean = sorted.reduce(0, +) / Double(sorted.count)
        self.mean = calculatedMean
        self.min = sorted.first ?? 0
        self.max = sorted.last ?? 0

        // Median
        if sorted.count % 2 == 0 {
            let mid = sorted.count / 2
            self.median = (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            self.median = sorted[sorted.count / 2]
        }

        // Standard deviation
        let variance = sorted.reduce(0.0) { $0 + pow($1 - calculatedMean, 2) } / Double(sorted.count)
        self.standardDeviation = sqrt(variance)

        // Distribution buckets: 0-9, 10-19, ..., 90-100
        var buckets = Array(repeating: 0, count: 10)
        for score in sorted {
            let bucket = Swift.min(Int(score / 10.0), 9)
            buckets[bucket] += 1
        }
        self.distribution = buckets
    }
}
