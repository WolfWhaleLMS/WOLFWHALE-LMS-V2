//
//  WolfWhaleLMSTests.swift
//  WolfWhaleLMSTests
//
//  Created by Rork on February 20, 2026.
//

import XCTest
@testable import WolfWhaleLMS

// MARK: - InputValidator Tests

final class InputValidatorTests: XCTestCase {

    // MARK: sanitizeHTML

    func test_sanitizeHTML_stripsScriptTags() {
        let input = "<script>alert('xss')</script>Hello"
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertFalse(result.contains("</script>"))
        XCTAssertTrue(result.contains("Hello"))
    }

    func test_sanitizeHTML_stripsEntityEncodedScriptTags() {
        let input = "&lt;script&gt;alert('xss')&lt;/script&gt;Safe text"
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertFalse(result.contains("<script>"), "Decoded <script> tag should be stripped")
        XCTAssertFalse(result.contains("&lt;script&gt;"), "Entity-encoded script tag should be decoded and stripped")
        XCTAssertTrue(result.contains("Safe text"))
    }

    func test_sanitizeHTML_stripsImgTagWithOnerror() {
        let input = #"<img src=x onerror="alert('xss')">"#
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertFalse(result.contains("<img"))
        XCTAssertFalse(result.contains("onerror"))
    }

    func test_sanitizeHTML_preservesPlainText() {
        let input = "Hello, this is plain text with no HTML."
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertEqual(result, input)
    }

    func test_sanitizeHTML_decodesHTMLEntities() {
        let input = "5 &gt; 3 &amp; 2 &lt; 4"
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertEqual(result, "5 > 3 & 2 < 4")
    }

    func test_sanitizeHTML_handlesDoubleEncodedTags() {
        // Double-encoded: &amp;lt;script&amp;gt; -> &lt;script&gt; -> <script>
        let input = "&amp;lt;script&amp;gt;alert('xss')&amp;lt;/script&amp;gt;"
        let result = InputValidator.sanitizeHTML(input)
        XCTAssertFalse(result.contains("<script>"), "Double-encoded script tags should be caught by iterative decoding")
    }

    // MARK: validateEmail

    func test_validateEmail_acceptsValidEmail() {
        XCTAssertTrue(InputValidator.validateEmail("user@example.com"))
    }

    func test_validateEmail_acceptsEmailWithSubdomain() {
        XCTAssertTrue(InputValidator.validateEmail("user@mail.example.com"))
    }

    func test_validateEmail_acceptsEmailWithPlus() {
        XCTAssertTrue(InputValidator.validateEmail("user+tag@example.com"))
    }

    func test_validateEmail_rejectsEmptyString() {
        XCTAssertFalse(InputValidator.validateEmail(""))
    }

    func test_validateEmail_rejectsEmailWithoutAtSign() {
        XCTAssertFalse(InputValidator.validateEmail("userexample.com"))
    }

    func test_validateEmail_rejectsEmailWithoutDomain() {
        XCTAssertFalse(InputValidator.validateEmail("user@"))
    }

    func test_validateEmail_rejectsEmailWithoutTLD() {
        XCTAssertFalse(InputValidator.validateEmail("user@example"))
    }

    func test_validateEmail_rejectsEmailWithSpaces() {
        XCTAssertFalse(InputValidator.validateEmail("user @example.com"))
    }

    func test_validateEmail_trimsWhitespace() {
        XCTAssertTrue(InputValidator.validateEmail("  user@example.com  "))
    }

    // MARK: validatePassword

