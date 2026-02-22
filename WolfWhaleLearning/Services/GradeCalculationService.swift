import SwiftUI

@MainActor @Observable
final class GradeCalculationService {
    var error: String?
    var isLoading = false

    // MARK: - UserDefaults Key Prefix

    private static let weightsKeyPrefix = "wolfwhale_grade_weights_"

    // MARK: - Core Calculations

    /// Calculates the overall course grade from individual assignment grades using weighted categories.
    func calculateCourseGrade(
        grades: [GradeEntry],
        weights: GradeWeights,
        courseId: UUID,
        courseName: String
    ) -> CourseGradeResult {
        // Flatten all assignment grades from every GradeEntry for this course
        let allAssignmentGrades = grades
            .filter { $0.courseId == courseId }
            .flatMap(\.assignmentGrades)

        let breakdowns = GradeCategory.allCases.map { category -> GradeBreakdown in
            let matching = allAssignmentGrades.filter { categorize($0.type) == category }
            let earned = matching.reduce(0.0) { $0 + $1.score }
            let total = matching.reduce(0.0) { $0 + $1.maxScore }
            let percentage = total > 0 ? (earned / total) * 100.0 : 0.0
            let weight = weights.weight(for: category)
            let contribution = percentage * weight

            return GradeBreakdown(
                category: category,
                weight: weight,
                earnedPoints: earned,
                totalPoints: total,
                percentage: percentage,
                weightedContribution: contribution
            )
        }

        // Only include categories that have actual grades
        let activeBreakdowns = breakdowns.filter { $0.totalPoints > 0 }
        let totalWeight = activeBreakdowns.reduce(0.0) { $0 + $1.weight }

        // Re-normalize: if some categories have no grades, redistribute their weight
        let overallPercentage: Double
        if totalWeight > 0 {
            let rawWeighted = activeBreakdowns.reduce(0.0) { $0 + $1.weightedContribution }
            overallPercentage = rawWeighted / totalWeight
        } else {
            overallPercentage = 0
        }

        let letter = letterGrade(from: overallPercentage)
        let points = gradePoints(from: overallPercentage)
        let trend = calculateTrend(assignmentGrades: allAssignmentGrades)

        return CourseGradeResult(
            courseId: courseId,
            courseName: courseName,
            overallPercentage: overallPercentage,
            letterGrade: letter,
            gradePoints: points,
            breakdowns: breakdowns,
            trend: trend
        )
    }

    /// Calculates cumulative GPA on a 4.0 scale from multiple course results.
    func calculateGPA(courseResults: [CourseGradeResult]) -> Double {
        guard !courseResults.isEmpty else { return 0.0 }
        let totalPoints = courseResults.reduce(0.0) { $0 + $1.gradePoints }
        return totalPoints / Double(courseResults.count)
    }

    // MARK: - Letter Grade

    /// Converts a percentage (0-100) to a letter grade.
    func letterGrade(from percentage: Double) -> String {
        switch percentage {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }

    // MARK: - Grade Points (4.0 Scale)

    /// Converts a percentage (0-100) to grade points on a 4.0 scale.
    func gradePoints(from percentage: Double) -> Double {
        switch percentage {
        case 97...: return 4.0
        case 93..<97: return 4.0
        case 90..<93: return 3.7
        case 87..<90: return 3.3
        case 83..<87: return 3.0
        case 80..<83: return 2.7
        case 77..<80: return 2.3
        case 73..<77: return 2.0
        case 70..<73: return 1.7
        case 67..<70: return 1.3
        case 63..<67: return 1.0
        case 60..<63: return 0.7
        default: return 0.0
        }
    }

    // MARK: - Trend Calculation

    /// Calculates the grade trend by comparing the last N grades to the N grades before them.
    func calculateTrend(grades: [GradeEntry], lastN: Int = 5) -> GradeTrend {
        let allAssignmentGrades = grades.flatMap(\.assignmentGrades)
        return calculateTrend(assignmentGrades: allAssignmentGrades, lastN: lastN)
    }

    /// Internal trend calculation on sorted assignment grades.
    private func calculateTrend(assignmentGrades: [AssignmentGrade], lastN: Int = 5) -> GradeTrend {
        let sorted = assignmentGrades.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return .stable }

        let recentCount = min(lastN, sorted.count)
        let recentSlice = sorted.suffix(recentCount)
        let recentAvg = recentSlice.reduce(0.0) { total, ag in
            total + (ag.maxScore > 0 ? (ag.score / ag.maxScore * 100) : 0)
        } / Double(recentSlice.count)

        let remaining = sorted.dropLast(recentCount)
        guard !remaining.isEmpty else { return .stable }

        let previousCount = min(lastN, remaining.count)
        let previousSlice = remaining.suffix(previousCount)
        let previousAvg = previousSlice.reduce(0.0) { total, ag in
            total + (ag.maxScore > 0 ? (ag.score / ag.maxScore * 100) : 0)
        } / Double(previousSlice.count)

        let delta = recentAvg - previousAvg
        if delta > 2.0 {
            return .improving
        } else if delta < -2.0 {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - Grade Color

    /// Returns a Color based on the percentage grade.
    func gradeColor(from percentage: Double) -> Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Weight Management (UserDefaults, per course)

    /// Retrieves the grade weights for a specific course, falling back to defaults.
    func getWeights(for courseId: UUID) -> GradeWeights {
        let key = Self.weightsKeyPrefix + courseId.uuidString
        guard let data = UserDefaults.standard.data(forKey: key),
              let weights = try? JSONDecoder().decode(GradeWeights.self, from: data) else {
            return .default
        }
        return weights
    }

    /// Persists the grade weights for a specific course.
    func setWeights(_ weights: GradeWeights, for courseId: UUID) {
        let key = Self.weightsKeyPrefix + courseId.uuidString
        if let data = try? JSONEncoder().encode(weights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - What-If Calculator

    /// Calculates what percentage a student needs on remaining work to achieve a target grade.
    /// Returns nil if the target is impossible.
    func percentageNeeded(
        currentEarned: Double,
        currentTotal: Double,
        remainingTotal: Double,
        targetPercentage: Double
    ) -> Double? {
        guard remainingTotal > 0 else { return nil }
        let totalPossible = currentTotal + remainingTotal
        let needed = (targetPercentage / 100.0) * totalPossible - currentEarned
        let neededPercent = (needed / remainingTotal) * 100.0
        guard neededPercent <= 100.0 else { return nil }
        return max(0, neededPercent)
    }

    // MARK: - Category Mapping

    /// Maps an AssignmentGrade type string to a GradeCategory.
    func categorize(_ type: String) -> GradeCategory {
        let lowered = type.lowercased()
        if lowered.contains("quiz") { return .quiz }
        if lowered.contains("participation") || lowered.contains("attend") { return .participation }
        if lowered.contains("midterm") || lowered.contains("mid-term") { return .midterm }
        if lowered.contains("final") { return .finalExam }
        return .assignment
    }
}
