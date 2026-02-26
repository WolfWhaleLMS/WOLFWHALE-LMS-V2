//
//  GradeCalculationServiceTests.swift
//  WolfWhaleLMSTests
//
//  Created by Rork on February 26, 2026.
//

import XCTest
import SwiftUI
@testable import WolfWhaleLMS

// MARK: - GradeCalculationService Tests

@MainActor
final class GradeCalculationServiceTests: XCTestCase {

    private var service: GradeCalculationService!

    override func setUp() {
        super.setUp()
        service = GradeCalculationService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Factory Helpers

    private func makeAssignmentGrade(
        score: Double,
        maxScore: Double,
        type: String = "homework",
        daysAgo: Int = 0
    ) -> AssignmentGrade {
        AssignmentGrade(
            id: UUID(),
            title: "Test Grade",
            score: score,
            maxScore: maxScore,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            type: type
        )
    }

    private func makeGradeEntry(
        courseId: UUID,
        assignmentGrades: [AssignmentGrade]
    ) -> GradeEntry {
        GradeEntry(
            id: UUID(),
            courseId: courseId,
            courseName: "Test Course",
            courseIcon: "book.fill",
            courseColor: "blue",
            letterGrade: "A",
            numericGrade: 95.0,
            assignmentGrades: assignmentGrades
        )
    }

    // MARK: - letterGrade(from:) Tests

    func test_letterGrade_A_plus_at97() {
        XCTAssertEqual(service.letterGrade(from: 97.0), "A+")
    }

    func test_letterGrade_A_plus_at100() {
        XCTAssertEqual(service.letterGrade(from: 100.0), "A+")
    }

    func test_letterGrade_A_plus_above100_extraCredit() {
        XCTAssertEqual(service.letterGrade(from: 105.0), "A+")
    }

    func test_letterGrade_A_at93() {
        XCTAssertEqual(service.letterGrade(from: 93.0), "A")
    }

    func test_letterGrade_A_at96point9() {
        XCTAssertEqual(service.letterGrade(from: 96.9), "A")
    }

    func test_letterGrade_A_minus_at90() {
        XCTAssertEqual(service.letterGrade(from: 90.0), "A-")
    }

    func test_letterGrade_A_minus_at92point9() {
        XCTAssertEqual(service.letterGrade(from: 92.9), "A-")
    }

    func test_letterGrade_B_plus_at87() {
        XCTAssertEqual(service.letterGrade(from: 87.0), "B+")
    }

    func test_letterGrade_B_plus_at89point9() {
        XCTAssertEqual(service.letterGrade(from: 89.9), "B+")
    }

    func test_letterGrade_B_at83() {
        XCTAssertEqual(service.letterGrade(from: 83.0), "B")
    }

    func test_letterGrade_B_at86point9() {
        XCTAssertEqual(service.letterGrade(from: 86.9), "B")
    }

    func test_letterGrade_B_minus_at80() {
        XCTAssertEqual(service.letterGrade(from: 80.0), "B-")
    }

    func test_letterGrade_B_minus_at82point9() {
        XCTAssertEqual(service.letterGrade(from: 82.9), "B-")
    }

    func test_letterGrade_C_plus_at77() {
        XCTAssertEqual(service.letterGrade(from: 77.0), "C+")
    }

    func test_letterGrade_C_at73() {
        XCTAssertEqual(service.letterGrade(from: 73.0), "C")
    }

    func test_letterGrade_C_minus_at70() {
        XCTAssertEqual(service.letterGrade(from: 70.0), "C-")
    }

    func test_letterGrade_D_plus_at67() {
        XCTAssertEqual(service.letterGrade(from: 67.0), "D+")
    }

    func test_letterGrade_D_at63() {
        XCTAssertEqual(service.letterGrade(from: 63.0), "D")
    }

    func test_letterGrade_D_minus_at60() {
        XCTAssertEqual(service.letterGrade(from: 60.0), "D-")
    }

    func test_letterGrade_F_at59point9() {
        XCTAssertEqual(service.letterGrade(from: 59.9), "F")
    }

    func test_letterGrade_F_atZero() {
        XCTAssertEqual(service.letterGrade(from: 0.0), "F")
    }

    func test_letterGrade_F_atNegativeValue() {
        XCTAssertEqual(service.letterGrade(from: -5.0), "F")
    }

    // MARK: - gradePoints(from:) Tests

    func test_gradePoints_A_plus_returns4point0() {
        XCTAssertEqual(service.gradePoints(from: 97.0), 4.0)
    }

    func test_gradePoints_A_returns4point0() {
        XCTAssertEqual(service.gradePoints(from: 95.0), 4.0)
    }

    func test_gradePoints_A_minus_returns3point7() {
        XCTAssertEqual(service.gradePoints(from: 91.0), 3.7)
    }

    func test_gradePoints_B_plus_returns3point3() {
        XCTAssertEqual(service.gradePoints(from: 88.0), 3.3)
    }

    func test_gradePoints_B_returns3point0() {
        XCTAssertEqual(service.gradePoints(from: 85.0), 3.0)
    }

    func test_gradePoints_B_minus_returns2point7() {
        XCTAssertEqual(service.gradePoints(from: 81.0), 2.7)
    }

    func test_gradePoints_C_plus_returns2point3() {
        XCTAssertEqual(service.gradePoints(from: 78.0), 2.3)
    }

    func test_gradePoints_C_returns2point0() {
        XCTAssertEqual(service.gradePoints(from: 75.0), 2.0)
    }

    func test_gradePoints_C_minus_returns1point7() {
        XCTAssertEqual(service.gradePoints(from: 71.0), 1.7)
    }

    func test_gradePoints_D_plus_returns1point3() {
        XCTAssertEqual(service.gradePoints(from: 68.0), 1.3)
    }

    func test_gradePoints_D_returns1point0() {
        XCTAssertEqual(service.gradePoints(from: 65.0), 1.0)
    }

    func test_gradePoints_D_minus_returns0point7() {
        XCTAssertEqual(service.gradePoints(from: 61.0), 0.7)
    }

    func test_gradePoints_F_returns0point0() {
        XCTAssertEqual(service.gradePoints(from: 50.0), 0.0)
    }

    func test_gradePoints_zero_returns0point0() {
        XCTAssertEqual(service.gradePoints(from: 0.0), 0.0)
    }

    func test_gradePoints_negative_returns0point0() {
        XCTAssertEqual(service.gradePoints(from: -10.0), 0.0)
    }

    func test_gradePoints_extraCredit_above100_returns4point0() {
        XCTAssertEqual(service.gradePoints(from: 110.0), 4.0)
    }

    // MARK: - gradeColor(from:) Tests

    func test_gradeColor_90_plus_returnsGreen() {
        XCTAssertEqual(service.gradeColor(from: 95.0), Color.green)
    }

    func test_gradeColor_exactly90_returnsGreen() {
        XCTAssertEqual(service.gradeColor(from: 90.0), Color.green)
    }

    func test_gradeColor_80to89_returnsBlue() {
        XCTAssertEqual(service.gradeColor(from: 85.0), Color.blue)
    }

    func test_gradeColor_exactly80_returnsBlue() {
        XCTAssertEqual(service.gradeColor(from: 80.0), Color.blue)
    }

    func test_gradeColor_70to79_returnsYellow() {
        XCTAssertEqual(service.gradeColor(from: 75.0), Color.yellow)
    }

    func test_gradeColor_exactly70_returnsYellow() {
        XCTAssertEqual(service.gradeColor(from: 70.0), Color.yellow)
    }

    func test_gradeColor_60to69_returnsOrange() {
        XCTAssertEqual(service.gradeColor(from: 65.0), Color.orange)
    }

    func test_gradeColor_exactly60_returnsOrange() {
        XCTAssertEqual(service.gradeColor(from: 60.0), Color.orange)
    }

    func test_gradeColor_below60_returnsRed() {
        XCTAssertEqual(service.gradeColor(from: 50.0), Color.red)
    }

    func test_gradeColor_zero_returnsRed() {
        XCTAssertEqual(service.gradeColor(from: 0.0), Color.red)
    }

    func test_gradeColor_negative_returnsRed() {
        XCTAssertEqual(service.gradeColor(from: -10.0), Color.red)
    }

    func test_gradeColor_extraCredit_above100_returnsGreen() {
        XCTAssertEqual(service.gradeColor(from: 105.0), Color.green)
    }

    // MARK: - calculateGPA(courseResults:) Tests

    func test_calculateGPA_emptyInput_returnsZero() {
        let gpa = service.calculateGPA(courseResults: [])
        XCTAssertEqual(gpa, 0.0)
    }

    func test_calculateGPA_singleCourse() {
        let result = CourseGradeResult(
            courseId: UUID(),
            courseName: "Math",
            overallPercentage: 95.0,
            letterGrade: "A",
            gradePoints: 4.0,
            breakdowns: [],
            trend: .stable
        )
        let gpa = service.calculateGPA(courseResults: [result])
        XCTAssertEqual(gpa, 4.0, accuracy: 0.001)
    }

    func test_calculateGPA_multipleCourses_averagesGradePoints() {
        let results = [
            CourseGradeResult(
                courseId: UUID(), courseName: "Math",
                overallPercentage: 95.0, letterGrade: "A",
                gradePoints: 4.0, breakdowns: [], trend: .stable
            ),
            CourseGradeResult(
                courseId: UUID(), courseName: "English",
                overallPercentage: 85.0, letterGrade: "B",
                gradePoints: 3.0, breakdowns: [], trend: .stable
            ),
            CourseGradeResult(
                courseId: UUID(), courseName: "History",
                overallPercentage: 75.0, letterGrade: "C",
                gradePoints: 2.0, breakdowns: [], trend: .declining
            ),
        ]
        let gpa = service.calculateGPA(courseResults: results)
        XCTAssertEqual(gpa, 3.0, accuracy: 0.001) // (4.0 + 3.0 + 2.0) / 3
    }

    func test_calculateGPA_allFailing_returnsZero() {
        let results = [
            CourseGradeResult(
                courseId: UUID(), courseName: "Math",
                overallPercentage: 40.0, letterGrade: "F",
                gradePoints: 0.0, breakdowns: [], trend: .declining
            ),
            CourseGradeResult(
                courseId: UUID(), courseName: "Science",
                overallPercentage: 30.0, letterGrade: "F",
                gradePoints: 0.0, breakdowns: [], trend: .declining
            ),
        ]
        let gpa = service.calculateGPA(courseResults: results)
        XCTAssertEqual(gpa, 0.0, accuracy: 0.001)
    }

    // MARK: - calculateTrend(grades:) Tests

    func test_calculateTrend_lessThanTwoGrades_returnsStable() {
        let courseId = UUID()
        let grades = [
            makeGradeEntry(courseId: courseId, assignmentGrades: [
                makeAssignmentGrade(score: 90, maxScore: 100, daysAgo: 1)
            ])
        ]
        let trend = service.calculateTrend(grades: grades)
        XCTAssertEqual(trend, .stable)
    }

    func test_calculateTrend_emptyGrades_returnsStable() {
        let trend = service.calculateTrend(grades: [])
        XCTAssertEqual(trend, .stable)
    }

    func test_calculateTrend_improvingScores_returnsImproving() {
        let courseId = UUID()
        // Older scores are low, recent scores are high
        let assignmentGrades = [
            makeAssignmentGrade(score: 60, maxScore: 100, daysAgo: 30),
            makeAssignmentGrade(score: 62, maxScore: 100, daysAgo: 25),
            makeAssignmentGrade(score: 65, maxScore: 100, daysAgo: 20),
            makeAssignmentGrade(score: 68, maxScore: 100, daysAgo: 15),
            makeAssignmentGrade(score: 70, maxScore: 100, daysAgo: 10),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 5),
            makeAssignmentGrade(score: 88, maxScore: 100, daysAgo: 4),
            makeAssignmentGrade(score: 90, maxScore: 100, daysAgo: 3),
            makeAssignmentGrade(score: 92, maxScore: 100, daysAgo: 2),
            makeAssignmentGrade(score: 95, maxScore: 100, daysAgo: 1),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]
        let trend = service.calculateTrend(grades: grades)
        XCTAssertEqual(trend, .improving)
    }