    func test_validatePassword_acceptsStrongPassword() {
        let result = InputValidator.validatePassword("Abcdef1!")
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.message, "")
    }

    func test_validatePassword_rejectsTooShortPassword() {
        let result = InputValidator.validatePassword("Ab1!")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("8 characters"))
    }

    func test_validatePassword_rejectsPasswordWithoutUppercase() {
        let result = InputValidator.validatePassword("abcdefg1")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("uppercase"))
    }

    func test_validatePassword_rejectsPasswordWithoutLowercase() {
        let result = InputValidator.validatePassword("ABCDEFG1")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("lowercase"))
    }

    func test_validatePassword_rejectsPasswordWithoutDigit() {
        let result = InputValidator.validatePassword("Abcdefgh")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("number"))
    }

    // MARK: sanitizeText

    func test_sanitizeText_trimsWhitespace() {
        let result = InputValidator.sanitizeText("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func test_sanitizeText_truncatesAtMaxLength() {
        let longString = String(repeating: "a", count: 100)
        let result = InputValidator.sanitizeText(longString, maxLength: 10)
        XCTAssertEqual(result.count, 10)
    }

    func test_sanitizeText_preservesNewlinesAndTabs() {
        let input = "Line 1\nLine 2\tTabbed"
        let result = InputValidator.sanitizeText(input)
        XCTAssertTrue(result.contains("\n"))
        XCTAssertTrue(result.contains("\t"))
    }

    // MARK: validateCourseName

    func test_validateCourseName_acceptsValidName() {
        let result = InputValidator.validateCourseName("Algebra I")
        XCTAssertTrue(result.valid)
    }

    func test_validateCourseName_rejectsTooShortName() {
        let result = InputValidator.validateCourseName("AB")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("3 characters"))
    }

    func test_validateCourseName_rejectsTooLongName() {
        let longName = String(repeating: "A", count: 101)
        let result = InputValidator.validateCourseName(longName)
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message.contains("100 characters"))
    }

    // MARK: validatePoints & validateGrade

    func test_validatePoints_acceptsValidRange() {
        XCTAssertTrue(InputValidator.validatePoints(0))
        XCTAssertTrue(InputValidator.validatePoints(500))
        XCTAssertTrue(InputValidator.validatePoints(1000))
    }

    func test_validatePoints_rejectsOutOfRange() {
        XCTAssertFalse(InputValidator.validatePoints(-1))
        XCTAssertFalse(InputValidator.validatePoints(1001))
    }

    func test_validateGrade_acceptsValidRange() {
        XCTAssertTrue(InputValidator.validateGrade(0))
        XCTAssertTrue(InputValidator.validateGrade(100))
        XCTAssertTrue(InputValidator.validateGrade(150)) // extra credit
    }

    func test_validateGrade_rejectsNegative() {
        XCTAssertFalse(InputValidator.validateGrade(-1))
    }

    func test_validateGrade_rejectsAbove200() {
        XCTAssertFalse(InputValidator.validateGrade(201))
    }

    // MARK: validateFileSize & validateFileType

    func test_validateFileSize_acceptsWithinLimit() {
        let oneMB: Int64 = 1_048_576
        XCTAssertTrue(InputValidator.validateFileSize(oneMB, maxMB: 5))
    }

    func test_validateFileSize_rejectsOverLimit() {
        let sixMB: Int64 = 6 * 1_048_576
        XCTAssertFalse(InputValidator.validateFileSize(sixMB, maxMB: 5))
    }

    func test_validateFileType_acceptsAllowedExtension() {
        XCTAssertTrue(InputValidator.validateFileType("report.pdf", allowed: ["pdf", "docx"]))
    }

    func test_validateFileType_rejectsDisallowedExtension() {
        XCTAssertFalse(InputValidator.validateFileType("malware.exe", allowed: ["pdf", "docx"]))
    }

    func test_validateFileType_isCaseInsensitive() {
        XCTAssertTrue(InputValidator.validateFileType("photo.PNG", allowed: ["png", "jpg"]))
    }
}

// MARK: - Assignment Model Tests

final class AssignmentTests: XCTestCase {

    // MARK: Helpers

