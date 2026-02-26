//
//  ModelTests.swift
//  WolfWhaleLMSTests
//
//  Created by Rork on February 26, 2026.
//

import XCTest
@testable import WolfWhaleLMS

// MARK: - User Model Tests

final class UserModelTests: XCTestCase {

    // MARK: Helpers

    private func makeUser(
        firstName: String = "John",
        lastName: String = "Doe",
        email: String = "john@example.com",
        role: UserRole = .student
    ) -> User {
        User(
            id: UUID(),
            firstName: firstName,
            lastName: lastName,
            email: email,
            role: role,
            streak: 5,
            joinDate: Date()
        )
    }

    // MARK: fullName

    func test_user_fullName_combinesFirstAndLastName() {
        let user = makeUser(firstName: "Jane", lastName: "Smith")
        XCTAssertEqual(user.fullName, "Jane Smith")
    }

    func test_user_fullName_withSingleCharNames() {
        let user = makeUser(firstName: "J", lastName: "D")
        XCTAssertEqual(user.fullName, "J D")
    }

    // MARK: Codable round-trip

    func test_user_codable_roundTrip() throws {
        let original = makeUser()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(User.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.firstName, original.firstName)
        XCTAssertEqual(decoded.lastName, original.lastName)
        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.streak, original.streak)
    }

    // MARK: Default values

    func test_user_defaultValues() {
        let user = User(id: UUID(), firstName: "Test", lastName: "User")
        XCTAssertEqual(user.email, "")
        XCTAssertEqual(user.role, .student)
        XCTAssertEqual(user.streak, 0)
        XCTAssertEqual(user.avatarSystemName, "person.crop.circle.fill")
        XCTAssertNil(user.schoolId)
        XCTAssertEqual(user.userSlotsTotal, 0)
        XCTAssertEqual(user.userSlotsUsed, 0)
    }
}

// MARK: - UserRole Tests

final class UserRoleTests: XCTestCase {

    func test_userRole_rawValues() {
        XCTAssertEqual(UserRole.student.rawValue, "Student")
        XCTAssertEqual(UserRole.teacher.rawValue, "Teacher")
        XCTAssertEqual(UserRole.parent.rawValue, "Parent")
        XCTAssertEqual(UserRole.admin.rawValue, "Admin")
        XCTAssertEqual(UserRole.superAdmin.rawValue, "SuperAdmin")
    }

    func test_userRole_id_matchesRawValue() {
        for role in UserRole.allCases {
            XCTAssertEqual(role.id, role.rawValue)
        }
    }

    func test_userRole_from_validString() {
        XCTAssertEqual(UserRole.from("Student"), .student)
        XCTAssertEqual(UserRole.from("student"), .student)
        XCTAssertEqual(UserRole.from("Teacher"), .teacher)
        XCTAssertEqual(UserRole.from("Admin"), .admin)
    }

    func test_userRole_from_invalidString_returnsNil() {
        XCTAssertNil(UserRole.from(""))
        XCTAssertNil(UserRole.from("InvalidRole"))
        XCTAssertNil(UserRole.from("moderator"))
    }

    func test_userRole_iconName_isNotEmpty() {
        for role in UserRole.allCases {
            XCTAssertFalse(role.iconName.isEmpty, "\(role.rawValue) has empty iconName")
        }
    }

    func test_userRole_allCases_hasFiveRoles() {
        XCTAssertEqual(UserRole.allCases.count, 5)
    }
}

// MARK: - GradeEntry Codable Tests

final class GradeEntryTests: XCTestCase {

