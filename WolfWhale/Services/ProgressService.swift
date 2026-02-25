import Foundation

@MainActor
@Observable
final class ProgressService {
    var error: String?
    var isLoading = false

    // MARK: - Data Types

    nonisolated struct CourseProgress: Sendable {
        let courseId: UUID
        let courseName: String
        let teacherName: String
        let colorName: String
        let iconSystemName: String
        let lessonsCompleted: Int
        let lessonsTotal: Int
        let assignmentsSubmitted: Int
        let assignmentsTotal: Int
        let quizzesCompleted: Int
        let quizzesTotal: Int
        let overallPercentage: Double // 0.0 to 1.0
        let currentGrade: Double? // percentage if available
        let letterGrade: String?
        let nextUncompletedLesson: Lesson?
        let nextUncompletedLessonModuleTitle: String?
    }

    nonisolated struct WeeklySummary: Sendable {
        let lessonsCompleted: Int
        let assignmentsSubmitted: Int
        let quizzesTaken: Int
        let studyStreak: Int // consecutive days
        let comparedToLastWeek: ComparisonTrend
    }

    nonisolated enum ComparisonTrend: Sendable {
        case up(Int)   // improved by N
        case down(Int) // decreased by N
        case same

        var label: String {
            switch self {
            case .up(let n): return "+\(n) from last week"
            case .down(let n): return "-\(n) from last week"
            case .same: return "Same as last week"
            }
        }
    }

    nonisolated struct NextUpItem: Sendable, Identifiable {
        let id: UUID
        let title: String
        let courseName: String
        let courseColor: String
        let type: NextUpType
        let dueDate: Date?
    }

    nonisolated enum NextUpType: Sendable {
        case lesson
        case assignment
        case quiz

        var iconName: String {
            switch self {
            case .lesson: return "book.fill"
            case .assignment: return "doc.text.fill"
            case .quiz: return "questionmark.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .lesson: return "Lesson"
            case .assignment: return "Assignment"
            case .quiz: return "Quiz"
            }
        }
    }

    // MARK: - Sort Option

    nonisolated enum SortOption: String, CaseIterable, Sendable {
        case completion = "Completion"
        case name = "Name"
        case grade = "Grade"
    }

    // MARK: - Single Course Progress

    func courseCompletion(
        course: Course,
        assignments: [Assignment],
        quizzes: [Quiz],
        grades: [GradeEntry]
    ) -> CourseProgress {
        let allLessons = course.modules.flatMap(\.lessons)
        let lessonsCompleted = allLessons.filter(\.isCompleted).count
        let lessonsTotal = allLessons.count

        let courseAssignments = assignments.filter { $0.courseId == course.id }
        let assignmentsSubmitted = courseAssignments.filter(\.isSubmitted).count
        let assignmentsTotal = courseAssignments.count

        let courseQuizzes = quizzes.filter { $0.courseId == course.id }
        let quizzesCompleted = courseQuizzes.filter(\.isCompleted).count
        let quizzesTotal = courseQuizzes.count

        let totalItems = lessonsTotal + assignmentsTotal + quizzesTotal
        let completedItems = lessonsCompleted + assignmentsSubmitted + quizzesCompleted
        let overallPercentage: Double = totalItems > 0
            ? Double(completedItems) / Double(totalItems)
            : 0.0

        let gradeEntry = grades.first(where: { $0.courseId == course.id })
        let currentGrade = gradeEntry?.numericGrade
        let letterGrade = gradeEntry?.letterGrade

        // Find next uncompleted lesson
        var nextLesson: Lesson?
        var nextLessonModuleTitle: String?
        for module in course.modules {
            if let lesson = module.lessons.first(where: { !$0.isCompleted }) {
                nextLesson = lesson
                nextLessonModuleTitle = module.title
                break
            }
        }

        return CourseProgress(
            courseId: course.id,
            courseName: course.title,
            teacherName: course.teacherName,
            colorName: course.colorName,
            iconSystemName: course.iconSystemName,
            lessonsCompleted: lessonsCompleted,
            lessonsTotal: lessonsTotal,
            assignmentsSubmitted: assignmentsSubmitted,
            assignmentsTotal: assignmentsTotal,
            quizzesCompleted: quizzesCompleted,
            quizzesTotal: quizzesTotal,
            overallPercentage: overallPercentage,
            currentGrade: currentGrade,
            letterGrade: letterGrade,
            nextUncompletedLesson: nextLesson,
            nextUncompletedLessonModuleTitle: nextLessonModuleTitle
        )
    }

    // MARK: - All Courses Progress

    func allCourseProgress(
        courses: [Course],
        assignments: [Assignment],
        quizzes: [Quiz],
        grades: [GradeEntry]
    ) -> [CourseProgress] {
        courses.map { course in
            courseCompletion(
                course: course,
                assignments: assignments,
                quizzes: quizzes,
                grades: grades
            )
        }
    }

    // MARK: - Weekly Summary

    /// Builds a weekly summary by comparing the current calendar week's activity
    /// against the previous week. Lesson completion is tracked via the course
    /// model's `isCompleted` flag (the project doesn't expose per-lesson completion
    /// dates at the view-model layer), so we use `courses` to derive the total and
    /// `assignments`/`quizzes` to derive submission counts for the current week.
    func weeklySummary(
        courses: [Course],
        assignments: [Assignment],
        quizzes: [Quiz],
        previousWeekLessons: Int = 0,
        previousWeekAssignments: Int = 0,
        previousWeekQuizzes: Int = 0,
        streakDays: Int = 0
    ) -> WeeklySummary {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return WeeklySummary(
                lessonsCompleted: 0,
                assignmentsSubmitted: 0,
                quizzesTaken: 0,
                studyStreak: streakDays,
                comparedToLastWeek: .same
            )
        }