    /// Creates a base assignment with sensible defaults that can be customized per test.
    private func makeAssignment(
        dueDate: Date = Date().addingTimeInterval(86400), // tomorrow
        isSubmitted: Bool = false,
        grade: Double? = nil,
        points: Int = 100,
        latePenaltyType: LatePenaltyType = .none,
        latePenaltyPerDay: Double = 0,
        maxLateDays: Int = 7,
        allowResubmission: Bool = false,
        maxResubmissions: Int = 1,
        resubmissionCount: Int = 0,
        resubmissionDeadline: Date? = nil,
        feedback: String? = nil
    ) -> Assignment {
        var assignment = Assignment(
            id: UUID(),
            title: "Test Assignment",
            courseId: UUID(),
            courseName: "Test Course",
            instructions: "Do the work",
            dueDate: dueDate,
            points: points,
            isSubmitted: isSubmitted,
            submission: isSubmitted ? "My submission text" : nil,
            grade: grade,
            feedback: feedback,
            xpReward: 50
        )
        assignment.latePenaltyType = latePenaltyType
        assignment.latePenaltyPerDay = latePenaltyPerDay
        assignment.maxLateDays = maxLateDays
        assignment.allowResubmission = allowResubmission
        assignment.maxResubmissions = maxResubmissions
        assignment.resubmissionCount = resubmissionCount
        assignment.resubmissionDeadline = resubmissionDeadline
        return assignment
    }

    // MARK: isOverdue

    func test_assignment_isOverdue_whenPastDueAndNotSubmitted_returnsTrue() {
        let pastDue = Date().addingTimeInterval(-86400) // yesterday
        let assignment = makeAssignment(dueDate: pastDue, isSubmitted: false)
        XCTAssertTrue(assignment.isOverdue)
    }

    func test_assignment_isOverdue_whenPastDueAndSubmitted_returnsFalse() {
        let pastDue = Date().addingTimeInterval(-86400)
        let assignment = makeAssignment(dueDate: pastDue, isSubmitted: true)
        XCTAssertFalse(assignment.isOverdue)
    }

    func test_assignment_isOverdue_whenFutureDueDate_returnsFalse() {
        let futureDue = Date().addingTimeInterval(86400) // tomorrow
        let assignment = makeAssignment(dueDate: futureDue, isSubmitted: false)
        XCTAssertFalse(assignment.isOverdue)
    }

    // MARK: daysLate

    func test_assignment_daysLate_whenNotOverdue_returnsZero() {
        let futureDue = Date().addingTimeInterval(86400)
        let assignment = makeAssignment(dueDate: futureDue)
        XCTAssertEqual(assignment.daysLate, 0)
    }

