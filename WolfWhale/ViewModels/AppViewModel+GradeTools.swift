import Foundation

// MARK: - Grade Curve/Scaling + Plagiarism Detection (Delegating to GradesViewModel)

extension AppViewModel {

    // MARK: - Grade Statistics (delegates to sub-VM)

    func gradeStatistics(for assignmentId: UUID) -> GradeStatistics {
        gradesVM.gradeStatistics(for: assignmentId, assignments: assignments)
    }

    func gradeStatisticsForAssignment(title: String, courseId: UUID) -> GradeStatistics {
        gradesVM.gradeStatisticsForAssignment(title: title, courseId: courseId, assignments: assignments)
    }

    // MARK: - Apply Flat Curve (delegates to sub-VM, then persists)

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

        gradesVM.applyFlatCurve(assignmentTitle: assignmentTitle, courseId: courseId, points: points, assignments: &assignments)

        if !isDemoMode {
            for i in assignments.indices {
                guard assignments[i].courseId == courseId,
                      assignments[i].title == assignmentTitle,
                      assignments[i].isSubmitted,
                      assignments[i].grade != nil else { continue }

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
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply flat curve: \(UserFacingError.sanitize(error).localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Percentage Boost (delegates to sub-VM, then persists)

    func applyPercentageBoost(assignmentTitle: String, courseId: UUID, factor: Double) async {
        isLoading = true
        defer { isLoading = false }

        let previousGrades: [UUID: Double?] = Dictionary(
            assignments.enumerated()
                .filter { $0.element.courseId == courseId && $0.element.title == assignmentTitle && $0.element.isSubmitted && $0.element.grade != nil }
                .map { ($0.element.id, $0.element.grade) },
            uniquingKeysWith: { first, _ in first }
        )

        gradesVM.applyPercentageBoost(assignmentTitle: assignmentTitle, courseId: courseId, factor: factor, assignments: &assignments)

        if !isDemoMode {
            for i in assignments.indices {
                guard assignments[i].courseId == courseId,
                      assignments[i].title == assignmentTitle,
                      assignments[i].isSubmitted,
                      assignments[i].grade != nil else { continue }

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
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply percentage boost: \(UserFacingError.sanitize(error).localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Square Root Curve (delegates to sub-VM, then persists)

    func applySquareRootCurve(assignmentTitle: String, courseId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let previousGrades: [UUID: Double?] = Dictionary(
            assignments.enumerated()
                .filter { $0.element.courseId == courseId && $0.element.title == assignmentTitle && $0.element.isSubmitted && $0.element.grade != nil }
                .map { ($0.element.id, $0.element.grade) },
            uniquingKeysWith: { first, _ in first }
        )

        gradesVM.applySquareRootCurve(assignmentTitle: assignmentTitle, courseId: courseId, assignments: &assignments)

        if !isDemoMode {
            for i in assignments.indices {
                guard assignments[i].courseId == courseId,
                      assignments[i].title == assignmentTitle,
                      assignments[i].isSubmitted,
                      assignments[i].grade != nil else { continue }

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
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply square root curve: \(UserFacingError.sanitize(error).localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Apply Bell Curve (delegates to sub-VM, then persists)

    func applyBellCurve(assignmentTitle: String, courseId: UUID, targetMean: Double, targetStdDev: Double) async {
        isLoading = true
        defer { isLoading = false }

        let matchingIndices = assignments.indices.filter {
            assignments[$0].courseId == courseId &&
            assignments[$0].title == assignmentTitle &&
            assignments[$0].isSubmitted &&
            assignments[$0].grade != nil
        }

        let previousGrades: [UUID: Double?] = Dictionary(
            matchingIndices.map { (assignments[$0].id, assignments[$0].grade) },
            uniquingKeysWith: { first, _ in first }
        )

        gradesVM.applyBellCurve(assignmentTitle: assignmentTitle, courseId: courseId, targetMean: targetMean, targetStdDev: targetStdDev, assignments: &assignments)

        if !isDemoMode {
            for i in matchingIndices {
                guard let newGrade = assignments[i].grade else { continue }
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
                    for j in assignments.indices where previousGrades[assignments[j].id] != nil {
                        assignments[j].grade = previousGrades[assignments[j].id] ?? nil
                    }
                    gradeError = "Failed to apply bell curve: \(UserFacingError.sanitize(error).localizedDescription)"
                    return
                }
            }
        }
    }

    // MARK: - Plagiarism Check (delegates to sub-VM)

    func runPlagiarismCheck(assignmentTitle: String, courseId: UUID) -> PlagiarismReport {
        gradesVM.runPlagiarismCheck(assignmentTitle: assignmentTitle, courseId: courseId, assignments: assignments)
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
