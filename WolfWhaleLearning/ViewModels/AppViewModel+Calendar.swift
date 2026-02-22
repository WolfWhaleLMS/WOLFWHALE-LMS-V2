import Foundation

// MARK: - Assignment Calendar & Progress Goals

extension AppViewModel {

    // MARK: - Progress Goals Storage

    /// In-memory progress goals. Persisted via UserDefaults for demo mode.
    /// For Supabase mode, these would be stored in a `progress_goals` table.
    var progressGoals: [ProgressGoal] {
        get {
            if let data = UserDefaults.standard.data(forKey: "progressGoals"),
               let goals = try? JSONDecoder().decode([ProgressGoal].self, from: data) {
                return goals
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "progressGoals")
            }
        }
    }

    func setProgressGoal(courseId: UUID, targetLetterGrade: String) {
        let targetPercentage = ProgressGoal.gradePercentage(for: targetLetterGrade)
        let goal = ProgressGoal(
            courseId: courseId,
            targetGrade: targetPercentage,
            targetLetterGrade: targetLetterGrade
        )
        var current = progressGoals
        current.removeAll { $0.courseId == courseId }
        current.append(goal)
        progressGoals = current
    }

    func removeProgressGoal(courseId: UUID) {
        var current = progressGoals
        current.removeAll { $0.courseId == courseId }
        progressGoals = current
    }

    func progressGoal(for courseId: UUID) -> ProgressGoal? {
        progressGoals.first { $0.courseId == courseId }
    }

    // MARK: - Calendar Helpers

    /// All assignments grouped by their due date (day precision).
    func assignmentsByDate() -> [Date: [Assignment]] {
        let calendar = Calendar.current
        var grouped: [Date: [Assignment]] = [:]
        for assignment in assignments {
            let dayStart = calendar.startOfDay(for: assignment.dueDate)
            grouped[dayStart, default: []].append(assignment)
        }
        return grouped
    }

    /// Courses that the student currently has assignments for.
    func coursesWithAssignments() -> [Course] {
        let courseIds = Set(assignments.map(\.courseId))
        return courses.filter { courseIds.contains($0.id) }
    }

    /// Current numeric grade for a given course (from grades array).
    func currentGrade(for courseId: UUID) -> Double? {
        grades.first(where: { $0.courseId == courseId })?.numericGrade
    }

    /// Count of remaining (not submitted) assignments for a course.
    func remainingAssignmentCount(for courseId: UUID) -> Int {
        assignments.filter { $0.courseId == courseId && !$0.isSubmitted }.count
    }

    /// Average score needed on remaining assignments to reach a target grade.
    /// Returns nil if there are no remaining assignments.
    func requiredAverageScore(courseId: UUID, targetGrade: Double) -> Double? {
        let courseAssignments = assignments.filter { $0.courseId == courseId }
        let graded = courseAssignments.filter { $0.grade != nil }
        let remaining = courseAssignments.filter { !$0.isSubmitted }

        guard !remaining.isEmpty else { return nil }

        let totalCount = Double(graded.count + remaining.count)
        let currentSum = graded.reduce(0.0) { $0 + ($1.grade ?? 0) }
        let neededSum = targetGrade * totalCount
        let remainingNeeded = neededSum - currentSum
        let averageNeeded = remainingNeeded / Double(remaining.count)

        return averageNeeded
    }
}
