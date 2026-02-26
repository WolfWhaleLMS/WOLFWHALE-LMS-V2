//
//  OfflineStorageServiceTests.swift
//  WolfWhaleLMSTests
//
//  Created by Rork on February 26, 2026.
//

import XCTest
@testable import WolfWhaleLMS

// MARK: - OfflineStorageService Tests

@MainActor
final class OfflineStorageServiceTests: XCTestCase {

    private var service: OfflineStorageService!
    private var testUserId1: UUID!
    private var testUserId2: UUID!

    override func setUp() {
        super.setUp()
        service = OfflineStorageService()
        testUserId1 = UUID()
        testUserId2 = UUID()
    }

    override func tearDown() {
        // Clean up any test data written to disk
        if let uid = testUserId1 {
            service.setCurrentUser(uid)
            service.clearAllData()
            service.clearCache()
        }
        if let uid = testUserId2 {
            service.setCurrentUser(uid)
            service.clearAllData()
            service.clearCache()
        }
        service.clearCurrentUser()
        service = nil
        super.tearDown()
    }

    // MARK: - Factory Helpers

    private func makeCourse(title: String = "Test Course") -> Course {
        Course(
            id: UUID(),
            title: title,
            description: "A test course",
            teacherName: "Teacher",
            iconSystemName: "book.fill",
            colorName: "blue",
            modules: [],
            enrolledStudentCount: 10,
            progress: 0.5,
            classCode: "TEST123"
        )
    }

    private func makeAssignment(title: String = "Test Assignment") -> Assignment {
        Assignment(
            id: UUID(),
            title: title,
            courseId: UUID(),
            courseName: "Test Course",
            instructions: "Do the work",
            dueDate: Date().addingTimeInterval(86400),
            points: 100,
            isSubmitted: false,
            submission: nil,
            grade: nil,
            feedback: nil,
            xpReward: 50
        )
    }

    private func makeGradeEntry() -> GradeEntry {
        GradeEntry(
            id: UUID(),
            courseId: UUID(),
            courseName: "Test Course",
            courseIcon: "book.fill",
            courseColor: "blue",
            letterGrade: "A",
            numericGrade: 95.0,
            assignmentGrades: []
        )
    }

    private func makeUser() -> User {
        User(
            id: UUID(),
            firstName: "Test",
            lastName: "User",
            email: "test@example.com",
            role: .student,
            streak: 5,
            joinDate: Date()
        )
    }

    // MARK: - Current User Scope Tests

    func test_setCurrentUser_enablesDataAccess() {
        service.setCurrentUser(testUserId1)
        // After setting user, hasOfflineData should return false (no data saved yet)
        // but the service should be functional (no guard early return)
        XCTAssertFalse(service.hasOfflineData)
    }

    func test_clearCurrentUser_resetsState() {
        service.setCurrentUser(testUserId1)
        service.clearCurrentUser()
        // After clearing user, cachedDataSize should be 0
        XCTAssertEqual(service.cachedDataSize, 0)
    }

    func test_hasOfflineData_returnsFalse_whenNoUserSet() {
        service.clearCurrentUser()
        XCTAssertFalse(service.hasOfflineData)
    }

    func test_hasOfflineData_returnsFalse_whenNoDataSaved() {
        service.setCurrentUser(testUserId1)
        XCTAssertFalse(service.hasOfflineData)
    }

    // MARK: - Save and Load Round-Trip Tests

    func test_saveCourses_andLoadCourses_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let courses = [makeCourse(title: "Math"), makeCourse(title: "Science")]
        service.saveCourses(courses)