    func test_gradeEntry_codable_roundTrip() throws {
        let original = GradeEntry(
            id: UUID(),
            courseId: UUID(),
            courseName: "Math",
            courseIcon: "book.fill",
            courseColor: "blue",
            letterGrade: "A",
            numericGrade: 95.0,
            assignmentGrades: [
                AssignmentGrade(
                    id: UUID(),
                    title: "HW 1",
                    score: 90,
                    maxScore: 100,
                    date: Date(),
                    type: "homework"
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GradeEntry.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.courseId, original.courseId)
        XCTAssertEqual(decoded.courseName, "Math")
        XCTAssertEqual(decoded.letterGrade, "A")
        XCTAssertEqual(decoded.numericGrade, 95.0, accuracy: 0.001)
        XCTAssertEqual(decoded.assignmentGrades.count, 1)
        XCTAssertEqual(decoded.assignmentGrades.first?.title, "HW 1")
    }

    func test_assignmentGrade_codable_roundTrip() throws {
        let original = AssignmentGrade(
            id: UUID(),
            title: "Quiz 1",
            score: 88.5,
            maxScore: 100,
            date: Date(),
            type: "quiz"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AssignmentGrade.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Quiz 1")
        XCTAssertEqual(decoded.score, 88.5, accuracy: 0.001)
        XCTAssertEqual(decoded.maxScore, 100.0, accuracy: 0.001)
        XCTAssertEqual(decoded.type, "quiz")
    }
}

// MARK: - SyncResult Tests

final class SyncResultTests: XCTestCase {

    func test_syncResult_isSuccess_whenNoErrors() {
        let result = SyncResult(itemsSynced: 10, errors: [])
        XCTAssertTrue(result.isSuccess)
    }

    func test_syncResult_isNotSuccess_whenHasErrors() {
        let result = SyncResult(itemsSynced: 5, errors: ["Network timeout"])
        XCTAssertFalse(result.isSuccess)
    }

    func test_syncResult_codable_roundTrip() throws {
        let original = SyncResult(
            itemsSynced: 42,
            conflictsFound: 3,
            conflictsResolved: 2,
            errors: ["One error"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SyncResult.self, from: data)

        XCTAssertEqual(decoded.itemsSynced, 42)
        XCTAssertEqual(decoded.conflictsFound, 3)
        XCTAssertEqual(decoded.conflictsResolved, 2)
        XCTAssertEqual(decoded.errors.count, 1)
        XCTAssertFalse(decoded.isSuccess)
    }

    func test_syncResult_defaultValues() {
        let result = SyncResult(itemsSynced: 5)
        XCTAssertEqual(result.conflictsFound, 0)
        XCTAssertEqual(result.conflictsResolved, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.isSuccess)
    }
}

// MARK: - ConflictResolution Tests

final class ConflictResolutionTests: XCTestCase {

    func test_conflictResolution_rawValues() {
        XCTAssertEqual(ConflictResolution.serverWins.rawValue, "serverWins")
        XCTAssertEqual(ConflictResolution.localWins.rawValue, "localWins")
        XCTAssertEqual(ConflictResolution.noConflict.rawValue, "noConflict")
    }

    func test_syncConflict_codable_roundTrip() throws {
        let original = SyncConflict(
            entityType: "course",
            entityId: UUID().uuidString,
            entityName: "Algebra",
            localModifiedAt: Date().addingTimeInterval(-3600),
            serverModifiedAt: Date(),
            resolution: .serverWins
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SyncConflict.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.entityType, "course")
        XCTAssertEqual(decoded.entityName, "Algebra")
        XCTAssertEqual(decoded.resolution, .serverWins)
    }
}

// MARK: - CachedItemMetadata Tests

final class CachedItemMetadataTests: XCTestCase {

    func test_cachedItemMetadata_defaultValues() {
        let metadata = CachedItemMetadata(
            id: UUID(),
            entityType: "assignment",
            entityName: "HW 1",
            modifiedAt: Date()
        )
        XCTAssertFalse(metadata.isLocallyModified)
    }

    func test_cachedItemMetadata_codable_roundTrip() throws {
        let original = CachedItemMetadata(
            id: UUID(),
            entityType: "grade",
            entityName: "Math Grade",
            modifiedAt: Date(),
            isLocallyModified: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CachedItemMetadata.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.entityType, "grade")
        XCTAssertEqual(decoded.entityName, "Math Grade")
        XCTAssertTrue(decoded.isLocallyModified)
    }
}

// MARK: - ProgressGoal Tests

final class ProgressGoalTests: XCTestCase {

    // MARK: letterGrade(for:)

    func test_letterGrade_A_at93() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 93.0), "A")
    }

    func test_letterGrade_A_at100() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 100.0), "A")
    }

    func test_letterGrade_A_minus_at90() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 90.0), "A-")
    }

    func test_letterGrade_B_plus_at87() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 87.0), "B+")
    }

    func test_letterGrade_B_at83() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 83.0), "B")
    }

    func test_letterGrade_B_minus_at80() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 80.0), "B-")
    }

    func test_letterGrade_C_plus_at77() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 77.0), "C+")
    }

    func test_letterGrade_C_at73() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 73.0), "C")
    }

    func test_letterGrade_C_minus_at70() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 70.0), "C-")
    }

    func test_letterGrade_D_plus_at67() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 67.0), "D+")
    }

    func test_letterGrade_D_at60() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 60.0), "D")
    }

    func test_letterGrade_F_at59() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 59.0), "F")
    }

    func test_letterGrade_F_atZero() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: 0.0), "F")
    }

    func test_letterGrade_F_atNegative() {
        XCTAssertEqual(ProgressGoal.letterGrade(for: -5.0), "F")
    }

    // MARK: gradePercentage(for:)

    func test_gradePercentage_A_returns95() {
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "A"), 95)
    }

    func test_gradePercentage_A_minus_returns91() {
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "A-"), 91)
    }

    func test_gradePercentage_B_plus_returns88() {
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "B+"), 88)
    }

    func test_gradePercentage_B_returns85() {
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "B"), 85)
    }

    func test_gradePercentage_unknown_returns55() {
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "F"), 55)
        XCTAssertEqual(ProgressGoal.gradePercentage(for: "X"), 55)
    }

    // MARK: allLetterGrades

    func test_allLetterGrades_hasTenEntries() {
        XCTAssertEqual(ProgressGoal.allLetterGrades.count, 10)
    }

    func test_allLetterGrades_startsWithA_endsWithD() {
        XCTAssertEqual(ProgressGoal.allLetterGrades.first, "A")
        XCTAssertEqual(ProgressGoal.allLetterGrades.last, "D")
    }

    // MARK: Init auto-derives letterGrade

    func test_init_autoDerives_letterGrade_whenEmpty() {
        let goal = ProgressGoal(courseId: UUID(), targetGrade: 95.0)
        XCTAssertEqual(goal.targetLetterGrade, "A")
    }

    func test_init_preserves_explicitLetterGrade() {
        let goal = ProgressGoal(courseId: UUID(), targetGrade: 95.0, targetLetterGrade: "Custom")
        XCTAssertEqual(goal.targetLetterGrade, "Custom")
    }

    // MARK: Codable round-trip

    func test_progressGoal_codable_roundTrip() throws {
        let original = ProgressGoal(courseId: UUID(), targetGrade: 88.0)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProgressGoal.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.targetGrade, 88.0, accuracy: 0.001)
        XCTAssertEqual(decoded.targetLetterGrade, "B+")
    }
}