    func test_assignment_daysLate_whenThreeDaysOverdue_returnsThree() {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 86400)
        let assignment = makeAssignment(dueDate: threeDaysAgo)
        // Due to Calendar.dateComponents rounding, allow within 1 day tolerance
        XCTAssertTrue(assignment.daysLate >= 2 && assignment.daysLate <= 3,
                       "Expected daysLate around 3, got \(assignment.daysLate)")
    }

    // MARK: latePenaltyPercent

    func test_assignment_latePenaltyPercent_noPenaltyType_returnsZero() {
        let overdue = Date().addingTimeInterval(-2 * 86400)
        let assignment = makeAssignment(dueDate: overdue, latePenaltyType: .none)
        XCTAssertEqual(assignment.latePenaltyPercent, 0)
    }

    func test_assignment_latePenaltyPercent_percentPerDay_calculatesCorrectly() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)
        let assignment = makeAssignment(
            dueDate: twoDaysAgo,
            latePenaltyType: .percentPerDay,
            latePenaltyPerDay: 10.0
        )
        // 2 days * 10% = 20%, could be 10% if calendar rounds to 1 day
        let penalty = assignment.latePenaltyPercent
        XCTAssertTrue(penalty >= 10 && penalty <= 20,
                       "Expected penalty around 20%, got \(penalty)%")
    }

    func test_assignment_latePenaltyPercent_percentPerDay_capsAt100() {
        let twentyDaysAgo = Date().addingTimeInterval(-20 * 86400)
        let assignment = makeAssignment(
            dueDate: twentyDaysAgo,
            latePenaltyType: .percentPerDay,
            latePenaltyPerDay: 10.0
        )
        XCTAssertEqual(assignment.latePenaltyPercent, 100)
    }

    func test_assignment_latePenaltyPercent_flatDeduction_calculatesCorrectly() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)
        let assignment = makeAssignment(
            dueDate: twoDaysAgo,
            points: 100,
            latePenaltyType: .flatDeduction,
            latePenaltyPerDay: 5.0  // 5 points per day
        )
        // 2 days * 5 pts = 10 pts out of 100 = 10%
        let penalty = assignment.latePenaltyPercent
        XCTAssertTrue(penalty >= 5 && penalty <= 10,
                       "Expected penalty around 10%, got \(penalty)%")
    }

    func test_assignment_latePenaltyPercent_noCredit_returns100() {
        let overdue = Date().addingTimeInterval(-1 * 86400)
        let assignment = makeAssignment(
            dueDate: overdue,
            latePenaltyType: .noCredit
        )
        XCTAssertEqual(assignment.latePenaltyPercent, 100)
    }

    // MARK: canSubmitLate

    func test_assignment_canSubmitLate_withinMaxDays_returnsTrue() {
        let oneDayAgo = Date().addingTimeInterval(-1 * 86400)
        let assignment = makeAssignment(
            dueDate: oneDayAgo,
            latePenaltyType: .percentPerDay,
            latePenaltyPerDay: 10,
            maxLateDays: 7
        )
        XCTAssertTrue(assignment.canSubmitLate)
    }

    func test_assignment_canSubmitLate_beyondMaxDays_returnsFalse() {
        let twentyDaysAgo = Date().addingTimeInterval(-20 * 86400)
        let assignment = makeAssignment(
            dueDate: twentyDaysAgo,
            latePenaltyType: .percentPerDay,
            latePenaltyPerDay: 10,
            maxLateDays: 7
        )
        XCTAssertFalse(assignment.canSubmitLate)
    }

    // MARK: canResubmit

    func test_assignment_canResubmit_whenAllowed_andSubmittedAndGraded_returnsTrue() {
        let assignment = makeAssignment(
            isSubmitted: true,
            grade: 80.0,
            allowResubmission: true,
            maxResubmissions: 2,
            resubmissionCount: 0
        )
        XCTAssertTrue(assignment.canResubmit)
    }

    func test_assignment_canResubmit_whenNotAllowed_returnsFalse() {
        let assignment = makeAssignment(
            isSubmitted: true,
            grade: 80.0,
            allowResubmission: false
        )
        XCTAssertFalse(assignment.canResubmit)
    }

    func test_assignment_canResubmit_whenNotSubmitted_returnsFalse() {
        let assignment = makeAssignment(
            isSubmitted: false,
            allowResubmission: true
        )
        XCTAssertFalse(assignment.canResubmit)
    }

    func test_assignment_canResubmit_whenNotGraded_returnsFalse() {
        let assignment = makeAssignment(
            isSubmitted: true,
            grade: nil,
            allowResubmission: true
        )
        XCTAssertFalse(assignment.canResubmit)
    }

    func test_assignment_canResubmit_whenMaxResubmissionsReached_returnsFalse() {
        let assignment = makeAssignment(
            isSubmitted: true,
            grade: 80.0,
            allowResubmission: true,
            maxResubmissions: 2,
            resubmissionCount: 2
        )
        XCTAssertFalse(assignment.canResubmit)
    }

    func test_assignment_canResubmit_whenPastDeadline_returnsFalse() {
        let pastDeadline = Date().addingTimeInterval(-86400)
        let assignment = makeAssignment(
            isSubmitted: true,
            grade: 80.0,
            allowResubmission: true,
            maxResubmissions: 3,
            resubmissionCount: 0,
            resubmissionDeadline: pastDeadline
        )
        XCTAssertFalse(assignment.canResubmit)
    }

    // MARK: remainingResubmissions

    func test_assignment_remainingResubmissions_calculatesCorrectly() {
        let assignment = makeAssignment(
            allowResubmission: true,
            maxResubmissions: 3,
            resubmissionCount: 1
        )
        XCTAssertEqual(assignment.remainingResubmissions, 2)
    }

    func test_assignment_remainingResubmissions_neverGoesNegative() {
        let assignment = makeAssignment(
            allowResubmission: true,
            maxResubmissions: 1,
            resubmissionCount: 5
        )
        XCTAssertEqual(assignment.remainingResubmissions, 0)
    }

    // MARK: statusText

    func test_assignment_statusText_whenSubmittedAndGraded_showsGrade() {
        let assignment = makeAssignment(isSubmitted: true, grade: 85.0)
        XCTAssertTrue(assignment.statusText.contains("Graded"))
        XCTAssertTrue(assignment.statusText.contains("85%"))
    }

    func test_assignment_statusText_whenSubmittedNotGraded_showsSubmitted() {
        let assignment = makeAssignment(isSubmitted: true, grade: nil)
        XCTAssertEqual(assignment.statusText, "Submitted")
    }

    func test_assignment_statusText_whenOverdue_showsOverdue() {
        let pastDue = Date().addingTimeInterval(-86400)
        let assignment = makeAssignment(dueDate: pastDue, isSubmitted: false)
        XCTAssertTrue(assignment.statusText.contains("Overdue") || assignment.statusText.contains("late"),
                       "Expected statusText to mention 'Overdue' or 'late', got: \(assignment.statusText)")
    }

    func test_assignment_statusText_whenPending_showsPending() {
        let futureDue = Date().addingTimeInterval(86400)
        let assignment = makeAssignment(dueDate: futureDue, isSubmitted: false)
        XCTAssertEqual(assignment.statusText, "Pending")
    }

    // MARK: extractAttachmentURLs

    func test_assignment_extractAttachmentURLs_extractsURLs() {
        let text = """
        My submission text here.

        [Attachments]
        https://example.com/file1.pdf
        https://example.com/file2.png
        """
        let urls = Assignment.extractAttachmentURLs(from: text)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0], "https://example.com/file1.pdf")
        XCTAssertEqual(urls[1], "https://example.com/file2.png")
    }

    func test_assignment_extractAttachmentURLs_returnsEmptyWhenNoAttachments() {
        let text = "Just a regular submission without attachments."
        let urls = Assignment.extractAttachmentURLs(from: text)
        XCTAssertTrue(urls.isEmpty)
    }

    func test_assignment_extractAttachmentURLs_returnsEmptyForNil() {
        let urls = Assignment.extractAttachmentURLs(from: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func test_assignment_extractAttachmentURLs_ignoresNonURLLines() {
        let text = """
        Submission.

        [Attachments]
        https://example.com/valid.pdf
        not a url
        some random text
        https://example.com/also-valid.docx
        """
        let urls = Assignment.extractAttachmentURLs(from: text)
        XCTAssertEqual(urls.count, 2)
    }

    // MARK: cleanSubmissionText

    func test_assignment_cleanSubmissionText_removesAttachmentSection() {
        let text = """
        My actual submission text.

        [Attachments]
        https://example.com/file.pdf
        """
        let cleaned = Assignment.cleanSubmissionText(text)
        XCTAssertEqual(cleaned, "My actual submission text.")
    }

    func test_assignment_cleanSubmissionText_returnsNilForNilInput() {
        XCTAssertNil(Assignment.cleanSubmissionText(nil))
    }

    func test_assignment_cleanSubmissionText_returnsOriginalWhenNoAttachments() {
        let text = "Plain submission without attachments."
        XCTAssertEqual(Assignment.cleanSubmissionText(text), text)
    }
}

// MARK: - Course Model Tests

final class CourseTests: XCTestCase {

    // MARK: Helpers

    private func makeLesson(isCompleted: Bool = false) -> Lesson {
        Lesson(
            id: UUID(),
            title: "Lesson",
            content: "Content",
            duration: 30,
            isCompleted: isCompleted,
            type: .reading,
            xpReward: 10
        )
    }

    private func makeModule(lessonCount: Int, completedCount: Int = 0) -> Module {
        var lessons = [Lesson]()
        for i in 0..<lessonCount {
            lessons.append(makeLesson(isCompleted: i < completedCount))
        }
        return Module(id: UUID(), title: "Module", lessons: lessons, orderIndex: 0)
    }

    private func makeCourse(
        modules: [Module] = [],
        enrolledStudentCount: Int = 10,
        maxCapacity: Int = 30,
        progress: Double = 0.0
    ) -> Course {
        Course(
            id: UUID(),
            title: "Test Course",
            description: "A test course",
            teacherName: "Teacher",
            iconSystemName: "book.fill",
            colorName: "blue",
            modules: modules,
            enrolledStudentCount: enrolledStudentCount,
            progress: progress,
            classCode: "ABC123",
            maxCapacity: maxCapacity
        )
    }

    // MARK: totalLessons

    func test_course_totalLessons_countsAcrossModules() {
        let module1 = makeModule(lessonCount: 3)
        let module2 = makeModule(lessonCount: 5)
        let course = makeCourse(modules: [module1, module2])
        XCTAssertEqual(course.totalLessons, 8)
    }

    func test_course_totalLessons_returnsZeroForEmptyModules() {
        let course = makeCourse(modules: [])
        XCTAssertEqual(course.totalLessons, 0)
    }

    // MARK: completedLessons

    func test_course_completedLessons_onlyCountsCompleted() {
        let module1 = makeModule(lessonCount: 4, completedCount: 2)
        let module2 = makeModule(lessonCount: 3, completedCount: 1)
        let course = makeCourse(modules: [module1, module2])
        XCTAssertEqual(course.completedLessons, 3)
    }

    func test_course_completedLessons_returnsZeroWhenNoneCompleted() {
        let module = makeModule(lessonCount: 5, completedCount: 0)
        let course = makeCourse(modules: [module])
        XCTAssertEqual(course.completedLessons, 0)
    }

    // MARK: isFull

    func test_course_isFull_whenAtCapacity_returnsTrue() {
        let course = makeCourse(enrolledStudentCount: 30, maxCapacity: 30)
        XCTAssertTrue(course.isFull)
    }

    func test_course_isFull_whenOverCapacity_returnsTrue() {
        let course = makeCourse(enrolledStudentCount: 35, maxCapacity: 30)
        XCTAssertTrue(course.isFull)
    }

    func test_course_isFull_whenBelowCapacity_returnsFalse() {
        let course = makeCourse(enrolledStudentCount: 20, maxCapacity: 30)
        XCTAssertFalse(course.isFull)
    }

    // MARK: spotsRemaining

    func test_course_spotsRemaining_calculatesCorrectly() {
        let course = makeCourse(enrolledStudentCount: 22, maxCapacity: 30)
        XCTAssertEqual(course.spotsRemaining, 8)
    }

    func test_course_spotsRemaining_neverGoesNegative() {
        let course = makeCourse(enrolledStudentCount: 35, maxCapacity: 30)
        XCTAssertEqual(course.spotsRemaining, 0)
    }

    // MARK: progress

    func test_course_progress_storesValue() {
        let course = makeCourse(progress: 0.75)
        XCTAssertEqual(course.progress, 0.75, accuracy: 0.001)
    }

    // MARK: maxCapacity default

    func test_course_maxCapacity_defaultsTo30() {
        let course = Course(
            id: UUID(),
            title: "Default Cap",
            description: "Test",
            teacherName: "Teacher",
            iconSystemName: "book.fill",
            colorName: "blue",
            modules: [],
            enrolledStudentCount: 0,
            progress: 0,
            classCode: "XYZ"
        )
        XCTAssertEqual(course.maxCapacity, 30)
    }
}

// MARK: - QuizQuestion Tests

final class QuizQuestionTests: XCTestCase {

    func test_quizQuestion_backwardsCompatibleInit_defaultsToMultipleChoice() {
        let question = QuizQuestion(
            id: UUID(),
            text: "What is 2+2?",
            options: ["3", "4", "5", "6"],
            correctIndex: 1
        )
        XCTAssertEqual(question.questionType, .multipleChoice)
        XCTAssertEqual(question.options.count, 4)
        XCTAssertEqual(question.correctIndex, 1)
        XCTAssertTrue(question.acceptedAnswers.isEmpty)
        XCTAssertTrue(question.matchingPairs.isEmpty)
        XCTAssertEqual(question.essayPrompt, "")
        XCTAssertEqual(question.essayMinWords, 0)
        XCTAssertFalse(question.needsManualReview)
    }

    func test_quizQuestion_fullInit_setsAllProperties() {
        let pairs = [MatchingPair(prompt: "A", answer: "1"), MatchingPair(prompt: "B", answer: "2")]
        let question = QuizQuestion(
            id: UUID(),
            text: "Match the following:",
            questionType: .matching,
            matchingPairs: pairs,
            essayPrompt: "Explain your reasoning",
            essayMinWords: 100,
            needsManualReview: true,
            explanation: "Because reasons"
        )
        XCTAssertEqual(question.questionType, .matching)
        XCTAssertEqual(question.matchingPairs.count, 2)
        XCTAssertEqual(question.essayPrompt, "Explain your reasoning")
        XCTAssertEqual(question.essayMinWords, 100)
        XCTAssertTrue(question.needsManualReview)
        XCTAssertEqual(question.explanation, "Because reasons")
    }

    func test_quizQuestion_fillInBlank_usesAcceptedAnswers() {
        let question = QuizQuestion(
            id: UUID(),
            text: "The capital of France is ___.",
            questionType: .fillInBlank,
            acceptedAnswers: ["Paris", "paris"]
        )
        XCTAssertEqual(question.questionType, .fillInBlank)
        XCTAssertEqual(question.acceptedAnswers, ["Paris", "paris"])
    }
}

// MARK: - QuizQuestionType Tests

final class QuizQuestionTypeTests: XCTestCase {

    func test_quizQuestionType_displayName_multipleChoice() {
        XCTAssertEqual(QuizQuestionType.multipleChoice.displayName, "Multiple Choice")
    }

    func test_quizQuestionType_displayName_trueFalse() {
        XCTAssertEqual(QuizQuestionType.trueFalse.displayName, "True / False")
    }

    func test_quizQuestionType_displayName_fillInBlank() {
        XCTAssertEqual(QuizQuestionType.fillInBlank.displayName, "Fill in the Blank")
    }

    func test_quizQuestionType_displayName_matching() {
        XCTAssertEqual(QuizQuestionType.matching.displayName, "Matching")
    }

    func test_quizQuestionType_displayName_essay() {
        XCTAssertEqual(QuizQuestionType.essay.displayName, "Essay")
    }

    func test_quizQuestionType_isAutoGradable_multipleChoice_true() {
        XCTAssertTrue(QuizQuestionType.multipleChoice.isAutoGradable)
    }

    func test_quizQuestionType_isAutoGradable_trueFalse_true() {
        XCTAssertTrue(QuizQuestionType.trueFalse.isAutoGradable)
    }

    func test_quizQuestionType_isAutoGradable_fillInBlank_true() {
        XCTAssertTrue(QuizQuestionType.fillInBlank.isAutoGradable)
    }

    func test_quizQuestionType_isAutoGradable_matching_false() {
        XCTAssertFalse(QuizQuestionType.matching.isAutoGradable)
    }

    func test_quizQuestionType_isAutoGradable_essay_false() {
        XCTAssertFalse(QuizQuestionType.essay.isAutoGradable)
    }
}

// MARK: - DayOfWeek Tests

final class DayOfWeekTests: XCTestCase {

    func test_dayOfWeek_fromCalendarWeekday_sunday_returnsNil() {
        XCTAssertNil(DayOfWeek.from(calendarWeekday: 1))
    }

    func test_dayOfWeek_fromCalendarWeekday_monday_returnsMonday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 2), .monday)
    }

    func test_dayOfWeek_fromCalendarWeekday_tuesday_returnsTuesday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 3), .tuesday)
    }

    func test_dayOfWeek_fromCalendarWeekday_wednesday_returnsWednesday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 4), .wednesday)
    }

    func test_dayOfWeek_fromCalendarWeekday_thursday_returnsThursday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 5), .thursday)
    }

    func test_dayOfWeek_fromCalendarWeekday_friday_returnsFriday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 6), .friday)
    }

    func test_dayOfWeek_fromCalendarWeekday_saturday_returnsNil() {
        XCTAssertNil(DayOfWeek.from(calendarWeekday: 7))
    }

    func test_dayOfWeek_shortName() {
        XCTAssertEqual(DayOfWeek.monday.shortName, "Mon")
        XCTAssertEqual(DayOfWeek.tuesday.shortName, "Tue")
        XCTAssertEqual(DayOfWeek.wednesday.shortName, "Wed")
        XCTAssertEqual(DayOfWeek.thursday.shortName, "Thu")
        XCTAssertEqual(DayOfWeek.friday.shortName, "Fri")
    }

    func test_dayOfWeek_fullName() {
        XCTAssertEqual(DayOfWeek.monday.fullName, "Monday")
        XCTAssertEqual(DayOfWeek.tuesday.fullName, "Tuesday")
        XCTAssertEqual(DayOfWeek.wednesday.fullName, "Wednesday")
        XCTAssertEqual(DayOfWeek.thursday.fullName, "Thursday")
        XCTAssertEqual(DayOfWeek.friday.fullName, "Friday")
    }

    func test_dayOfWeek_comparable_mondayLessThanFriday() {
        XCTAssertTrue(DayOfWeek.monday < DayOfWeek.friday)
    }

    func test_dayOfWeek_comparable_fridayNotLessThanMonday() {
        XCTAssertFalse(DayOfWeek.friday < DayOfWeek.monday)
    }

    func test_dayOfWeek_comparable_sameDayNotLessThan() {
        XCTAssertFalse(DayOfWeek.wednesday < DayOfWeek.wednesday)
    }
}

