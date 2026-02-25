import Foundation
import SwiftUI
import Supabase

// MARK: - GradesViewModel
/// Manages all grade-related state and logic: grade entries, weighted calculations,
/// grade statistics, grade curves, bulk grading, CSV export, late penalties, and plagiarism checks.
/// Extracted from AppViewModel to reduce god-class complexity.

@Observable
@MainActor
class GradesViewModel {

    // MARK: - Grade Data

    /// All grade entries for the current student (or all students for teacher view).
    var grades: [GradeEntry] = []

    /// Error surfaced when grading operations fail.
    var gradeError: String?

    /// Indicates a grade operation is in progress.
    var isLoading = false

    // MARK: - Grade Calculation Service

    var gradeService = GradeCalculationService()

    // MARK: - Computed: Weighted Course Grades

    /// Weighted grade results for every course the student is enrolled in.
    /// Each result includes per-category breakdowns, letter grade, and GPA points
    /// computed using the teacher-configured weights (or defaults).
    var courseGradeResults: [CourseGradeResult] {
        let grouped = Dictionary(grouping: grades, by: \.courseId)
        return grouped.compactMap { courseId, courseGrades -> CourseGradeResult? in
            guard let first = courseGrades.first else { return nil }
            let weights = gradeService.getWeights(for: courseId)
            return gradeService.calculateCourseGrade(
                grades: courseGrades,
                weights: weights,
                courseId: courseId,
                courseName: first.courseName
            )
        }
    }

    /// GPA on a 4.0 scale, computed from weighted course grades.
    var gpa: Double {
        let results = courseGradeResults
        guard !results.isEmpty else { return 0 }
        return gradeService.calculateGPA(courseResults: results)
    }

    /// Overall weighted percentage across all courses (0-100).
    var weightedAveragePercent: Double {
        let results = courseGradeResults
        guard !results.isEmpty else { return 0 }
        return results.reduce(0.0) { $0 + $1.overallPercentage } / Double(results.count)
    }

    /// Overall letter grade derived from the weighted average percentage.
    var overallLetterGrade: String {
        gradeService.letterGrade(from: weightedAveragePercent)
    }

    // MARK: - Grade Invalidation

    /// Forces a recalculation of weighted grades (called after teacher saves new weights).
    func invalidateGradeCalculations() {
        let current = grades
        grades = current
    }

    // MARK: - Grade Statistics

    /// Computes grade statistics for a specific assignment across all student submissions.
    func gradeStatistics(for assignmentId: UUID, assignments: [Assignment]) -> GradeStatistics {
        let assignmentSubmissions = assignments.filter {
            $0.id == assignmentId && $0.isSubmitted && $0.grade != nil
        }
        let scores = assignmentSubmissions.compactMap(\.grade)
        return GradeStatistics(scores: scores)
    }

    /// Computes grade statistics for all graded submissions in a course for a specific assignment title.
    func gradeStatisticsForAssignment(title: String, courseId: UUID, assignments: [Assignment]) -> GradeStatistics {
        let matchingSubmissions = assignments.filter {
            $0.courseId == courseId && $0.title == title && $0.isSubmitted && $0.grade != nil
        }
        let scores = matchingSubmissions.compactMap(\.grade)
        return GradeStatistics(scores: scores)
    }

    // MARK: - Grade Curves

    /// Adds a flat number of points to all graded submissions for the given assignment.
    /// Scores are capped at 100. Mutates the assignments array in place.
    func applyFlatCurve(assignmentTitle: String, courseId: UUID, points: Double, assignments: inout [Assignment]) {
        isLoading = true
        defer { isLoading = false }

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(currentGrade + points, 100.0)
            assignments[i].grade = max(newGrade, 0)
        }
    }

    /// Multiplies all graded submissions by a factor (e.g., 1.1 = 10% boost).
    /// Scores are capped at 100.
    func applyPercentageBoost(assignmentTitle: String, courseId: UUID, factor: Double, assignments: inout [Assignment]) {
        isLoading = true
        defer { isLoading = false }

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(currentGrade * factor, 100.0)
            assignments[i].grade = max(newGrade, 0)
        }
    }

    /// Applies sqrt curve: newScore = sqrt(original) * 10.
    func applySquareRootCurve(assignmentTitle: String, courseId: UUID, assignments: inout [Assignment]) {
        isLoading = true
        defer { isLoading = false }

        for i in assignments.indices {
            guard assignments[i].courseId == courseId,
                  assignments[i].title == assignmentTitle,
                  assignments[i].isSubmitted,
                  let currentGrade = assignments[i].grade else { continue }

            let newGrade = min(sqrt(currentGrade) * 10.0, 100.0)
            assignments[i].grade = max(newGrade, 0)
        }
    }

    /// Scales grades to a target mean and standard deviation using z-score normalization.
    func applyBellCurve(assignmentTitle: String, courseId: UUID, targetMean: Double, targetStdDev: Double, assignments: inout [Assignment]) {
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

        for i in matchingIndices {
            guard let currentGrade = assignments[i].grade else { continue }
            let zScore = (currentGrade - currentMean) / currentStdDev
            let newGrade = min(max(targetMean + (zScore * targetStdDev), 0), 100)
            assignments[i].grade = newGrade
        }
    }

    // MARK: - CSV Export

    /// Generates a CSV file with graded assignment data for a given course.
    func exportGradesToCSV(courseId: UUID, assignments: [Assignment], courses: [Course], startDate: Date? = nil, endDate: Date? = nil) -> URL? {
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
            print("[GradesViewModel] CSV export failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Plagiarism Check

    /// Runs plagiarism detection on all text submissions for a given assignment title in a course.
    func runPlagiarismCheck(assignmentTitle: String, courseId: UUID, assignments: [Assignment]) -> PlagiarismReport {
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

    // MARK: - Late Penalty Calculation

    /// Calculates the adjusted grade after applying the late penalty for an assignment.
    func adjustedGradeWithLatePenalty(rawGradePercent: Double, for assignment: Assignment) -> Double {
        guard assignment.latePenaltyType != .none else { return rawGradePercent }

        let daysLate = assignment.daysLate
        guard daysLate > 0 else { return rawGradePercent }

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
    func adjustedScoreWithLatePenalty(rawScore: Double, for assignment: Assignment) -> Double {
        let maxPts = Double(assignment.points)
        guard maxPts > 0 else { return rawScore }

        let rawPercent = (rawScore / maxPts) * 100
        let adjustedPercent = adjustedGradeWithLatePenalty(rawGradePercent: rawPercent, for: assignment)
        return (adjustedPercent / 100) * maxPts
    }

    /// Returns a human-readable summary of the late penalty applied to an assignment.
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

    // MARK: - Current Grade Lookup

    /// Current numeric grade for a given course (from grades array).
    func currentGrade(for courseId: UUID) -> Double? {
        grades.first(where: { $0.courseId == courseId })?.numericGrade
    }
}