// MARK: - XPLevelSystem Tests

final class XPLevelSystemTests: XCTestCase {

    // MARK: xpRequired(forLevel:)

    func test_xpRequired_level1_isZero() {
        XCTAssertEqual(XPLevelSystem.xpRequired(forLevel: 1), 0)
    }

    func test_xpRequired_level2_is101() {
        XCTAssertEqual(XPLevelSystem.xpRequired(forLevel: 2), 101)
    }

    func test_xpRequired_level3_is301() {
        // 1*100 + 2*100 + 1 = 301
        XCTAssertEqual(XPLevelSystem.xpRequired(forLevel: 3), 301)
    }

    func test_xpRequired_level4_is601() {
        // 1*100 + 2*100 + 3*100 + 1 = 601
        XCTAssertEqual(XPLevelSystem.xpRequired(forLevel: 4), 601)
    }

    func test_xpRequired_levelZeroOrNegative_isZero() {
        XCTAssertEqual(XPLevelSystem.xpRequired(forLevel: 0), 0)
    }

    // MARK: level(forXP:)

    func test_level_forZeroXP_isLevel1() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 0), 1)
    }

    func test_level_for100XP_isLevel1() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 100), 1)
    }

    func test_level_for101XP_isLevel2() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 101), 2)
    }

    func test_level_for300XP_isLevel2() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 300), 2)
    }

    func test_level_for301XP_isLevel3() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 301), 3)
    }

    func test_level_for601XP_isLevel4() {
        XCTAssertEqual(XPLevelSystem.level(forXP: 601), 4)
    }

    // MARK: xpForNextLevel(currentLevel:)

    func test_xpForNextLevel_level1_is101() {
        XCTAssertEqual(XPLevelSystem.xpForNextLevel(currentLevel: 1), 101)
    }

    func test_xpForNextLevel_level2_is301() {
        XCTAssertEqual(XPLevelSystem.xpForNextLevel(currentLevel: 2), 301)
    }

    // MARK: progressInLevel(xp:)

    func test_progressInLevel_atLevelStart_isZero() {
        // Level 2 starts at 101
        let progress = XPLevelSystem.progressInLevel(xp: 101)
        XCTAssertEqual(progress, 0.0, accuracy: 0.01)
    }

    func test_progressInLevel_midLevel_returnsCorrectFraction() {
        // Level 2: 101-300, range = 200
        // At 201 XP: (201-101)/200 = 0.5
        let progress = XPLevelSystem.progressInLevel(xp: 201)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    func test_progressInLevel_atZero_returnsZero() {
        // Level 1: 0-100, range = 101
        let progress = XPLevelSystem.progressInLevel(xp: 0)
        XCTAssertEqual(progress, 0.0, accuracy: 0.01)
    }

    // MARK: xpToNextLevel(xp:)

    func test_xpToNextLevel_atZero() {
        // At 0 XP, level 1. Next level at 101. Need 101.
        XCTAssertEqual(XPLevelSystem.xpToNextLevel(xp: 0), 101)
    }

    func test_xpToNextLevel_at50() {
        // At 50 XP, level 1. Next level at 101. Need 51.
        XCTAssertEqual(XPLevelSystem.xpToNextLevel(xp: 50), 51)
    }

    func test_xpToNextLevel_at101() {
        // At 101 XP, level 2. Next level at 301. Need 200.
        XCTAssertEqual(XPLevelSystem.xpToNextLevel(xp: 101), 200)
    }

    // MARK: tierName(forLevel:)

    func test_tierName_level1_isBeginner() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 1), "Beginner")
    }

    func test_tierName_level2_isLearner() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 2), "Learner")
    }

    func test_tierName_level3_isLearner() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 3), "Learner")
    }

    func test_tierName_level5_isScholar() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 5), "Scholar")
    }

    func test_tierName_level8_isExpert() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 8), "Expert")
    }

    func test_tierName_level10_isMaster() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 10), "Master")
    }

    func test_tierName_level50_isMaster() {
        XCTAssertEqual(XPLevelSystem.tierName(forLevel: 50), "Master")
    }
}