// MARK: - CourseSchedule Tests

final class CourseScheduleTests: XCTestCase {

    private func makeSchedule(
        startMinute: Int = 480,
        endMinute: Int = 530
    ) -> CourseSchedule {
        CourseSchedule(
            id: UUID(),
            courseId: UUID(),
            dayOfWeek: .monday,
            startMinute: startMinute,
            endMinute: endMinute,
            roomNumber: "101"
        )
    }

    func test_courseSchedule_startTimeString_formatsAM() {
        let schedule = makeSchedule(startMinute: 480) // 8:00 AM
        XCTAssertEqual(schedule.startTimeString, "8 AM")
    }

    func test_courseSchedule_startTimeString_formatsWithMinutes() {
        let schedule = makeSchedule(startMinute: 495) // 8:15 AM
        XCTAssertEqual(schedule.startTimeString, "8:15 AM")
    }

    func test_courseSchedule_endTimeString_formatsPM() {
        let schedule = makeSchedule(endMinute: 780) // 1:00 PM
        XCTAssertEqual(schedule.endTimeString, "1 PM")
    }

    func test_courseSchedule_endTimeString_formats12PM() {
        let schedule = makeSchedule(endMinute: 720) // 12:00 PM (noon)
        XCTAssertEqual(schedule.endTimeString, "12 PM")
    }

