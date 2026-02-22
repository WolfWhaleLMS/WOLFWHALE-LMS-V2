import Foundation
import CoreML

// MARK: - Models

nonisolated struct LearningRecommendation: Identifiable, Hashable, Sendable {
    let id: UUID
    let type: RecommendationType
    let title: String
    let description: String
    let priority: RecommendationPriority
    let relatedCourseId: UUID?
    let relatedAssignmentId: UUID?
    let iconSystemName: String
    let actionLabel: String
}

nonisolated enum RecommendationType: String, Sendable {
    case studyReminder
    case weakArea
    case upcomingDeadline
    case streakBoost
    case lessonSuggestion
    case performanceTrend
    case studyTimeOptimal
    case learningStyle
}

nonisolated enum RecommendationPriority: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var colorName: String {
        switch self {
        case .low: "green"
        case .medium: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }
}

nonisolated struct StudentAnalytics: Sendable {
    let averageGrade: Double
    let strongSubjects: [String]
    let weakSubjects: [String]
    let preferredLearningStyle: LessonType
    let completionRate: Double
    let studyStreakDays: Int
    let predictedPerformance: Double
    let totalLessonsCompleted: Int
    let totalAssignmentsSubmitted: Int
    let gradeDistribution: [String: Double]
}

// MARK: - Service

@MainActor
@Observable
final class LearningRecommendationService {
    var error: String?
    var isLoading = false
    var recommendations: [LearningRecommendation] = []
    var analytics: StudentAnalytics?

    // MARK: - Internal State

    private var completionTimestamps: [Date] = []

    /// Learned weights for performance prediction, fitted via simple linear regression
    /// on grade history data. Falls back to defaults when insufficient data exists.
    private var weights: (scoreW: Double, completionW: Double, intercept: Double) = (0.7, 0.3, 0.0)
    private var hasTrainedModel = false

    // MARK: - On-Device Performance Prediction

    /// Fits a simple linear regression from grade history to learn personalized
    /// prediction weights. Requires 3+ grade entries; otherwise uses default weights.
    /// Runs entirely on-device with no external model file required.
    private func trainPerformancePredictor(grades: [GradeEntry], assignments: [Assignment]) {
        guard grades.count >= 3 else {
            hasTrainedModel = false
            return
        }

        // Build feature vectors: [averageScore, completionRate] → target: numericGrade
        var features: [(score: Double, completion: Double)] = []
        var targets: [Double] = []

        for grade in grades {
            let courseAssignments = assignments.filter { $0.courseId == grade.courseId }
            let submitted = courseAssignments.filter(\.isSubmitted)
            let rate: Double = courseAssignments.isEmpty ? 0.0 : Double(submitted.count) / Double(courseAssignments.count)

            let avgScore: Double
            if grade.assignmentGrades.isEmpty {
                avgScore = grade.numericGrade
            } else {
                let total = grade.assignmentGrades.reduce(0.0) { sum, ag in
                    sum + (ag.score / max(ag.maxScore, 1) * 100)
                }
                avgScore = total / Double(grade.assignmentGrades.count)
            }

            features.append((score: avgScore, completion: rate * 100))
            targets.append(grade.numericGrade)
        }

        // Simple ordinary least squares for 2 features
        // y = w1 * score + w2 * completion + b
        let n = Double(features.count)
        let meanScore = features.reduce(0.0) { $0 + $1.score } / n
        let meanCompletion = features.reduce(0.0) { $0 + $1.completion } / n
        let meanTarget = targets.reduce(0.0, +) / n

        var ssScore = 0.0, ssCompletion = 0.0
        var spScoreTarget = 0.0, spCompletionTarget = 0.0

        for i in features.indices {
            let ds = features[i].score - meanScore
            let dc = features[i].completion - meanCompletion
            let dt = targets[i] - meanTarget
            ssScore += ds * ds
            ssCompletion += dc * dc
            spScoreTarget += ds * dt
            spCompletionTarget += dc * dt
        }

        let w1 = ssScore > 0 ? spScoreTarget / ssScore : 0.7
        let w2 = ssCompletion > 0 ? spCompletionTarget / ssCompletion : 0.3
        let intercept = meanTarget - w1 * meanScore - w2 * meanCompletion

        weights = (scoreW: w1, completionW: w2, intercept: intercept)
        hasTrainedModel = true
    }

    /// Predicts performance using learned weights or heuristic fallback.
    private func predictPerformance(
        assignmentCount: Double,
        averageScore: Double,
        completionRate: Double
    ) -> Double {
        if hasTrainedModel {
            let predicted = weights.scoreW * averageScore + weights.completionW * completionRate + weights.intercept
            return min(max(predicted, 0), 100)
        }

        // Heuristic fallback: weighted blend of score and completion
        return min(max(averageScore * 0.7 + completionRate * 0.3, 0), 100)
    }