// MARK: - EnrollmentStatus Tests

final class EnrollmentStatusTests: XCTestCase {

    func test_enrollmentStatus_displayName() {
        XCTAssertEqual(EnrollmentStatus.enrolled.displayName, "Enrolled")
        XCTAssertEqual(EnrollmentStatus.pending.displayName, "Pending Approval")
        XCTAssertEqual(EnrollmentStatus.waitlisted.displayName, "Waitlisted")
        XCTAssertEqual(EnrollmentStatus.dropped.displayName, "Dropped")
        XCTAssertEqual(EnrollmentStatus.denied.displayName, "Denied")
    }

    func test_enrollmentStatus_iconName_isNotEmpty() {
        for status in EnrollmentStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty, "\(status.rawValue) has empty iconName")
        }
    }

    func test_enrollmentStatus_color_isNotEmpty() {
        for status in EnrollmentStatus.allCases {
            XCTAssertFalse(status.color.isEmpty, "\(status.rawValue) has empty color")
        }
    }

    func test_enrollmentStatus_allCases_hasFiveStatuses() {
        XCTAssertEqual(EnrollmentStatus.allCases.count, 5)
    }
}

// MARK: - CourseCatalogEntry Tests

final class CourseCatalogEntryTests: XCTestCase {

    private func makeEntry(
        currentEnrollment: Int = 20,
        maxEnrollment: Int = 30
    ) -> CourseCatalogEntry {
        CourseCatalogEntry(
            id: UUID(),
            name: "Test Course",
            description: "A course",
            teacherName: "Teacher",
            schedule: "MWF",
            subject: "Math",
            gradeLevel: "10",
            currentEnrollment: currentEnrollment,
            maxEnrollment: maxEnrollment,
            enrollmentStatus: nil
        )
    }