    func test_calculateTrend_decliningScores_returnsDeclining() {
        let courseId = UUID()
        // Older scores are high, recent scores are low
        let assignmentGrades = [
            makeAssignmentGrade(score: 95, maxScore: 100, daysAgo: 30),
            makeAssignmentGrade(score: 93, maxScore: 100, daysAgo: 25),
            makeAssignmentGrade(score: 90, maxScore: 100, daysAgo: 20),
            makeAssignmentGrade(score: 88, maxScore: 100, daysAgo: 15),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 10),
            makeAssignmentGrade(score: 65, maxScore: 100, daysAgo: 5),
            makeAssignmentGrade(score: 62, maxScore: 100, daysAgo: 4),
            makeAssignmentGrade(score: 60, maxScore: 100, daysAgo: 3),
            makeAssignmentGrade(score: 58, maxScore: 100, daysAgo: 2),
            makeAssignmentGrade(score: 55, maxScore: 100, daysAgo: 1),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]
        let trend = service.calculateTrend(grades: grades)
        XCTAssertEqual(trend, .declining)
    }

    func test_calculateTrend_stableScores_returnsStable() {
        let courseId = UUID()
        // All scores are roughly the same (within 2% delta)
        let assignmentGrades = [
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 30),
            makeAssignmentGrade(score: 84, maxScore: 100, daysAgo: 25),
            makeAssignmentGrade(score: 86, maxScore: 100, daysAgo: 20),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 15),
            makeAssignmentGrade(score: 84, maxScore: 100, daysAgo: 10),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 5),
            makeAssignmentGrade(score: 86, maxScore: 100, daysAgo: 4),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 3),
            makeAssignmentGrade(score: 84, maxScore: 100, daysAgo: 2),
            makeAssignmentGrade(score: 85, maxScore: 100, daysAgo: 1),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]
        let trend = service.calculateTrend(grades: grades)
        XCTAssertEqual(trend, .stable)
    }

    // MARK: - calculateCourseGrade() Tests

    func test_calculateCourseGrade_noGrades_returnsZero() {
        let courseId = UUID()
        let result = service.calculateCourseGrade(
            grades: [],
            weights: .default,
            courseId: courseId,
            courseName: "Empty Course"
        )
        XCTAssertEqual(result.overallPercentage, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.letterGrade, "F")
        XCTAssertEqual(result.gradePoints, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.courseId, courseId)
        XCTAssertEqual(result.courseName, "Empty Course")
    }

    func test_calculateCourseGrade_singleCategory_assignmentsOnly() {
        let courseId = UUID()
        let assignmentGrades = [
            makeAssignmentGrade(score: 90, maxScore: 100, type: "homework"),
            makeAssignmentGrade(score: 85, maxScore: 100, type: "homework"),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "Math"
        )

        // Only assignment category has data, so it gets renormalized to 100% weight.
        // Assignment percentage: (90+85)/(100+100) = 87.5%
        XCTAssertEqual(result.overallPercentage, 87.5, accuracy: 0.1)
        XCTAssertEqual(result.letterGrade, "B+")
    }

    func test_calculateCourseGrade_multipleCategories_withDefaultWeights() {
        let courseId = UUID()

        // Assignments: 90/100 = 90% (weight 0.40)
        // Quizzes: 80/100 = 80% (weight 0.30)
        // Participation: 100/100 = 100% (weight 0.20)
        // Attendance: 95/100 = 95% (weight 0.10)
        let assignmentGrades = [
            makeAssignmentGrade(score: 90, maxScore: 100, type: "homework"),
            makeAssignmentGrade(score: 80, maxScore: 100, type: "quiz"),
            makeAssignmentGrade(score: 100, maxScore: 100, type: "participation"),
            makeAssignmentGrade(score: 95, maxScore: 100, type: "attendance"),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "Science"
        )

        // Weighted: 90*0.40 + 80*0.30 + 100*0.20 + 95*0.10 = 36+24+20+9.5 = 89.5
        // Total weight = 1.0, so overall = 89.5 / 1.0 = 89.5%
        XCTAssertEqual(result.overallPercentage, 89.5, accuracy: 0.1)
        XCTAssertEqual(result.letterGrade, "B+")
    }

    func test_calculateCourseGrade_customWeights() {
        let courseId = UUID()

        // Custom weights: assignments 60%, quizzes 40%
        let customWeights = GradeWeights(
            assignments: 0.60,
            quizzes: 0.40,
            participation: 0.00,
            attendance: 0.00
        )

        let assignmentGrades = [
            makeAssignmentGrade(score: 100, maxScore: 100, type: "homework"),
            makeAssignmentGrade(score: 70, maxScore: 100, type: "quiz"),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: customWeights,
            courseId: courseId,
            courseName: "Art"
        )

        // Assignments: 100% * 0.60 = 60, Quizzes: 70% * 0.40 = 28
        // Total weight with data: 0.60 + 0.40 = 1.0
        // Overall: (60+28)/1.0 = 88%
        XCTAssertEqual(result.overallPercentage, 88.0, accuracy: 0.1)
    }

    func test_calculateCourseGrade_extraCredit_above100percent() {
        let courseId = UUID()

        let assignmentGrades = [
            makeAssignmentGrade(score: 110, maxScore: 100, type: "homework"),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "Bonus Course"
        )

        // 110/100 = 110%, renormalized to just assignment weight
        XCTAssertEqual(result.overallPercentage, 110.0, accuracy: 0.1)
        XCTAssertEqual(result.letterGrade, "A+")
    }

    func test_calculateCourseGrade_filtersByCourseId() {
        let targetCourseId = UUID()
        let otherCourseId = UUID()

        // Only the grade entry matching targetCourseId should be used
        let targetGrades = [makeAssignmentGrade(score: 90, maxScore: 100, type: "homework")]
        let otherGrades = [makeAssignmentGrade(score: 50, maxScore: 100, type: "homework")]

        let grades = [
            makeGradeEntry(courseId: targetCourseId, assignmentGrades: targetGrades),
            makeGradeEntry(courseId: otherCourseId, assignmentGrades: otherGrades),
        ]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: targetCourseId,
            courseName: "Target"
        )

        // Should only use the 90/100 grade
        XCTAssertEqual(result.overallPercentage, 90.0, accuracy: 0.1)
    }

    func test_calculateCourseGrade_breakdownsHaveAllCategories() {
        let courseId = UUID()
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: [])]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "Test"
        )

        // Should have breakdowns for all four categories
        XCTAssertEqual(result.breakdowns.count, GradeCategory.allCases.count)
    }

    func test_calculateCourseGrade_renormalizesWeights_whenCategoriesMissing() {
        let courseId = UUID()

        // Only assignments and quizzes have data; participation and attendance are empty
        let assignmentGrades = [
            makeAssignmentGrade(score: 80, maxScore: 100, type: "homework"),
            makeAssignmentGrade(score: 90, maxScore: 100, type: "quiz"),
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "Renorm"
        )

        // Assignments: 80%, weight 0.40. Quizzes: 90%, weight 0.30.
        // Active weight = 0.40 + 0.30 = 0.70
        // Weighted: 80*0.40 + 90*0.30 = 32 + 27 = 59
        // Re-normalized: 59 / 0.70 = 84.29%
        XCTAssertEqual(result.overallPercentage, 84.29, accuracy: 0.5)
    }

    func test_calculateCourseGrade_zeroMaxScore_treatedAsZeroPercent() {
        let courseId = UUID()
        // Assignment with zero max score -- division by zero guard
        let assignmentGrades = [
            AssignmentGrade(
                id: UUID(), title: "Zero Max", score: 10, maxScore: 0,
                date: Date(), type: "homework"
            )
        ]
        let grades = [makeGradeEntry(courseId: courseId, assignmentGrades: assignmentGrades)]

        let result = service.calculateCourseGrade(
            grades: grades,
            weights: .default,
            courseId: courseId,
            courseName: "ZeroMax"
        )

        // maxScore is 0 but score is 10; earned=10, total=0, so percentage=0
        // This means there are no "active" breakdowns (totalPoints > 0), so overall = 0
        XCTAssertEqual(result.overallPercentage, 0.0, accuracy: 0.001)
    }

    // MARK: - categorize(_:) Tests

    func test_categorize_quiz_type() {
        XCTAssertEqual(service.categorize("quiz"), .quiz)
        XCTAssertEqual(service.categorize("Quiz"), .quiz)
        XCTAssertEqual(service.categorize("Weekly Quiz"), .quiz)
    }

    func test_categorize_attendance_type() {
        XCTAssertEqual(service.categorize("attendance"), .attendance)
        XCTAssertEqual(service.categorize("Attend"), .attendance)
        XCTAssertEqual(service.categorize("Daily Attendance"), .attendance)
    }

    func test_categorize_participation_type() {
        XCTAssertEqual(service.categorize("participation"), .participation)
        XCTAssertEqual(service.categorize("Class Participation"), .participation)
    }

    func test_categorize_assignment_defaultsForOtherTypes() {
        XCTAssertEqual(service.categorize("homework"), .assignment)
        XCTAssertEqual(service.categorize("midterm"), .assignment)
        XCTAssertEqual(service.categorize("final exam"), .assignment)
        XCTAssertEqual(service.categorize("essay"), .assignment)
        XCTAssertEqual(service.categorize("lab"), .assignment)
        XCTAssertEqual(service.categorize("project"), .assignment)
    }

    // MARK: - percentageNeeded() Tests

    func test_percentageNeeded_achievableTarget() {
        // Currently earned 80/100, remaining 100 points, target 90%
        let needed = service.percentageNeeded(
            currentEarned: 80,
            currentTotal: 100,
            remainingTotal: 100,
            targetPercentage: 90
        )
        XCTAssertNotNil(needed)
        // Need 90% of 200 = 180. Already have 80. Need 100 out of 100 = 100%
        XCTAssertEqual(needed!, 100.0, accuracy: 0.1)
    }

    func test_percentageNeeded_easyTarget() {
        // Currently earned 90/100, remaining 100 points, target 50%
        let needed = service.percentageNeeded(
            currentEarned: 90,
            currentTotal: 100,
            remainingTotal: 100,
            targetPercentage: 50
        )
        XCTAssertNotNil(needed)
        // Need 50% of 200 = 100. Already have 90. Need 10 out of 100 = 10%
        XCTAssertEqual(needed!, 10.0, accuracy: 0.1)
    }

    func test_percentageNeeded_impossibleTarget_returnsNil() {
        // Currently earned 0/100, remaining 50 points, target 90%
        let needed = service.percentageNeeded(
            currentEarned: 0,
            currentTotal: 100,
            remainingTotal: 50,
            targetPercentage: 90
        )
        // Need 90% of 150 = 135. Already have 0. Need 135 out of 50 = 270% -- impossible
        XCTAssertNil(needed)
    }

    func test_percentageNeeded_zeroRemaining_returnsNil() {
        let needed = service.percentageNeeded(
            currentEarned: 80,
            currentTotal: 100,
            remainingTotal: 0,
            targetPercentage: 90
        )
        XCTAssertNil(needed)
    }

    func test_percentageNeeded_alreadyMeetingTarget_returnsZero() {
        // Already have 90/100 and want 45%. Remaining 100 points.
        let needed = service.percentageNeeded(
            currentEarned: 90,
            currentTotal: 100,
            remainingTotal: 100,
            targetPercentage: 45
        )
        XCTAssertNotNil(needed)
        // Need 45% of 200 = 90. Already have 90. Need 0 out of 100 = 0%
        XCTAssertEqual(needed!, 0.0, accuracy: 0.1)
    }

    // MARK: - GradeWeights Tests

    func test_gradeWeights_default_isValid() {
        XCTAssertTrue(GradeWeights.default.isValid)
    }

    func test_gradeWeights_default_sumsToOne() {
        let w = GradeWeights.default
        let sum = w.assignments + w.quizzes + w.participation + w.attendance
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func test_gradeWeights_invalidWeights() {
        let badWeights = GradeWeights(
            assignments: 0.50,
            quizzes: 0.50,
            participation: 0.50,
            attendance: 0.50
        )
        XCTAssertFalse(badWeights.isValid)
    }

    func test_gradeWeights_weightForCategory() {
        let w = GradeWeights.default
        XCTAssertEqual(w.weight(for: .assignment), 0.40)
        XCTAssertEqual(w.weight(for: .quiz), 0.30)
        XCTAssertEqual(w.weight(for: .participation), 0.20)
        XCTAssertEqual(w.weight(for: .attendance), 0.10)
    }

    func test_gradeWeights_settingCategory() {
        let original = GradeWeights.default
        let updated = original.setting(.assignment, to: 0.50)
        XCTAssertEqual(updated.assignments, 0.50)
        // Other weights should be unchanged
        XCTAssertEqual(updated.quizzes, original.quizzes)
        XCTAssertEqual(updated.participation, original.participation)
        XCTAssertEqual(updated.attendance, original.attendance)
    }

    // MARK: - GradeCategory Tests

    func test_gradeCategory_displayName() {
        XCTAssertEqual(GradeCategory.assignment.displayName, "Assignments")
        XCTAssertEqual(GradeCategory.quiz.displayName, "Quizzes")
        XCTAssertEqual(GradeCategory.participation.displayName, "Participation")
        XCTAssertEqual(GradeCategory.attendance.displayName, "Attendance")
    }

    func test_gradeCategory_allCases_hasFourCategories() {
        XCTAssertEqual(GradeCategory.allCases.count, 4)
    }

    // MARK: - GradeTrend Tests

    func test_gradeTrend_displayName() {
        XCTAssertEqual(GradeTrend.improving.displayName, "Improving")
        XCTAssertEqual(GradeTrend.declining.displayName, "Declining")
        XCTAssertEqual(GradeTrend.stable.displayName, "Stable")
    }

    func test_gradeTrend_iconName() {
        XCTAssertEqual(GradeTrend.improving.iconName, "arrow.up.right")
        XCTAssertEqual(GradeTrend.declining.iconName, "arrow.down.right")
        XCTAssertEqual(GradeTrend.stable.iconName, "arrow.right")
    }

    func test_gradeTrend_color() {
        XCTAssertEqual(GradeTrend.improving.color, "green")
        XCTAssertEqual(GradeTrend.declining.color, "red")
        XCTAssertEqual(GradeTrend.stable.color, "gray")
    }
}