        // Allow the detached save task to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        let loaded = await service.loadCourses()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.title).sorted(), ["Math", "Science"])
    }

    func test_saveAssignments_andLoadAssignments_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let assignments = [makeAssignment(title: "HW 1"), makeAssignment(title: "HW 2")]
        service.saveAssignments(assignments)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadAssignments()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.title).sorted(), ["HW 1", "HW 2"])
    }

    func test_saveGrades_andLoadGrades_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let grades = [makeGradeEntry()]
        service.saveGrades(grades)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadGrades()
        XCTAssertEqual(loaded.count, 1)
    }

    func test_saveUserProfile_andLoadUserProfile_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let user = makeUser()
        service.saveUserProfile(user)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadUserProfile()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.firstName, "Test")
        XCTAssertEqual(loaded?.lastName, "User")
        XCTAssertEqual(loaded?.email, "test@example.com")
    }

    // MARK: - Overwrite Tests

    func test_saveCourses_overwritesPreviousData() async {
        service.setCurrentUser(testUserId1)

        // Save initial data
        service.saveCourses([makeCourse(title: "Original")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Overwrite with new data
        service.saveCourses([makeCourse(title: "Replaced"), makeCourse(title: "New")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadCourses()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertFalse(loaded.contains(where: { $0.title == "Original" }))
    }

    // MARK: - Load Returns Empty/Nil for Non-Existent Data

    func test_loadCourses_returnsEmpty_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadCourses()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadAssignments_returnsEmpty_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadAssignments()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadGrades_returnsEmpty_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadGrades()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadUserProfile_returnsNil_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadUserProfile()
        XCTAssertNil(loaded)
    }

    func test_loadConversations_returnsEmpty_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadConversations()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Load Returns Empty When No User Set

    func test_loadCourses_returnsEmpty_whenNoUserSet() async {
        service.clearCurrentUser()
        let loaded = await service.loadCourses()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadUserProfile_returnsNil_whenNoUserSet() async {
        service.clearCurrentUser()
        let loaded = await service.loadUserProfile()
        XCTAssertNil(loaded)
    }

    // MARK: - ClearAllData Tests

    func test_clearAllData_removesAllFiles() async {
        service.setCurrentUser(testUserId1)

        // Save some data first
        service.saveCourses([makeCourse()])
        service.saveAssignments([makeAssignment()])
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify data exists
        let coursesBeforeClear = await service.loadCourses()
        XCTAssertFalse(coursesBeforeClear.isEmpty)

        // Clear all data
        service.clearAllData()

        // Verify data is gone
        let coursesAfterClear = await service.loadCourses()
        XCTAssertTrue(coursesAfterClear.isEmpty)

        let assignmentsAfterClear = await service.loadAssignments()
        XCTAssertTrue(assignmentsAfterClear.isEmpty)
    }

    func test_clearAllData_resetsCachedDataSize() async {
        service.setCurrentUser(testUserId1)

        service.saveCourses([makeCourse()])
        try? await Task.sleep(nanoseconds: 500_000_000)

        service.clearAllData()
        XCTAssertEqual(service.cachedDataSize, 0)
    }

    func test_clearAllData_doesNothing_whenNoUserSet() {
        service.clearCurrentUser()
        // Should not crash
        service.clearAllData()
        XCTAssertEqual(service.cachedDataSize, 0)
    }

    // MARK: - User Isolation Tests

    func test_differentUsers_haveIsolatedStorage() async {
        // Save data for user 1
        service.setCurrentUser(testUserId1)
        service.saveCourses([makeCourse(title: "User1 Course")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Switch to user 2 and save different data
        service.setCurrentUser(testUserId2)
        service.saveCourses([makeCourse(title: "User2 Course")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify user 2 sees only their data
        let user2Courses = await service.loadCourses()
        XCTAssertEqual(user2Courses.count, 1)
        XCTAssertEqual(user2Courses.first?.title, "User2 Course")

        // Switch back to user 1 and verify their data is still there
        service.setCurrentUser(testUserId1)
        let user1Courses = await service.loadCourses()
        XCTAssertEqual(user1Courses.count, 1)
        XCTAssertEqual(user1Courses.first?.title, "User1 Course")
    }

    func test_clearAllData_onlyAffectsCurrentUser() async {
        // Save data for both users
        service.setCurrentUser(testUserId1)
        service.saveCourses([makeCourse(title: "User1 Course")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        service.setCurrentUser(testUserId2)
        service.saveCourses([makeCourse(title: "User2 Course")])
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Clear user 2's data
        service.clearAllData()

        let user2Courses = await service.loadCourses()
        XCTAssertTrue(user2Courses.isEmpty)

        // User 1's data should still exist
        service.setCurrentUser(testUserId1)
        let user1Courses = await service.loadCourses()
        XCTAssertEqual(user1Courses.count, 1)
        XCTAssertEqual(user1Courses.first?.title, "User1 Course")
    }

    // MARK: - Save Guard Tests (no user set)

    func test_saveCourses_doesNothing_whenNoUserSet() async {
        service.clearCurrentUser()
        // Should not crash and should not persist
        service.saveCourses([makeCourse()])
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Even after setting a user, the data should not be there
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadCourses()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - SyncResult Tests

    func test_saveSyncResult_andLoadSyncResult_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let result = SyncResult(
            itemsSynced: 42,
            conflictsFound: 2,
            conflictsResolved: 2,
            errors: []
        )
        service.saveSyncResult(result)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadSyncResult()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.itemsSynced, 42)
        XCTAssertEqual(loaded?.conflictsFound, 2)
        XCTAssertTrue(loaded?.isSuccess ?? false)
    }

    func test_loadSyncResult_returnsNil_whenNoDataSaved() async {
        service.setCurrentUser(testUserId1)
        let loaded = await service.loadSyncResult()
        XCTAssertNil(loaded)
    }

    // MARK: - Metadata Tests

    func test_saveMetadata_andLoadMetadata_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let metadata = [
            CachedItemMetadata(
                id: UUID(),
                entityType: "course",
                entityName: "Math",
                modifiedAt: Date(),
                isLocallyModified: true
            )
        ]
        service.saveMetadata(metadata)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadMetadata()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.entityType, "course")
        XCTAssertEqual(loaded.first?.entityName, "Math")
        XCTAssertTrue(loaded.first?.isLocallyModified ?? false)
    }

    // MARK: - Conflict History Tests

    func test_saveConflictHistory_andLoadConflictHistory_roundTrip() async {
        service.setCurrentUser(testUserId1)

        let conflicts = [
            SyncConflict(
                entityType: "assignment",
                entityId: UUID().uuidString,
                entityName: "HW 1",
                localModifiedAt: Date().addingTimeInterval(-3600),
                serverModifiedAt: Date(),
                resolution: .serverWins
            )
        ]
        service.saveConflictHistory(conflicts)

        try? await Task.sleep(nanoseconds: 500_000_000)

        let loaded = await service.loadConflictHistory()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.entityType, "assignment")
        XCTAssertEqual(loaded.first?.resolution, .serverWins)
    }

    // MARK: - Formatted Cache Size

    func test_formattedCacheSize_returnsHumanReadableString() {
        service.setCurrentUser(testUserId1)
        // Initially should return some form of "Zero KB" or "0 bytes"
        let formatted = service.formattedCacheSize
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Last Sync Date

    func test_lastSyncDate_defaultsToNil() {
        service.setCurrentUser(testUserId1)
        // Remove any existing value by clearing
        service.lastSyncDate = nil
        XCTAssertNil(service.lastSyncDate)
    }

    func test_lastSyncDate_canBeSetAndRetrieved() {
        service.setCurrentUser(testUserId1)
        let now = Date()
        service.lastSyncDate = now
        XCTAssertNotNil(service.lastSyncDate)
        // Accuracy within 1 second due to UserDefaults serialization
        XCTAssertEqual(
            service.lastSyncDate!.timeIntervalSince1970,
            now.timeIntervalSince1970,
            accuracy: 1.0
        )
        // Clean up
        service.lastSyncDate = nil
    }
}