    func test_courseCatalogEntry_isFull_whenAtCapacity() {
        let entry = makeEntry(currentEnrollment: 30, maxEnrollment: 30)
        XCTAssertTrue(entry.isFull)
    }

    func test_courseCatalogEntry_isFull_whenOverCapacity() {
        let entry = makeEntry(currentEnrollment: 35, maxEnrollment: 30)
        XCTAssertTrue(entry.isFull)
    }

    func test_courseCatalogEntry_isNotFull_whenBelowCapacity() {
        let entry = makeEntry(currentEnrollment: 20, maxEnrollment: 30)
        XCTAssertFalse(entry.isFull)
    }

    func test_courseCatalogEntry_spotsRemaining() {
        let entry = makeEntry(currentEnrollment: 22, maxEnrollment: 30)
        XCTAssertEqual(entry.spotsRemaining, 8)
    }

    func test_courseCatalogEntry_spotsRemaining_neverNegative() {
        let entry = makeEntry(currentEnrollment: 35, maxEnrollment: 30)
        XCTAssertEqual(entry.spotsRemaining, 0)
    }
}

// MARK: - AttendanceStatus Tests

final class AttendanceStatusTests: XCTestCase {

    func test_attendanceStatus_from_validString() {
        XCTAssertEqual(AttendanceStatus.from("Present"), .present)
        XCTAssertEqual(AttendanceStatus.from("present"), .present)
        XCTAssertEqual(AttendanceStatus.from("Absent"), .absent)
        XCTAssertEqual(AttendanceStatus.from("Tardy"), .tardy)
        XCTAssertEqual(AttendanceStatus.from("Excused"), .excused)
    }

    func test_attendanceStatus_from_invalidString_returnsNil() {
        XCTAssertNil(AttendanceStatus.from(""))
        XCTAssertNil(AttendanceStatus.from("Unknown"))
    }

    func test_attendanceStatus_iconName_isNotEmpty() {
        for status in AttendanceStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty, "\(status.rawValue) has empty iconName")
        }
    }

    func test_attendanceStatus_colorName_isNotEmpty() {
        for status in AttendanceStatus.allCases {
            XCTAssertFalse(status.colorName.isEmpty, "\(status.rawValue) has empty colorName")
        }
    }

    func test_attendanceStatus_hasFourStatuses() {
        XCTAssertEqual(AttendanceStatus.allCases.count, 4)
    }
}

// MARK: - AttendanceReport Tests

final class AttendanceReportTests: XCTestCase {

    private func makeReport(
        present: Int = 80,
        absent: Int = 10,
        tardy: Int = 5,
        excused: Int = 5
    ) -> AttendanceReport {
        AttendanceReport(
            startDate: Date().addingTimeInterval(-30 * 86400),
            endDate: Date(),
            courseName: "Math",
            totalDays: 20,
            totalRecords: present + absent + tardy + excused,
            presentCount: present,
            absentCount: absent,
            tardyCount: tardy,
            excusedCount: excused,
            studentBreakdowns: [],
            dailyRates: []
        )
    }

    func test_attendanceReport_presentPercent() {
        let report = makeReport(present: 80, absent: 10, tardy: 5, excused: 5)
        XCTAssertEqual(report.presentPercent, 80.0, accuracy: 0.1)
    }

    func test_attendanceReport_absentPercent() {
        let report = makeReport(present: 80, absent: 10, tardy: 5, excused: 5)
        XCTAssertEqual(report.absentPercent, 10.0, accuracy: 0.1)
    }

    func test_attendanceReport_tardyPercent() {
        let report = makeReport(present: 80, absent: 10, tardy: 5, excused: 5)
        XCTAssertEqual(report.tardyPercent, 5.0, accuracy: 0.1)
    }

    func test_attendanceReport_excusedPercent() {
        let report = makeReport(present: 80, absent: 10, tardy: 5, excused: 5)
        XCTAssertEqual(report.excusedPercent, 5.0, accuracy: 0.1)
    }

    func test_attendanceReport_overallRate_includesPresentAndTardy() {
        let report = makeReport(present: 80, absent: 10, tardy: 5, excused: 5)
        // Overall rate = (present + tardy) / total = 85/100 = 85%
        XCTAssertEqual(report.overallRate, 85.0, accuracy: 0.1)
    }