    // MARK: - Public API

    /// Generates all recommendations and analytics from current student data.
    /// This runs entirely on-device -- no network calls required.
    func generateRecommendations(
        courses: [Course],
        assignments: [Assignment],
        quizzes: [Quiz],
        grades: [GradeEntry],
        streakDays: Int
    ) {
        isLoading = true
        error = nil

        // Train ML model if enough data
        trainPerformancePredictor(grades: grades, assignments: assignments)

        // Build analytics
        let computedAnalytics = buildAnalytics(
            courses: courses,
            assignments: assignments,
            quizzes: quizzes,
            grades: grades,
            streakDays: streakDays
        )
        analytics = computedAnalytics

        // Generate recommendations
        var allRecs: [LearningRecommendation] = []

        allRecs.append(contentsOf: generateWeakAreaRecommendations(grades: grades))
        allRecs.append(contentsOf: generateDeadlineRecommendations(assignments: assignments))
        allRecs.append(contentsOf: generateStreakRecommendations(streakDays: streakDays))
        allRecs.append(contentsOf: generateLessonSuggestions(courses: courses))
        allRecs.append(contentsOf: generatePerformanceTrends(grades: grades, analytics: computedAnalytics))
        allRecs.append(contentsOf: generateStudyTimeRecommendations())
        allRecs.append(contentsOf: generateLearningStyleRecommendations(courses: courses, analytics: computedAnalytics))

        // Sort by priority (urgent first), then by type for stable ordering
        recommendations = allRecs.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.type.rawValue < rhs.type.rawValue
        }