        // Assignments submitted this week
        let thisWeekAssignments = assignments.filter { assignment in
            assignment.isSubmitted && assignment.dueDate >= weekStart && assignment.dueDate <= now
        }.count

        // Quizzes completed this week
        let thisWeekQuizzes = quizzes.filter { quiz in
            quiz.isCompleted && quiz.dueDate >= weekStart && quiz.dueDate <= now
        }.count

        // Lessons completed this week (approximate from total completed lessons)
        let thisWeekLessons = courses.reduce(0) { total, course in
            total + course.modules.reduce(0) { modTotal, module in
                modTotal + module.lessons.filter(\.isCompleted).count
            }
        }

        // Comparison: total activity this week vs last week
        let thisWeekTotal = thisWeekLessons + thisWeekAssignments + thisWeekQuizzes
        let lastWeekTotal = previousWeekLessons + previousWeekAssignments + previousWeekQuizzes

        let trend: ComparisonTrend
        if thisWeekTotal > lastWeekTotal {
            trend = .up(thisWeekTotal - lastWeekTotal)
        } else if thisWeekTotal < lastWeekTotal {
            trend = .down(lastWeekTotal - thisWeekTotal)
        } else {
            trend = .same
        }

        return WeeklySummary(
            lessonsCompleted: thisWeekLessons,
            assignmentsSubmitted: thisWeekAssignments,
            quizzesTaken: thisWeekQuizzes,
            studyStreak: streakDays,
            comparedToLastWeek: trend
        )
    }

    // MARK: - Study Streak

    /// Returns the number of consecutive days with at least one lesson completed,
    /// going backwards from today. Uses the user's streak from their profile as
    /// the authoritative value since individual lesson completion dates aren't
    /// exposed at the view-model layer.
    func studyStreak(user: User?) -> Int {
        user?.streak ?? 0
    }

    // MARK: - Next Up Items

    /// Returns the most urgent incomplete items across all courses, sorted by due date.
    func nextUpItems(
        courses: [Course],
        assignments: [Assignment],
        quizzes: [Quiz]
    ) -> [NextUpItem] {
        var items: [NextUpItem] = []

        // Incomplete assignments sorted by due date
        let pendingAssignments = assignments
            .filter { !$0.isSubmitted && !$0.isOverdue }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(5)

        for assignment in pendingAssignments {
            let courseColor = courses.first(where: { $0.id == assignment.courseId })?.colorName ?? "blue"
            items.append(NextUpItem(
                id: assignment.id,
                title: assignment.title,
                courseName: assignment.courseName,
                courseColor: courseColor,
                type: .assignment,
                dueDate: assignment.dueDate
            ))
        }

        // Incomplete quizzes sorted by due date
        let pendingQuizzes = quizzes
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)

        for quiz in pendingQuizzes {
            let courseColor = courses.first(where: { $0.id == quiz.courseId })?.colorName ?? "blue"
            items.append(NextUpItem(
                id: quiz.id,
                title: quiz.title,
                courseName: quiz.courseName,
                courseColor: courseColor,
                type: .quiz,
                dueDate: quiz.dueDate
            ))
        }

        // Next uncompleted lesson per course (no due date, so sort by course name)
        for course in courses {
            for module in course.modules {
                if let lesson = module.lessons.first(where: { !$0.isCompleted }) {
                    items.append(NextUpItem(
                        id: lesson.id,
                        title: lesson.title,
                        courseName: course.title,
                        courseColor: course.colorName,
                        type: .lesson,
                        dueDate: nil
                    ))
                    break // Only one lesson per course
                }
            }
        }

        // Sort: items with due dates first (soonest), then lessons
        return items.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (.some(dateA), .some(dateB)):
                return dateA < dateB
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return a.courseName < b.courseName
            }
        }
    }

    // MARK: - Overall Stats

    func overallCompletionPercentage(progressList: [CourseProgress]) -> Double {
        guard !progressList.isEmpty else { return 0 }
        let totalPercentage = progressList.reduce(0.0) { $0 + $1.overallPercentage }
        return totalPercentage / Double(progressList.count)
    }

    // MARK: - Letter Grade Helper

    nonisolated static func letterGrade(for percentage: Double) -> String {
        switch percentage {
        case 93...: return "A"
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

    nonisolated static func gradeColor(for percentage: Double) -> String {
        switch percentage {
        case 90...: return "green"
        case 80..<90: return "blue"
        case 70..<80: return "orange"
        default: return "red"
        }
    }

    // MARK: - Sort Helper

    func sorted(_ progressList: [CourseProgress], by option: SortOption) -> [CourseProgress] {
        switch option {
        case .completion:
            return progressList.sorted { $0.overallPercentage > $1.overallPercentage }
        case .name:
            return progressList.sorted { $0.courseName.localizedStandardCompare($1.courseName) == .orderedAscending }
        case .grade:
            return progressList.sorted { ($0.currentGrade ?? 0) > ($1.currentGrade ?? 0) }
        }
    }
}