    func test_attendanceReport_zeroRecords_returnsZeroPercents() {
        let report = makeReport(present: 0, absent: 0, tardy: 0, excused: 0)
        XCTAssertEqual(report.presentPercent, 0.0)
        XCTAssertEqual(report.absentPercent, 0.0)
        XCTAssertEqual(report.overallRate, 0.0)
    }

    func test_attendanceReport_toCSV_containsHeaders() {
        let report = makeReport()
        let csv = report.toCSV()
        XCTAssertTrue(csv.contains("Attendance Report"))
        XCTAssertTrue(csv.contains("Summary"))
        XCTAssertTrue(csv.contains("Total Days:"))
        XCTAssertTrue(csv.contains("Present:"))
        XCTAssertTrue(csv.contains("Absent:"))
        XCTAssertTrue(csv.contains("Overall Rate:"))
    }

    func test_attendanceReport_toCSV_containsCourseName() {
        let report = makeReport()
        let csv = report.toCSV()
        XCTAssertTrue(csv.contains("Course:,Math"))
    }
}

// MARK: - Badge Tests

final class BadgeTests: XCTestCase {

    func test_badge_earnedBadge_hasProgressOfOne() {
        let badge = Badge(badgeType: .perfectScore, isEarned: true, earnedDate: Date(), progress: 0.5)
        // When isEarned is true, progress is forced to 1.0
        XCTAssertEqual(badge.progress, 1.0, accuracy: 0.001)
    }

    func test_badge_unearnedBadge_preservesProgress() {
        let badge = Badge(badgeType: .quizMaster, isEarned: false, progress: 0.6)
        XCTAssertEqual(badge.progress, 0.6, accuracy: 0.001)
    }

    func test_badge_progress_clampedToZeroOne() {
        let over = Badge(badgeType: .firstSteps, isEarned: false, progress: 1.5)
        XCTAssertEqual(over.progress, 1.0, accuracy: 0.001)

        let under = Badge(badgeType: .firstSteps, isEarned: false, progress: -0.5)
        XCTAssertEqual(under.progress, 0.0, accuracy: 0.001)
    }

    func test_badge_delegatedProperties() {
        let badge = Badge(badgeType: .perfectScore)
        XCTAssertEqual(badge.name, "Perfect Score")
        XCTAssertEqual(badge.icon, "star.circle.fill")
        XCTAssertEqual(badge.description, "Score 100% on a quiz")
        XCTAssertEqual(badge.rarity, .epic)
    }
}

// MARK: - BadgeType Tests

final class BadgeTypeTests: XCTestCase {

    func test_badgeType_allCases_hasTenTypes() {
        XCTAssertEqual(BadgeType.allCases.count, 10)
    }

    func test_badgeType_displayName_matchesRawValue() {
        for badgeType in BadgeType.allCases {
            XCTAssertEqual(badgeType.displayName, badgeType.rawValue)
        }
    }

    func test_badgeType_description_isNotEmpty() {
        for badgeType in BadgeType.allCases {
            XCTAssertFalse(badgeType.description.isEmpty, "\(badgeType.rawValue) has empty description")
        }
    }

    func test_badgeType_iconSystemName_isNotEmpty() {
        for badgeType in BadgeType.allCases {
            XCTAssertFalse(badgeType.iconSystemName.isEmpty, "\(badgeType.rawValue) has empty icon")
        }
    }

    func test_badgeType_rarity_commonTypes() {
        XCTAssertEqual(BadgeType.firstAssignment.rarity, .common)
        XCTAssertEqual(BadgeType.firstSteps.rarity, .common)
    }

    func test_badgeType_rarity_rareTypes() {
        XCTAssertEqual(BadgeType.quizMaster.rarity, .rare)
        XCTAssertEqual(BadgeType.sevenDayStreak.rarity, .rare)
        XCTAssertEqual(BadgeType.tenLessons.rarity, .rare)
        XCTAssertEqual(BadgeType.socialLearner.rarity, .rare)
    }