        isLoading = false
    }

    /// Records a lesson completion timestamp for study-time pattern analysis.
    func recordCompletionEvent() {
        completionTimestamps.append(Date())
        // Keep only last 100 events
        if completionTimestamps.count > 100 {
            completionTimestamps = Array(completionTimestamps.suffix(100))
        }
    }

    // MARK: - Analytics Builder

    private func buildAnalytics(
        courses: [Course],
        assignments: [Assignment],
        quizzes: [Quiz],
        grades: [GradeEntry],
        streakDays: Int
    ) -> StudentAnalytics {
        // Average grade
        let avgGrade: Double = grades.isEmpty
            ? 0
            : grades.reduce(0.0) { $0 + $1.numericGrade } / Double(grades.count)

        // Strong / weak subjects (threshold: 80 strong, <65 weak)
        let strong = grades.filter { $0.numericGrade >= 80 }.map(\.courseName)
        let weak = grades.filter { $0.numericGrade < 65 }.map(\.courseName)

        // Learning style detection based on completed lesson types
        let preferredStyle = detectLearningStyle(courses: courses)

        // Completion rate
        let totalAssignments = assignments.count
        let submitted = assignments.filter(\.isSubmitted).count
        let completedQuizzes = quizzes.filter(\.isCompleted).count
        let totalItems = totalAssignments + quizzes.count
        let completedItems = submitted + completedQuizzes
        let completionRate = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0

        // Predicted performance via ML or heuristic
        let predicted = predictPerformance(
            assignmentCount: Double(totalAssignments),
            averageScore: avgGrade,
            completionRate: completionRate * 100
        )

        // Totals
        let totalLessonsCompleted = courses.reduce(0) { $0 + $1.completedLessons }

        // Grade distribution by course
        var distribution: [String: Double] = [:]
        for grade in grades {
            distribution[grade.courseName] = grade.numericGrade
        }

        return StudentAnalytics(
            averageGrade: avgGrade,
            strongSubjects: strong,
            weakSubjects: weak,
            preferredLearningStyle: preferredStyle,
            completionRate: completionRate,
            studyStreakDays: streakDays,
            predictedPerformance: predicted,
            totalLessonsCompleted: totalLessonsCompleted,
            totalAssignmentsSubmitted: submitted,
            gradeDistribution: distribution
        )
    }

    // MARK: - Learning Style Detection

    /// Determines preferred learning style by analyzing which lesson types
    /// have the highest completion rate across all courses.
    private func detectLearningStyle(courses: [Course]) -> LessonType {
        var typeCounts: [LessonType: (completed: Int, total: Int)] = [
            .reading: (0, 0),
            .video: (0, 0),
            .activity: (0, 0),
            .quiz: (0, 0)
        ]

        for course in courses {
            for module in course.modules {
                for lesson in module.lessons {
                    let existing = typeCounts[lesson.type] ?? (0, 0)
                    typeCounts[lesson.type] = (
                        completed: existing.completed + (lesson.isCompleted ? 1 : 0),
                        total: existing.total + 1
                    )
                }
            }
        }

        // Find the type with the highest completion ratio
        var bestStyle: LessonType = .reading
        var bestRate: Double = -1

        for (type, counts) in typeCounts where counts.total > 0 {
            let rate = Double(counts.completed) / Double(counts.total)
            if rate > bestRate {
                bestRate = rate
                bestStyle = type
            }
        }

        return bestStyle
    }

    // MARK: - Recommendation Generators

    private func generateWeakAreaRecommendations(grades: [GradeEntry]) -> [LearningRecommendation] {
        grades
            .filter { $0.numericGrade < 65 }
            .map { grade in
                let priority: RecommendationPriority = grade.numericGrade < 50 ? .urgent : .high
                return LearningRecommendation(
                    id: UUID(),
                    type: .weakArea,
                    title: "Focus on \(grade.courseName)",
                    description: "Your grade of \(String(format: "%.0f%%", grade.numericGrade)) in \(grade.courseName) is below target. Review recent material and try practice exercises to strengthen your understanding.",
                    priority: priority,
                    relatedCourseId: grade.courseId,
                    relatedAssignmentId: nil,
                    iconSystemName: "exclamationmark.triangle.fill",
                    actionLabel: "Review Course"
                )
            }
    }

    private func generateDeadlineRecommendations(assignments: [Assignment]) -> [LearningRecommendation] {
        let now = Date()
        let upcoming = assignments.filter { !$0.isSubmitted && $0.dueDate > now }

        return upcoming.compactMap { assignment in
            let hoursUntilDue = assignment.dueDate.timeIntervalSince(now) / 3600

            let priority: RecommendationPriority
            let description: String

            if hoursUntilDue < 24 {
                priority = .urgent
                description = "\"\(assignment.title)\" for \(assignment.courseName) is due in less than 24 hours. Worth \(assignment.points) points -- submit now to avoid losing credit."
            } else if hoursUntilDue < 72 {
                priority = .high
                description = "\"\(assignment.title)\" for \(assignment.courseName) is due in \(Int(hoursUntilDue / 24)) days. Start working on it to stay ahead."
            } else if hoursUntilDue < 168 {
                priority = .medium
                description = "\"\(assignment.title)\" for \(assignment.courseName) is coming up this week. Plan your time accordingly."
            } else {
                return nil // Too far out to recommend
            }

            return LearningRecommendation(
                id: UUID(),
                type: .upcomingDeadline,
                title: "Assignment Due Soon",
                description: description,
                priority: priority,
                relatedCourseId: assignment.courseId,
                relatedAssignmentId: assignment.id,
                iconSystemName: "clock.badge.exclamationmark.fill",
                actionLabel: "View Assignment"
            )
        }
    }

    private func generateStreakRecommendations(streakDays: Int) -> [LearningRecommendation] {
        var recs: [LearningRecommendation] = []

        if streakDays == 0 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .streakBoost,
                title: "Start a Study Streak",
                description: "Complete a lesson today to begin building your study streak. Consistent daily learning leads to better retention and higher grades.",
                priority: .medium,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "flame",
                actionLabel: "Start Learning"
            ))
        } else if streakDays >= 7 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .streakBoost,
                title: "\(streakDays)-Day Streak -- Keep Going!",
                description: "You have been studying consistently for \(streakDays) days straight. Your dedication is paying off -- do not break the chain!",
                priority: .low,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "flame.fill",
                actionLabel: "Continue Streak"
            ))
        } else {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .streakBoost,
                title: "Keep Your \(streakDays)-Day Streak Alive",
                description: "Complete at least one lesson today to maintain your study streak. You are building great habits!",
                priority: .medium,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "flame.fill",
                actionLabel: "Study Now"
            ))
        }

        return recs
    }

    private func generateLessonSuggestions(courses: [Course]) -> [LearningRecommendation] {
        var recs: [LearningRecommendation] = []

        for course in courses {
            // Find the first incomplete lesson across modules (ordered by module index)
            let sortedModules = course.modules.sorted { $0.orderIndex < $1.orderIndex }
            for module in sortedModules {
                if let nextLesson = module.lessons.first(where: { !$0.isCompleted }) {
                    let progress = course.progress
                    let priority: RecommendationPriority = progress < 0.3 ? .high : .medium

                    recs.append(LearningRecommendation(
                        id: UUID(),
                        type: .lessonSuggestion,
                        title: "Continue: \(nextLesson.title)",
                        description: "Pick up where you left off in \(course.title). This \(nextLesson.type.rawValue.lowercased()) lesson is next in \(module.title) and earns \(nextLesson.xpReward) XP.",
                        priority: priority,
                        relatedCourseId: course.id,
                        relatedAssignmentId: nil,
                        iconSystemName: nextLesson.type.iconName,
                        actionLabel: "Start Lesson"
                    ))
                    break // Only one suggestion per course
                }
            }
        }

        return recs
    }

    private func generatePerformanceTrends(grades: [GradeEntry], analytics: StudentAnalytics) -> [LearningRecommendation] {
        var recs: [LearningRecommendation] = []

        // Overall performance trend
        if analytics.averageGrade >= 85 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .performanceTrend,
                title: "Excellent Performance",
                description: "Your average grade of \(String(format: "%.0f%%", analytics.averageGrade)) puts you among top performers. Keep up this outstanding work across your \(grades.count) courses.",
                priority: .low,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "star.fill",
                actionLabel: "View Grades"
            ))
        } else if analytics.averageGrade < 70 && analytics.averageGrade > 0 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .performanceTrend,
                title: "Room for Improvement",
                description: "Your current average is \(String(format: "%.0f%%", analytics.averageGrade)). Consider dedicating extra study time to \(analytics.weakSubjects.first ?? "challenging courses"). Small improvements add up!",
                priority: .high,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "chart.line.uptrend.xyaxis",
                actionLabel: "Study Plan"
            ))
        }

        // Predicted vs actual performance gap
        let gap = analytics.predictedPerformance - analytics.averageGrade
        if gap > 10 && analytics.averageGrade > 0 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .performanceTrend,
                title: "Untapped Potential Detected",
                description: "Based on your study patterns, our model predicts you could achieve \(String(format: "%.0f%%", analytics.predictedPerformance)). Increase your completion rate and review weak areas to close this gap.",
                priority: .medium,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "arrow.up.right.circle.fill",
                actionLabel: "Improve"
            ))
        }

        return recs
    }

    private func generateStudyTimeRecommendations() -> [LearningRecommendation] {
        guard completionTimestamps.count >= 5 else { return [] }

        // Analyze which hour of day the student completes most lessons
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        for timestamp in completionTimestamps {
            let hour = calendar.component(.hour, from: timestamp)
            hourCounts[hour, default: 0] += 1
        }

        guard let bestHour = hourCounts.max(by: { $0.value < $1.value })?.key else { return [] }

        let timeLabel: String
        switch bestHour {
        case 5..<12: timeLabel = "morning"
        case 12..<17: timeLabel = "afternoon"
        case 17..<21: timeLabel = "evening"
        default: timeLabel = "night"
        }

        let formattedHour: String
        if bestHour == 0 {
            formattedHour = "12 AM"
        } else if bestHour < 12 {
            formattedHour = "\(bestHour) AM"
        } else if bestHour == 12 {
            formattedHour = "12 PM"
        } else {
            formattedHour = "\(bestHour - 12) PM"
        }

        return [
            LearningRecommendation(
                id: UUID(),
                type: .studyTimeOptimal,
                title: "Your Best Study Time",
                description: "You are most productive in the \(timeLabel) around \(formattedHour). Schedule your most challenging lessons during this window for better results.",
                priority: .low,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "clock.fill",
                actionLabel: "Set Reminder"
            )
        ]
    }

    private func generateLearningStyleRecommendations(courses: [Course], analytics: StudentAnalytics) -> [LearningRecommendation] {
        let style = analytics.preferredLearningStyle
        let styleName = style.rawValue.lowercased()

        let description: String
        switch style {
        case .video:
            description = "You complete video lessons at the highest rate. Look for courses with strong video content and consider recording your own study summaries."
        case .reading:
            description = "You excel with reading-based material. Try annotating key concepts and creating summary notes to maximize retention."
        case .activity:
            description = "Hands-on activities are your strength. Seek out interactive exercises and practice problems to reinforce what you learn."
        case .quiz:
            description = "You thrive on quiz-based learning. Use flashcards and self-testing to reinforce your knowledge across all subjects."
        }

        // Count incomplete lessons of the preferred type
        var availableLessonsOfType = 0
        for course in courses {
            for module in course.modules {
                availableLessonsOfType += module.lessons.filter { $0.type == style && !$0.isCompleted }.count
            }
        }

        var recs = [
            LearningRecommendation(
                id: UUID(),
                type: .learningStyle,
                title: "Your Learning Style: \(style.rawValue)",
                description: description,
                priority: .low,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: style.iconName,
                actionLabel: "Browse \(style.rawValue) Lessons"
            )
        ]

        if availableLessonsOfType > 0 {
            recs.append(LearningRecommendation(
                id: UUID(),
                type: .learningStyle,
                title: "\(availableLessonsOfType) \(style.rawValue) Lessons Available",
                description: "There are \(availableLessonsOfType) \(styleName) lessons you have not completed yet. Since this matches your learning preference, these are a great place to start.",
                priority: .medium,
                relatedCourseId: nil,
                relatedAssignmentId: nil,
                iconSystemName: "sparkles",
                actionLabel: "View Lessons"
            ))
        }

        return recs
    }
}