    func test_courseSchedule_endTimeString_formatsMidnight() {
        let schedule = makeSchedule(endMinute: 0) // 12:00 AM (midnight)
        XCTAssertEqual(schedule.endTimeString, "12 AM")
    }

    func test_courseSchedule_durationMinutes_calculatesCorrectly() {
        let schedule = makeSchedule(startMinute: 480, endMinute: 530)
        XCTAssertEqual(schedule.durationMinutes, 50)
    }

    func test_courseSchedule_timeRangeString_formatsCorrectly() {
        let schedule = makeSchedule(startMinute: 480, endMinute: 530)
        // 8 AM - 8:50 AM
        XCTAssertEqual(schedule.timeRangeString, "8 AM - 8:50 AM")
    }

    func test_courseSchedule_timeRangeString_afternoonClass() {
        let schedule = makeSchedule(startMinute: 810, endMinute: 870) // 1:30 PM - 2:30 PM
        XCTAssertEqual(schedule.timeRangeString, "1:30 PM - 2:30 PM")
    }
}

// MARK: - LatePenaltyType Tests

final class LatePenaltyTypeTests: XCTestCase {

    func test_latePenaltyType_displayName_none() {
        XCTAssertEqual(LatePenaltyType.none.displayName, "No Penalty")
    }

    func test_latePenaltyType_displayName_percentPerDay() {
        XCTAssertEqual(LatePenaltyType.percentPerDay.displayName, "% Per Day Late")
    }

    func test_latePenaltyType_displayName_flatDeduction() {
        XCTAssertEqual(LatePenaltyType.flatDeduction.displayName, "Flat Point Deduction")
    }

    func test_latePenaltyType_displayName_noCredit() {
        XCTAssertEqual(LatePenaltyType.noCredit.displayName, "No Credit If Late")
    }
}