    func test_badgeType_rarity_epicTypes() {
        XCTAssertEqual(BadgeType.perfectScore.rarity, .epic)
        XCTAssertEqual(BadgeType.earlyBird.rarity, .epic)
        XCTAssertEqual(BadgeType.courseComplete.rarity, .epic)
    }

    func test_badgeType_rarity_legendaryTypes() {
        XCTAssertEqual(BadgeType.thirtyDayStreak.rarity, .legendary)
    }
}

// MARK: - AchievementRarity Tests

final class AchievementRarityTests: XCTestCase {

    func test_achievementRarity_colorName() {
        XCTAssertEqual(AchievementRarity.common.colorName, "gray")
        XCTAssertEqual(AchievementRarity.rare.colorName, "blue")
        XCTAssertEqual(AchievementRarity.epic.colorName, "purple")
        XCTAssertEqual(AchievementRarity.legendary.colorName, "orange")
    }

    func test_achievementRarity_rawValues() {
        XCTAssertEqual(AchievementRarity.common.rawValue, "Common")
        XCTAssertEqual(AchievementRarity.rare.rawValue, "Rare")
        XCTAssertEqual(AchievementRarity.epic.rawValue, "Epic")
        XCTAssertEqual(AchievementRarity.legendary.rawValue, "Legendary")
    }
}

// MARK: - Conversation Model Tests

final class ConversationModelTests: XCTestCase {

    func test_conversation_codable_roundTrip() throws {
        let msg = ChatMessage(
            id: UUID(),
            senderName: "Alice",
            content: "Hello!",
            timestamp: Date(),
            isFromCurrentUser: true,
            status: .sent
        )
        let original = Conversation(
            id: UUID(),
            participantNames: ["Alice", "Bob"],
            title: "Chat",
            lastMessage: "Hello!",
            lastMessageDate: Date(),
            unreadCount: 2,
            messages: [msg],
            avatarSystemName: "person.circle"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Conversation.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.participantNames, ["Alice", "Bob"])
        XCTAssertEqual(decoded.unreadCount, 2)
        XCTAssertEqual(decoded.messages.count, 1)
        XCTAssertEqual(decoded.messages.first?.content, "Hello!")
        XCTAssertEqual(decoded.messages.first?.status, .sent)
    }

    func test_chatMessage_backwardsCompatible_withoutStatus() throws {
        // Simulate old JSON without "status" field
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "senderName": "Bob",
            "content": "Hi there",
            "timestamp": "2026-02-20T10:00:00Z",
            "isFromCurrentUser": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatMessage.self, from: json)

        XCTAssertEqual(decoded.senderName, "Bob")
        XCTAssertEqual(decoded.content, "Hi there")
        XCTAssertFalse(decoded.isFromCurrentUser)
        XCTAssertEqual(decoded.status, .sent) // Default fallback
    }
}

// MARK: - MessageStatus Tests

final class MessageStatusTests: XCTestCase {

    func test_messageStatus_rawValues() {
        XCTAssertEqual(MessageStatus.sending.rawValue, "sending")
        XCTAssertEqual(MessageStatus.sent.rawValue, "sent")
        XCTAssertEqual(MessageStatus.delivered.rawValue, "delivered")
        XCTAssertEqual(MessageStatus.read.rawValue, "read")
        XCTAssertEqual(MessageStatus.failed.rawValue, "failed")
    }
}

// MARK: - Rubric Tests

final class RubricTests: XCTestCase {

    func test_rubric_totalPoints_sumsCriteriaMaxPoints() {
        let rubric = Rubric(
            id: UUID(),
            title: "Essay Rubric",
            courseId: UUID(),
            criteria: [
                RubricCriterion(id: UUID(), name: "Thesis", description: "", maxPoints: 20, levels: []),
                RubricCriterion(id: UUID(), name: "Evidence", description: "", maxPoints: 30, levels: []),
                RubricCriterion(id: UUID(), name: "Grammar", description: "", maxPoints: 10, levels: []),
            ],
            createdAt: Date()
        )
        XCTAssertEqual(rubric.totalPoints, 60)
    }

    func test_rubric_totalPoints_emptyRubric_returnsZero() {
        let rubric = Rubric(id: UUID(), title: "Empty", courseId: UUID(), criteria: [], createdAt: Date())
        XCTAssertEqual(rubric.totalPoints, 0)
    }

    func test_rubric_codable_roundTrip() throws {
        let level = RubricLevel(id: UUID(), label: "Excellent", description: "Perfect work", points: 10)
        let criterion = RubricCriterion(id: UUID(), name: "Quality", description: "Work quality", maxPoints: 10, levels: [level])
        let original = Rubric(id: UUID(), title: "Test Rubric", courseId: UUID(), criteria: [criterion], createdAt: Date())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Rubric.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Test Rubric")
        XCTAssertEqual(decoded.totalPoints, 10)
        XCTAssertEqual(decoded.criteria.count, 1)
        XCTAssertEqual(decoded.criteria.first?.levels.count, 1)
    }
}

// MARK: - Course Codable Tests

final class CourseCodableTests: XCTestCase {

    func test_course_codable_roundTrip() throws {
        let lesson = Lesson(
            id: UUID(), title: "Lesson 1", content: "Content",
            duration: 30, isCompleted: false, type: .reading, xpReward: 10
        )
        let module = Module(id: UUID(), title: "Module 1", lessons: [lesson], orderIndex: 0)
        let original = Course(
            id: UUID(),
            title: "Physics",
            description: "Intro to Physics",
            teacherName: "Dr. Smith",
            iconSystemName: "atom",
            colorName: "purple",
            modules: [module],
            enrolledStudentCount: 25,
            progress: 0.5,
            classCode: "PHY101",
            maxCapacity: 35
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Course.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Physics")
        XCTAssertEqual(decoded.maxCapacity, 35)
        XCTAssertEqual(decoded.modules.count, 1)
        XCTAssertEqual(decoded.modules.first?.lessons.count, 1)
    }

    func test_course_backwardsCompatible_withoutNewFields() throws {
        // Simulate old JSON missing prerequisiteIds, sectionNumber, maxCapacity
        let courseId = UUID()
        let json = """
        {
            "id": "\(courseId.uuidString)",
            "title": "Old Course",
            "description": "Legacy",
            "teacherName": "Teacher",
            "iconSystemName": "book.fill",
            "colorName": "blue",
            "modules": [],
            "enrolledStudentCount": 10,
            "progress": 0.3,
            "classCode": "OLD"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Course.self, from: json)

        XCTAssertEqual(decoded.title, "Old Course")
        XCTAssertEqual(decoded.maxCapacity, 30) // Default
        XCTAssertTrue(decoded.prerequisiteIds.isEmpty) // Default
        XCTAssertNil(decoded.sectionNumber) // Default
        XCTAssertNil(decoded.sectionLabel) // Default
    }
}

// MARK: - LessonType Tests

final class LessonTypeTests: XCTestCase {

    func test_lessonType_rawValues() {
        XCTAssertEqual(LessonType.reading.rawValue, "Reading")
        XCTAssertEqual(LessonType.video.rawValue, "Video")
        XCTAssertEqual(LessonType.activity.rawValue, "Activity")
        XCTAssertEqual(LessonType.quiz.rawValue, "Quiz")
    }

    func test_lessonType_iconName_isNotEmpty() {
        let allTypes: [LessonType] = [.reading, .video, .activity, .quiz]
        for type in allTypes {
            XCTAssertFalse(type.iconName.isEmpty, "\(type.rawValue) has empty iconName")
        }
    }
}

// MARK: - ParentAlertType Tests

final class ParentAlertTypeTests: XCTestCase {

    func test_parentAlertType_rawValues() {
        XCTAssertEqual(ParentAlertType.lowGrade.rawValue, "Low Grade")
        XCTAssertEqual(ParentAlertType.absence.rawValue, "Absence")
        XCTAssertEqual(ParentAlertType.upcomingDueDate.rawValue, "Upcoming Due Date")
    }

    func test_parentAlertType_iconName_isNotEmpty() {
        for type in ParentAlertType.allCases {
            XCTAssertFalse(type.iconName.isEmpty, "\(type.rawValue) has empty iconName")
        }
    }

    func test_parentAlertType_colorName_isNotEmpty() {
        for type in ParentAlertType.allCases {
            XCTAssertFalse(type.colorName.isEmpty, "\(type.rawValue) has empty colorName")
        }
    }
}
