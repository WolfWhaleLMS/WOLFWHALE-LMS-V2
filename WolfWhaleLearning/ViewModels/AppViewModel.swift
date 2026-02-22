import SwiftUI
import Supabase
import UserNotifications

@Observable
@MainActor
class AppViewModel {

    // MARK: - Pagination Helper

    struct PaginationState {
        var offset: Int = 0
        var hasMore: Bool = true
        var isLoadingMore: Bool = false
        let pageSize: Int

        init(pageSize: Int = 50) {
            self.pageSize = pageSize
        }

        mutating func reset() {
            offset = 0
            hasMore = true
            isLoadingMore = false
        }
    }

    // MARK: - Search Context

    enum SearchContext {
        case courses, assignments, users, conversations
    }

    // MARK: - Properties

    var currentUser: User?
    var isAuthenticated = false
    var email = ""
    var password = ""
    var isLoading = false
    var isCheckingSession = true
    var isDataLoading = false
    var loginError: String?

    var courses: [Course] = []
    var assignments: [Assignment] = []
    var quizzes: [Quiz] = []
    var grades: [GradeEntry] = []
    var attendance: [AttendanceRecord] = []
    var achievements: [Achievement] = []
    var leaderboard: [LeaderboardEntry] = []
    var conversations: [Conversation] = []
    var announcements: [Announcement] = []
    var children: [ChildInfo] = []
    var parentAlerts: [ParentAlert] = []
    var schoolMetrics: SchoolMetrics?
    var allUsers: [ProfileDTO] = []
    var dataError: String?
    var gradeError: String?
    var enrollmentError: String?

    // MARK: - XP & Gamification
    var currentXP: Int = 0
    var currentLevel: Int = 1
    var currentStreak: Int = 0
    var currentCoins: Int = 0
    var badges: [Badge] = []
    /// Temporarily set when XP is gained; views animate this value then clear it.
    var xpGainAmount: Int = 0
    var showXPGain: Bool = false
    private var xpLoaded = false

    var xpProgressInLevel: Double {
        XPLevelSystem.progressInLevel(xp: currentXP)
    }

    var xpToNextLevel: Int {
        XPLevelSystem.xpToNextLevel(xp: currentXP)
    }

    var levelTierName: String {
        XPLevelSystem.tierName(forLevel: currentLevel)
    }

    // MARK: - Pagination State
    var coursePagination = PaginationState(pageSize: 50)
    var assignmentPagination = PaginationState(pageSize: 50)
    var conversationPagination = PaginationState(pageSize: 50)
    var userPagination = PaginationState(pageSize: 30)

    // MARK: - Lazy Loading Flags
    private var assignmentsLoaded = false
    private var conversationsLoaded = false
    private var gradesLoaded = false
    private var leaderboardLoaded = false
    private var quizzesLoaded = false
    private var attendanceLoaded = false
    private var achievementsLoaded = false

    // MARK: - Search Debouncing
    private var searchTask: Task<Void, Never>?

    var isDemoMode = false
    private let mockService = MockDataService.shared
    private let dataService = DataService.shared
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    /// Auto-refresh interval in seconds (5 minutes).
    private let autoRefreshInterval: TimeInterval = 300
    let networkMonitor = NetworkMonitor()

    // MARK: - Audit Logging (FERPA/GDPR Compliance)
    private let auditLog = AuditLogService()

    // MARK: - Grade Calculation (Weighted)
    var gradeService = GradeCalculationService()

    /// Weighted grade results for every course the student is enrolled in.
    /// Each result includes per-category breakdowns, letter grade, and GPA points
    /// computed using the teacher-configured weights (or defaults).
    var courseGradeResults: [CourseGradeResult] {
        // Build a unique set of courseIds from grade entries
        let uniqueCourseIds = Set(grades.map(\.courseId))
        return uniqueCourseIds.compactMap { courseId -> CourseGradeResult? in
            let courseGrades = grades.filter { $0.courseId == courseId }
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

    // MARK: - Notifications
    var notificationService = NotificationService()

    // MARK: - Due Date Reminders (Integration Layer)
    var dueDateReminderService = DueDateReminderService()

    // MARK: - Push Notifications (Remote)
    // Lazy: APNs registration can crash without proper provisioning/entitlements
    // Internal so ContentView can wire the AppDelegate's shared instance.
    var _pushService: PushNotificationService?
    var pushService: PushNotificationService {
        if let existing = _pushService { return existing }
        let service = PushNotificationService()
        _pushService = service
        return service
    }

    // MARK: - Deep Link Navigation
    var deepLinkCourseId: UUID?
    var deepLinkQuizId: UUID?
    var deepLinkShowTools: Bool = false
    var deepLinkShowWellness: Bool = false
    var deepLinkShowSharePlay: Bool = false
    var deepLinkShowRecommendations: Bool = false

    // MARK: - Biometric Auth
    var biometricService = BiometricAuthService()
    var isAppLocked: Bool = false

    var biometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.biometricEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.biometricEnabled) }
    }

    // MARK: - Calendar Sync
    // Lazy: EventKit may require entitlements/permissions that crash without provisioning
    private var _calendarService: CalendarService?
    var calendarService: CalendarService {
        if let existing = _calendarService { return existing }
        let service = CalendarService()
        _calendarService = service
        return service
    }
    var calendarSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.calendarSyncEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.calendarSyncEnabled) }
    }

    // MARK: - Offline Storage & Cloud Sync
    var offlineStorage = OfflineStorageService()
    // Lazy: CKContainer.default() crashes without iCloud capability/entitlements
    private var _cloudSync: CloudSyncService?
    var cloudSync: CloudSyncService {
        if let existing = _cloudSync { return existing }
        let service = CloudSyncService()
        _cloudSync = service
        return service
    }

    // MARK: - Speech Recognition
    // Lazy: Microphone & speech recognition require entitlements/permissions
    private var _speechService: SpeechService?
    var speechService: SpeechService {
        if let existing = _speechService { return existing }
        let service = SpeechService()
        _speechService = service
        return service
    }

    // MARK: - CoreSpotlight Search Indexing
    private var _spotlightService: SpotlightService?
    var spotlightService: SpotlightService {
        if let existing = _spotlightService { return existing }
        let service = SpotlightService()
        _spotlightService = service
        return service
    }

    // MARK: - AI Learning Recommendations (CoreML)
    private var _recommendationService: LearningRecommendationService?
    var recommendationService: LearningRecommendationService {
        if let existing = _recommendationService { return existing }
        let service = LearningRecommendationService()
        _recommendationService = service
        return service
    }

    // MARK: - SharePlay (GroupActivities)
    #if canImport(GroupActivities)
    private var _sharePlayService: SharePlayService?
    var sharePlayService: SharePlayService {
        if let existing = _sharePlayService { return existing }
        let service = SharePlayService()
        _sharePlayService = service
        return service
    }
    #endif

    // MARK: - HealthKit Wellness
    // Lazy: HealthKit requires entitlements and authorization
    private var _healthService: HealthService?
    var healthService: HealthService {
        if let existing = _healthService { return existing }
        let service = HealthService()
        _healthService = service
        return service
    }

    // MARK: - VisionKit Document Scanner
    private var _documentScannerService: DocumentScannerService?
    var documentScannerService: DocumentScannerService {
        if let existing = _documentScannerService { return existing }
        let service = DocumentScannerService()
        _documentScannerService = service
        return service
    }

    // MARK: - PencilKit Drawing
    private var _drawingService: DrawingService?
    var drawingService: DrawingService {
        if let existing = _drawingService { return existing }
        let service = DrawingService()
        _drawingService = service
        return service
    }

    /// GPA on a 4.0 scale, computed from weighted course grades.
    /// Uses teacher-configured weights per course (defaults if none set).
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

    /// Forces a recalculation of weighted grades (called after teacher saves new weights).
    /// Because `courseGradeResults` is a computed property reading from `grades`,
    /// we trigger an observation update by toggling a flag the view model publishes.
    func invalidateGradeCalculations() {
        // Touch the grades array to trigger @Observable recalculation
        // This is a lightweight operation that notifies observers
        let current = grades
        grades = current
    }

    var upcomingAssignments: [Assignment] {
        assignments.filter { !$0.isSubmitted && !$0.isOverdue }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var overdueAssignments: [Assignment] {
        assignments.filter { $0.isOverdue }
    }

    var totalUnreadMessages: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var pendingGradingCount: Int {
        assignments.filter { $0.isSubmitted && $0.grade == nil }.count
    }

    var unreadParentAlertCount: Int {
        parentAlerts.filter { !$0.isRead }.count
    }

    var remainingUserSlots: Int {
        guard let user = currentUser else { return 0 }
        return max(0, user.userSlotsTotal - user.userSlotsUsed)
    }

    func checkSession() {
        Task {
            defer { isCheckingSession = false }

            // If we were in demo mode and there's no real Supabase session,
            // clear all state so the user lands back on the login screen.
            if isDemoMode {
                do {
                    _ = try await supabaseClient.auth.session
                } catch {
                    // No valid session — tear down demo state
                    isDemoMode = false
                    isAuthenticated = false
                    currentUser = nil
                    return
                }
            }

            do {
                let session = try await supabaseClient.auth.session
                try await fetchProfile(userId: session.user.id)
                await loadData()
                isAuthenticated = true
                startAutoRefresh()

                // Re-register push token on session restore
                pushService.registerForRemoteNotifications()
                await pushService.sendTokenToServer(userId: session.user.id)
            } catch {
                #if DEBUG
                print("[AppViewModel] Session check failed: \(error)")
                #endif
            }
        }
    }

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Please enter your email and password"
            return
        }

        isLoading = true
        loginError = nil

        Task {
            do {
                try await supabaseClient.auth.signIn(email: email, password: password)
                let session = try await supabaseClient.auth.session
                try await fetchProfile(userId: session.user.id)
                await loadData()
                isAuthenticated = true
                startAutoRefresh()

                // Register device for remote push notifications
                pushService.registerForRemoteNotifications()
                await pushService.sendTokenToServer(userId: session.user.id)

                // Audit: record successful login
                auditLog.setUser(session.user.id)
                await auditLog.log(AuditAction.login, entityType: AuditEntityType.user, entityId: session.user.id.uuidString)

                // Clear password from memory after successful login
                password = ""
            } catch {
                loginError = mapAuthError(error)
                password = ""
            }
            isLoading = false
        }
    }

    // MARK: - Sign Up
    // Role is NOT stored on profiles — it goes into tenant_memberships.
    func signUp(name: String, email: String, password: String, role: UserRole, schoolCode: String?) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let nameComponents = trimmedName.split(separator: " ", maxSplits: 1)
        let firstName = String(nameComponents.first ?? "")
        let lastName = nameComponents.count > 1 ? String(nameComponents.last ?? "") : ""
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        // Resolve schoolCode to a tenant ID (for all roles including parent)
        var tenantId: UUID? = nil
        if let code = schoolCode?.trimmingCharacters(in: .whitespaces).uppercased(), !code.isEmpty {
            struct TenantLookup: Decodable { let id: UUID }
            let results: [TenantLookup] = try await supabaseClient
                .from("tenants")
                .select("id")
                .eq("invite_code", value: code)
                .limit(1)
                .execute()
                .value
            tenantId = results.first?.id
        }

        let result = try await supabaseClient.auth.signUp(
            email: trimmedEmail,
            password: password,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName),
                "role": .string(role.rawValue)
            ]
        )

        // Insert into profiles (without role — role is NOT on profiles table)
        let newProfile = InsertProfileDTO(
            id: result.user.id,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: nil,
            phone: nil,
            dateOfBirth: nil,
            bio: nil,
            timezone: nil,
            language: nil,
            gradeLevel: nil,
            fullName: "\(firstName) \(lastName)"
        )
        try await supabaseClient
            .from("profiles")
            .insert(newProfile)
            .execute()

        // Insert role into tenant_memberships for ALL roles (student, teacher, parent, admin)
        let membershipDTO = InsertTenantMembershipDTO(
            userId: result.user.id,
            tenantId: tenantId,
            role: role.rawValue,
            status: "active",
            joinedAt: nil,
            invitedAt: nil,
            invitedBy: nil
        )
        try await supabaseClient
            .from("tenant_memberships")
            .insert(membershipDTO)
            .execute()

        // If student, create initial student_xp row
        if role == .student {
            let xpDTO = InsertStudentXpDTO(
                studentId: result.user.id,
                tenantId: tenantId,
                totalXp: 0,
                currentLevel: 1,
                currentTier: nil,
                streakDays: 0,
                coins: 0,
                totalCoinsEarned: nil,
                totalCoinsSpent: nil
            )
            try await supabaseClient
                .from("student_xp")
                .insert(xpDTO)
                .execute()
        }
    }

    func loginAsDemo(role: UserRole) {
        isDemoMode = true
        currentUser = mockService.sampleUser(role: role)
        loadMockData()
        withAnimation(.smooth) {
            isAuthenticated = true
        }
    }

    func logout() {
        // Audit: record logout before clearing state
        if !isDemoMode {
            Task { await auditLog.log(AuditAction.logout, entityType: AuditEntityType.user, entityId: currentUser?.id.uuidString) }
            Task { await auditLog.clearUser() }
        }

        // 1. Cancel any pending background refresh to prevent network storms
        refreshTask?.cancel()
        refreshTask = nil
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        if !isDemoMode {
            Task {
                // Remove push token from server before signing out
                if let userId = currentUser?.id {
                    await pushService.removeTokenFromServer(userId: userId)
                }
                pushService.clearAllNotifications()
                try? await supabaseClient.auth.signOut()
            }
        }

        // Always invalidate cache, even in demo mode, to prevent data leakage
        Task { await CacheService.shared.invalidateAll() }

        // 2. Stop radio playback so audio doesn't persist after logout
        RadioService.shared.stop()

        // 3. Clear offline storage and user scope
        offlineStorage.clearAllData()
        offlineStorage.clearCurrentUser()

        // 4. Clear Siri / App Intents cached data from UserDefaults
        //    so the next user doesn't see stale grades, assignments, or schedule
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.upcomingAssignments)
        defaults.removeObject(forKey: UserDefaultsKeys.gradesSummary)
        defaults.removeObject(forKey: UserDefaultsKeys.scheduleToday)

        // 5. Remove all pending local notification reminders for the previous user
        //    and clear any deep-link state so they don't carry over
        notificationService.cancelAllNotifications()
        notificationService.clearDeepLinks()

        // 5a. Cancel all due-date reminders managed by the integration service
        Task { await dueDateReminderService.cancelAllReminders() }

        // 6. Reset biometric lock state and deep-link navigation so the next login starts clean
        isAppLocked = false
        deepLinkCourseId = nil
        deepLinkQuizId = nil
        deepLinkShowTools = false
        deepLinkShowWellness = false
        deepLinkShowSharePlay = false
        deepLinkShowRecommendations = false

        // 7. Clear lazy services so they are re-created fresh for the next user
        _pushService = nil
        _calendarService = nil
        _cloudSync = nil
        _speechService = nil
        _recommendationService = nil
        _healthService = nil
        _documentScannerService = nil
        _drawingService = nil
        #if canImport(GroupActivities)
        _sharePlayService = nil
        #endif

        // 8. Deindex all Spotlight items for the previous user
        Task { await spotlightService.deindexAllContent() }
        _spotlightService = nil

        isDemoMode = false

        // 8. Reset pagination state so the next session starts fresh
        coursePagination.reset()
        assignmentPagination.reset()
        conversationPagination.reset()
        userPagination.reset()

        // 9. Reset lazy-loading flags
        assignmentsLoaded = false
        conversationsLoaded = false
        gradesLoaded = false
        leaderboardLoaded = false
        quizzesLoaded = false
        attendanceLoaded = false
        achievementsLoaded = false

        // 10. Cancel any pending search
        searchTask?.cancel()
        searchTask = nil

        // 11. Animate only the auth transition; clear data arrays outside animation
        // to avoid a burst of cascading view recalculations
        withAnimation(.smooth) {
            isAuthenticated = false
        }

        // 12. Clear all user data and error states
        currentUser = nil
        email = ""
        password = ""
        courses = []
        assignments = []
        quizzes = []
        grades = []
        attendance = []
        achievements = []
        leaderboard = []
        conversations = []
        announcements = []
        children = []
        parentAlerts = []
        schoolMetrics = nil
        allUsers = []
        dataError = nil
        gradeError = nil
        enrollmentError = nil
        loginError = nil
        isDataLoading = false
    }

    // MARK: - Fetch Profile
    // Loads profile from profiles table, role from tenant_memberships, streak from student_xp,
    // and email from Supabase Auth session.
    private func fetchProfile(userId: UUID) async throws {
        let profile: ProfileDTO = try await supabaseClient
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        // Get email from Auth session (not stored in profiles table)
        let session = try await supabaseClient.auth.session
        let userEmail = session.user.email ?? ""

        // Fetch role from tenant_memberships
        let memberships: [TenantMembershipDTO] = try await supabaseClient
            .from("tenant_memberships")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        let role = memberships.first.flatMap { UserRole(rawValue: $0.role) } ?? .student

        // Derive schoolId from tenant_memberships.tenant_id
        let tenantId = memberships.first?.tenantId?.uuidString

        // Fetch streak from student_xp (only relevant for students, but safe to query)
        var streak = 0
        let xpEntries: [StudentXpDTO] = try await supabaseClient
            .from("student_xp")
            .select()
            .eq("student_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        if let xpEntry = xpEntries.first {
            streak = xpEntry.streakDays ?? 0
        }

        var user = profile.toUser(email: userEmail, role: role, streak: streak)
        user.schoolId = tenantId
        currentUser = user
    }

    // MARK: - Sync streak to student_xp table (NOT profiles)
    func syncProfile() {
        guard let user = currentUser, !isDemoMode else { return }
        Task {
            let update = UpdateStudentXpDTO(
                streakDays: user.streak
            )
            _ = try? await supabaseClient
                .from("student_xp")
                .update(update)
                .eq("student_id", value: user.id.uuidString)
                .execute()
        }
    }

    func loadData() async {
        guard let user = currentUser else { return }
        if isDemoMode {
            loadMockData()
            return
        }

        // Scope offline storage to the current user to prevent cross-user data leakage
        offlineStorage.setCurrentUser(user.id)

        guard networkMonitor.isConnected else {
            if offlineStorage.hasOfflineData {
                dataError = "No internet connection. Using offline data."
                loadOfflineData()
            } else {
                dataError = "No internet connection. Using offline mode."
                loadMockData()
            }
            return
        }

        isDataLoading = true
        dataError = nil

        // Reset lazy-loading flags so fresh data can be fetched on-demand
        assignmentsLoaded = false
        conversationsLoaded = false
        gradesLoaded = false
        leaderboardLoaded = false
        quizzesLoaded = false
        attendanceLoaded = false
        achievementsLoaded = false

        do {
            // Always load: courses (first page) and announcements — these power the dashboard
            coursePagination.reset()
            let newCourses = try await dataService.fetchCourses(
                for: user.id,
                role: user.role,
                schoolId: user.schoolId,
                offset: coursePagination.offset,
                limit: coursePagination.pageSize
            )
            courses = newCourses
            coursePagination.offset = newCourses.count
            coursePagination.hasMore = newCourses.count >= coursePagination.pageSize

            // Always load announcements (small, capped at 20 by the service)
            announcements = (try? await dataService.fetchAnnouncements()) ?? []

            // Per-role essential data for the dashboard
            switch user.role {
            case .student:
                // Students need grades summary on the dashboard
                let courseIds = courses.map(\.id)
                grades = (try? await dataService.fetchGrades(for: user.id, courseIds: courseIds)) ?? []
                gradesLoaded = true

            case .teacher:
                // Courses already loaded above — that is what teachers see on dashboard
                break

            case .parent:
                children = (try? await dataService.fetchChildren(for: user.id)) ?? []
                scheduleParentAlerts()

            case .admin, .superAdmin:
                // Load school metrics and first page of users for admin dashboard
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.userPagination.reset()
                        let newUsers = (try? await self.dataService.fetchAllUsers(
                            schoolId: user.schoolId,
                            offset: self.userPagination.offset,
                            limit: self.userPagination.pageSize
                        )) ?? []
                        self.allUsers = newUsers
                        self.userPagination.offset = newUsers.count
                        self.userPagination.hasMore = newUsers.count >= self.userPagination.pageSize
                    }
                    group.addTask { @MainActor in
                        self.schoolMetrics = try? await self.dataService.fetchSchoolMetrics(schoolId: user.schoolId)
                    }
                }
            }
            isDataLoading = false

            // Move expensive I/O operations off the main thread
            let assignmentsForReminders = assignments
            Task.detached(priority: .utility) { @MainActor [weak self] in
                self?.cacheDataForSiri()
                self?.cacheDataForWidgets()
                self?.saveDataToOfflineStorage()
                self?.notificationService.scheduleAllAssignmentReminders(assignments: assignmentsForReminders)

                // Refresh due-date reminders via the integration service
                if let self {
                    await self.dueDateReminderService.refreshReminders(assignments: assignmentsForReminders)
                }

                // Index content for Spotlight search
                if let self {
                    await self.spotlightService.indexAllContent(
                        courses: self.courses,
                        assignments: self.assignments,
                        quizzes: self.quizzes
                    )
                }

                // Generate AI learning recommendations for students
                if let self, self.currentUser?.role == .student {
                    self.recommendationService.generateRecommendations(
                        courses: self.courses,
                        assignments: self.assignments,
                        quizzes: self.quizzes,
                        grades: self.grades,
                        streakDays: self.currentUser?.streak ?? 0
                    )
                }
            }
        } catch {
            isDataLoading = false
            if offlineStorage.hasOfflineData {
                dataError = "Could not load data. Using offline data."
                loadOfflineData()
            } else {
                dataError = "Could not load data. Using offline mode."
                loadMockData()
            }
        }
    }

    // MARK: - Lazy "If Needed" Loaders

    /// Called when user opens the Assignments tab. Loads assignments only if not already loaded.
    func loadAssignmentsIfNeeded() async {
        guard !assignmentsLoaded, !isDemoMode, let user = currentUser else { return }
        let courseIds = courses.map(\.id)
        assignmentPagination.reset()
        let newAssignments = (try? await dataService.fetchAssignments(
            for: user.id,
            role: user.role,
            courseIds: courseIds,
            offset: assignmentPagination.offset,
            limit: assignmentPagination.pageSize
        )) ?? []
        assignments = newAssignments
        assignmentPagination.offset = newAssignments.count
        assignmentPagination.hasMore = newAssignments.count >= assignmentPagination.pageSize
        assignmentsLoaded = true
    }

    /// Called when user opens the Messages tab. Loads conversations only if not already loaded.
    func loadConversationsIfNeeded() async {
        guard !conversationsLoaded, !isDemoMode, let user = currentUser else { return }
        conversationPagination.reset()
        let newConversations = (try? await dataService.fetchConversations(
            for: user.id,
            offset: conversationPagination.offset,
            limit: conversationPagination.pageSize
        )) ?? []
        conversations = newConversations
        conversationPagination.offset = newConversations.count
        conversationPagination.hasMore = newConversations.count >= conversationPagination.pageSize
        conversationsLoaded = true
    }

    /// Called when user opens the Grades tab. Loads grades only if not already loaded.
    func loadGradesIfNeeded() async {
        guard !gradesLoaded, !isDemoMode, let user = currentUser else { return }
        let courseIds = courses.map(\.id)
        grades = (try? await dataService.fetchGrades(for: user.id, courseIds: courseIds)) ?? []
        gradesLoaded = true
    }

    /// Called when user opens the Leaderboard. Loads leaderboard only if not already loaded.
    func loadLeaderboardIfNeeded() async {
        guard !leaderboardLoaded, !isDemoMode else { return }
        await loadLeaderboard()
        leaderboardLoaded = true
    }

    /// Called when user opens the Quizzes section. Loads quizzes only if not already loaded.
    func loadQuizzesIfNeeded() async {
        guard !quizzesLoaded, !isDemoMode, let user = currentUser else { return }
        let courseIds = courses.map(\.id)
        quizzes = (try? await dataService.fetchQuizzes(for: user.id, courseIds: courseIds)) ?? []
        quizzesLoaded = true
    }

    /// Called when user opens the Attendance section. Loads attendance only if not already loaded.
    func loadAttendanceIfNeeded() async {
        guard !attendanceLoaded, !isDemoMode, let user = currentUser else { return }
        attendance = (try? await dataService.fetchAttendance(for: user.id)) ?? []
        attendanceLoaded = true
    }

    /// Called when user opens the Achievements section. Loads achievements only if not already loaded.
    func loadAchievementsIfNeeded() async {
        guard !achievementsLoaded, !isDemoMode, let user = currentUser else { return }
        achievements = (try? await dataService.fetchAchievements(for: user.id)) ?? []
        achievementsLoaded = true
    }


    /// Called when user opens XPProfileView. Loads XP, level, streak, and badges from Supabase.
    func loadXPIfNeeded() async {
        guard !xpLoaded, !isDemoMode, let user = currentUser else { return }

        do {
            let entries: [StudentXpDTO] = try await supabaseClient
                .from("student_xp")
                .select()
                .eq("student_id", value: user.id.uuidString)
                .execute()
                .value

            if let entry = entries.first {
                currentXP = entry.totalXp ?? 0
                currentLevel = XPLevelSystem.level(forXP: currentXP)
                currentStreak = entry.streakDays ?? 0
                currentCoins = entry.coins ?? 0
            }
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load XP data: \(error)")
            #endif
        }

        refreshBadges()
        xpLoaded = true
    }

    /// Recomputes badge earned/progress state from current data.
    func refreshBadges() {
        let submittedCount = assignments.filter(\.isSubmitted).count
        let completedQuizCount = quizzes.filter(\.isCompleted).count
        let hasPerfectScore = grades.contains { $0.numericGrade >= 100.0 }
        let completedLessonCount = courses.reduce(0) { $0 + $1.completedLessons }
        let hasCourseComplete = courses.contains { $0.totalLessons > 0 && $0.completedLessons == $0.totalLessons }
        let messageCount = conversations.reduce(0) { $0 + $1.messages.count }

        var result: [Badge] = []

        result.append(Badge(badgeType: .firstAssignment, isEarned: submittedCount >= 1, progress: min(Double(submittedCount), 1.0)))
        result.append(Badge(badgeType: .quizMaster, isEarned: completedQuizCount >= 5, progress: min(Double(completedQuizCount) / 5.0, 1.0)))
        result.append(Badge(badgeType: .perfectScore, isEarned: hasPerfectScore, progress: hasPerfectScore ? 1.0 : 0.0))
        result.append(Badge(badgeType: .sevenDayStreak, isEarned: currentStreak >= 7, progress: min(Double(currentStreak) / 7.0, 1.0)))
        result.append(Badge(badgeType: .courseComplete, isEarned: hasCourseComplete, progress: hasCourseComplete ? 1.0 : 0.0))

        let earlyCount = assignments.filter { $0.isSubmitted && ($0.submission != nil) }.count
        result.append(Badge(badgeType: .earlyBird, isEarned: earlyCount >= 3, progress: min(Double(earlyCount) / 3.0, 1.0)))
        result.append(Badge(badgeType: .socialLearner, isEarned: messageCount >= 10, progress: min(Double(messageCount) / 10.0, 1.0)))
        result.append(Badge(badgeType: .firstSteps, isEarned: completedLessonCount >= 1, progress: min(Double(completedLessonCount), 1.0)))
        result.append(Badge(badgeType: .tenLessons, isEarned: completedLessonCount >= 10, progress: min(Double(completedLessonCount) / 10.0, 1.0)))
        result.append(Badge(badgeType: .thirtyDayStreak, isEarned: currentStreak >= 30, progress: min(Double(currentStreak) / 30.0, 1.0)))

        badges = result
    }

    // MARK: - Load More (Pagination)

    func loadMoreCourses() async {
        guard !coursePagination.isLoadingMore, coursePagination.hasMore, let user = currentUser, !isDemoMode else { return }
        coursePagination.isLoadingMore = true
        defer { coursePagination.isLoadingMore = false }

        do {
            let newCourses = try await dataService.fetchCourses(
                for: user.id,
                role: user.role,
                schoolId: user.schoolId,
                offset: coursePagination.offset,
                limit: coursePagination.pageSize
            )
            courses.append(contentsOf: newCourses)
            coursePagination.offset += newCourses.count
            coursePagination.hasMore = newCourses.count >= coursePagination.pageSize
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load more courses: \(error)")
            #endif
        }
    }

    func loadMoreAssignments() async {
        guard !assignmentPagination.isLoadingMore, assignmentPagination.hasMore, let user = currentUser, !isDemoMode else { return }
        assignmentPagination.isLoadingMore = true
        defer { assignmentPagination.isLoadingMore = false }

        do {
            let courseIds = courses.map(\.id)
            let newAssignments = try await dataService.fetchAssignments(
                for: user.id,
                role: user.role,
                courseIds: courseIds,
                offset: assignmentPagination.offset,
                limit: assignmentPagination.pageSize
            )
            assignments.append(contentsOf: newAssignments)
            assignmentPagination.offset += newAssignments.count
            assignmentPagination.hasMore = newAssignments.count >= assignmentPagination.pageSize
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load more assignments: \(error)")
            #endif
        }
    }

    func loadMoreConversations() async {
        guard !conversationPagination.isLoadingMore, conversationPagination.hasMore, let user = currentUser, !isDemoMode else { return }
        conversationPagination.isLoadingMore = true
        defer { conversationPagination.isLoadingMore = false }

        do {
            let newConversations = try await dataService.fetchConversations(
                for: user.id,
                offset: conversationPagination.offset,
                limit: conversationPagination.pageSize
            )
            conversations.append(contentsOf: newConversations)
            conversationPagination.offset += newConversations.count
            conversationPagination.hasMore = newConversations.count >= conversationPagination.pageSize
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load more conversations: \(error)")
            #endif
        }
    }

    func loadMoreUsers() async {
        guard !userPagination.isLoadingMore, userPagination.hasMore, let user = currentUser, !isDemoMode else { return }
        userPagination.isLoadingMore = true
        defer { userPagination.isLoadingMore = false }

        do {
            let newUsers = try await dataService.fetchAllUsers(
                schoolId: user.schoolId,
                offset: userPagination.offset,
                limit: userPagination.pageSize
            )
            allUsers.append(contentsOf: newUsers)
            userPagination.offset += newUsers.count
            userPagination.hasMore = newUsers.count >= userPagination.pageSize
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load more users: \(error)")
            #endif
        }
    }

    // MARK: - Search Debouncing

    func debouncedSearch(query: String, context: SearchContext) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query: query, context: context)
        }
    }

    private func performSearch(query: String, context: SearchContext) async {
        guard let user = currentUser, !isDemoMode else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch context {
        case .courses:
            // Client-side filter since courses are already loaded
            break
        case .assignments:
            // Client-side filter since assignments are already loaded
            break
        case .users:
            // Server-side search: reload users filtered by name
            do {
                allUsers = try await dataService.fetchAllUsers(
                    schoolId: user.schoolId,
                    offset: 0,
                    limit: userPagination.pageSize
                )
            } catch {
                #if DEBUG
                print("[AppViewModel] User search failed: \(error)")
                #endif
            }
        case .conversations:
            // Client-side filter since conversations are already loaded
            break
        }
    }

    /// Returns a cache key scoped to the current user to prevent cross-user data leakage.
    private func userCacheKey(_ base: String) -> String {
        guard let userId = currentUser?.id else { return base }
        return "\(userId.uuidString)-\(base)"
    }

    func loadLeaderboard() async {
        let key = userCacheKey("leaderboard")
        if let cached: [LeaderboardEntry] = await CacheService.shared.get(key) {
            leaderboard = cached
            return
        }
        do {
            leaderboard = try await dataService.fetchLeaderboard()
            await CacheService.shared.set(key, value: leaderboard, ttl: 60)
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load leaderboard: \(error)")
            #endif
        }
    }

    private func loadMockData() {
        courses = mockService.sampleCourses()
        assignments = mockService.sampleAssignments()
        quizzes = mockService.sampleQuizzes()
        grades = mockService.sampleGrades()
        attendance = mockService.sampleAttendance()
        achievements = mockService.sampleAchievements()
        leaderboard = mockService.sampleLeaderboard()
        conversations = mockService.sampleConversations()
        announcements = mockService.sampleAnnouncements()
        children = mockService.sampleChildren()
        schoolMetrics = mockService.sampleSchoolMetrics()

        // Populate XP & gamification for demo mode
        currentXP = 475
        currentLevel = XPLevelSystem.level(forXP: currentXP)
        currentStreak = currentUser?.streak ?? 5
        currentCoins = 120
        refreshBadges()

        cacheDataForSiri()
    }

    // MARK: - Offline Storage Helpers

    private func saveDataToOfflineStorage() {
        offlineStorage.saveCourses(courses)
        offlineStorage.saveAssignments(assignments)
        offlineStorage.saveGrades(grades)
        offlineStorage.saveConversations(conversations)
        if let user = currentUser {
            offlineStorage.saveUserProfile(user)
        }
        offlineStorage.lastSyncDate = Date()
    }

    private func loadOfflineData() {
        // Ensure offline storage is scoped to the current user before loading
        if let userId = currentUser?.id {
            offlineStorage.setCurrentUser(userId)
        }
        courses = offlineStorage.loadCourses()
        assignments = offlineStorage.loadAssignments()
        grades = offlineStorage.loadGrades()
        conversations = offlineStorage.loadConversations()
        if currentUser == nil {
            currentUser = offlineStorage.loadUserProfile()
        }
        cacheDataForSiri()
    }

    func refreshData() {
        // Cancel any pending refresh to prevent network storms
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadData()
        }
    }

    // MARK: - Targeted Refresh Methods (Pull-to-Refresh)

    /// Re-fetches only courses from the data service. Used by pull-to-refresh on course list views.
    func refreshCourses() async {
        guard let user = currentUser, !isDemoMode, networkMonitor.isConnected else { return }
        isDataLoading = true
        dataError = nil
        defer { isDataLoading = false }
        do {
            coursePagination.reset()
            let newCourses = try await dataService.fetchCourses(
                for: user.id,
                role: user.role,
                schoolId: user.schoolId,
                offset: coursePagination.offset,
                limit: coursePagination.pageSize
            )
            courses = newCourses
            coursePagination.offset = newCourses.count
            coursePagination.hasMore = newCourses.count >= coursePagination.pageSize
        } catch {
            dataError = "Could not refresh courses."
            #if DEBUG
            print("[AppViewModel] refreshCourses failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only assignments from the data service. Used by pull-to-refresh on assignment views.
    func refreshAssignments() async {
        guard let user = currentUser, !isDemoMode, networkMonitor.isConnected else { return }
        isDataLoading = true
        dataError = nil
        defer { isDataLoading = false }
        do {
            let courseIds = courses.map(\.id)
            assignmentPagination.reset()
            let newAssignments = try await dataService.fetchAssignments(
                for: user.id,
                role: user.role,
                courseIds: courseIds,
                offset: assignmentPagination.offset,
                limit: assignmentPagination.pageSize
            )
            assignments = newAssignments
            assignmentPagination.offset = newAssignments.count
            assignmentPagination.hasMore = newAssignments.count >= assignmentPagination.pageSize
            assignmentsLoaded = true
        } catch {
            dataError = "Could not refresh assignments."
            #if DEBUG
            print("[AppViewModel] refreshAssignments failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only grades from the data service. Used by pull-to-refresh on the grades view.
    func refreshGrades() async {
        guard let user = currentUser, !isDemoMode, networkMonitor.isConnected else { return }
        isDataLoading = true
        dataError = nil
        defer { isDataLoading = false }
        do {
            let courseIds = courses.map(\.id)
            grades = try await dataService.fetchGrades(for: user.id, courseIds: courseIds)
            gradesLoaded = true
        } catch {
            dataError = "Could not refresh grades."
            #if DEBUG
            print("[AppViewModel] refreshGrades failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only conversations from the data service. Used by pull-to-refresh on the messages view.
    func refreshConversations() async {
        guard let user = currentUser, !isDemoMode, networkMonitor.isConnected else { return }
        isDataLoading = true
        dataError = nil
        defer { isDataLoading = false }
        do {
            conversationPagination.reset()
            let newConversations = try await dataService.fetchConversations(
                for: user.id,
                offset: conversationPagination.offset,
                limit: conversationPagination.pageSize
            )
            conversations = newConversations
            conversationPagination.offset = newConversations.count
            conversationPagination.hasMore = newConversations.count >= conversationPagination.pageSize
            conversationsLoaded = true
        } catch {
            dataError = "Could not refresh conversations."
            #if DEBUG
            print("[AppViewModel] refreshConversations failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only attendance records from the data service. Used by pull-to-refresh on the attendance view.
    func refreshAttendance() async {
        guard let user = currentUser, !isDemoMode, networkMonitor.isConnected else { return }
        isDataLoading = true
        dataError = nil
        defer { isDataLoading = false }
        do {
            attendance = try await dataService.fetchAttendance(for: user.id)
            attendanceLoaded = true
        } catch {
            dataError = "Could not refresh attendance."
            #if DEBUG
            print("[AppViewModel] refreshAttendance failed: \(error)")
            #endif
        }
    }

    // MARK: - Auto-Refresh

    /// Starts a repeating auto-refresh timer. Call when the app enters the foreground
    /// or when the user first authenticates. The timer stops itself when cancelled.
    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoRefreshInterval))
                guard !Task.isCancelled, isAuthenticated, !isDemoMode, networkMonitor.isConnected else { continue }
                await loadData()
            }
        }
    }

    /// Stops the auto-refresh timer. Call when the app backgrounds or the user logs out.
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Called when the app returns to the foreground. Refreshes data if the last
    /// fetch is stale and restarts the auto-refresh timer.
    func handleForegroundResume() {
        guard isAuthenticated, !isDemoMode else { return }
        startAutoRefresh()

        // Sync the due-date reminder count from the notification center.
        // This is lightweight (local query only) and keeps the badge accurate
        // even when offline.
        Task { await dueDateReminderService.syncScheduledCount() }

        // Only refresh if we have a network connection
        guard networkMonitor.isConnected else { return }
        refreshData()
    }

    // MARK: - Cache Data for Siri Intents
    /// Writes lightweight JSON summaries to UserDefaults so App Intents can read
    /// them without needing a live Supabase session.
    func cacheDataForSiri() {
        let defaults = UserDefaults.standard
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 1. Upcoming assignments
        let upcomingItems = upcomingAssignments.prefix(10).map { assignment in
            CachedAssignment(
                title: assignment.title,
                dueDate: isoFormatter.string(from: assignment.dueDate),
                courseName: assignment.courseName
            )
        }
        if let data = try? JSONEncoder().encode(Array(upcomingItems)) {
            defaults.set(data, forKey: UserDefaultsKeys.upcomingAssignments)
        }

        // 2. Grades summary
        let courseGrades = grades.map { entry in
            CachedCourseGrade(
                courseName: entry.courseName,
                letterGrade: entry.letterGrade,
                numericGrade: entry.numericGrade
            )
        }
        let gradesSummary = CachedGradesSummary(gpa: gpa, courseGrades: courseGrades)
        if let data = try? JSONEncoder().encode(gradesSummary) {
            defaults.set(data, forKey: UserDefaultsKeys.gradesSummary)
        }

        // 3. Today's schedule (derived from enrolled courses)
        let scheduleEntries = courses.map { course in
            CachedScheduleEntry(courseName: course.title, time: nil)
        }
        if let data = try? JSONEncoder().encode(scheduleEntries) {
            defaults.set(data, forKey: UserDefaultsKeys.scheduleToday)
        }
    }

    // MARK: - Cache Data for Widgets (App Group)
    /// Writes the same cached data to the shared App Group UserDefaults so
    /// WidgetKit widgets can display grades, assignments, and schedule.
    func cacheDataForWidgets() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.wolfwhale.lms") else { return }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 1. Upcoming assignments
        let upcomingItems = upcomingAssignments.prefix(10).map { assignment in
            CachedAssignment(
                title: assignment.title,
                dueDate: isoFormatter.string(from: assignment.dueDate),
                courseName: assignment.courseName
            )
        }
        if let data = try? JSONEncoder().encode(Array(upcomingItems)) {
            sharedDefaults.set(data, forKey: UserDefaultsKeys.upcomingAssignments)
        }

        // 2. Grades summary
        let courseGrades = grades.map { entry in
            CachedCourseGrade(
                courseName: entry.courseName,
                letterGrade: entry.letterGrade,
                numericGrade: entry.numericGrade
            )
        }
        let gradesSummary = CachedGradesSummary(gpa: gpa, courseGrades: courseGrades)
        if let data = try? JSONEncoder().encode(gradesSummary) {
            sharedDefaults.set(data, forKey: UserDefaultsKeys.gradesSummary)
        }

        // 3. Today's schedule
        let scheduleEntries = courses.map { course in
            CachedScheduleEntry(courseName: course.title, time: nil)
        }
        if let data = try? JSONEncoder().encode(scheduleEntries) {
            sharedDefaults.set(data, forKey: UserDefaultsKeys.scheduleToday)
        }
    }

    // MARK: - Admin: Create User
    // Role goes into tenant_memberships, NOT profiles.
    func createUser(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        role: UserRole
    ) async throws {
        guard let admin = currentUser, admin.role == .admin else {
            throw UserManagementError.unauthorized
        }

        // Input validation
        guard InputValidator.validateEmail(email) else {
            dataError = "Please enter a valid email address."
            throw ValidationError.invalidInput("Please enter a valid email address.")
        }
        let passwordResult = InputValidator.validatePassword(password)
        guard passwordResult.valid else {
            dataError = passwordResult.message
            throw ValidationError.invalidInput(passwordResult.message)
        }
        let firstNameResult = InputValidator.validateName(firstName, fieldName: "First name")
        guard firstNameResult.valid else {
            dataError = firstNameResult.message
            throw ValidationError.invalidInput(firstNameResult.message)
        }
        let lastNameResult = InputValidator.validateName(lastName, fieldName: "Last name")
        guard lastNameResult.valid else {
            dataError = lastNameResult.message
            throw ValidationError.invalidInput(lastNameResult.message)
        }

        let trimFirst = InputValidator.sanitizeText(firstName)
        let trimLast = InputValidator.sanitizeText(lastName)

        let result = try await supabaseClient.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(trimFirst),
                "last_name": .string(trimLast),
                "role": .string(role.rawValue)
            ]
        )

        // Insert into profiles (without role -- role is NOT on profiles table)
        let newProfile = InsertProfileDTO(
            id: result.user.id,
            firstName: trimFirst,
            lastName: trimLast,
            avatarUrl: nil,
            phone: nil,
            dateOfBirth: nil,
            bio: nil,
            timezone: nil,
            language: nil,
            gradeLevel: nil,
            fullName: "\(trimFirst) \(trimLast)"
        )
        try await supabaseClient
            .from("profiles")
            .insert(newProfile)
            .execute()

        // Insert role into tenant_memberships (use admin's tenant if available)
        let adminTenantId = admin.schoolId.flatMap { UUID(uuidString: $0) }
        let membershipDTO = InsertTenantMembershipDTO(
            userId: result.user.id,
            tenantId: adminTenantId,
            role: role.rawValue,
            status: "active",
            joinedAt: nil,
            invitedAt: nil,
            invitedBy: admin.id
        )
        try await supabaseClient
            .from("tenant_memberships")
            .insert(membershipDTO)
            .execute()

        // If student, create initial student_xp row
        if role == .student {
            let xpDTO = InsertStudentXpDTO(
                studentId: result.user.id,
                tenantId: adminTenantId,
                totalXp: 0,
                currentLevel: 1,
                currentTier: nil,
                streakDays: 0,
                coins: 0,
                totalCoinsEarned: nil,
                totalCoinsSpent: nil
            )
            try await supabaseClient
                .from("student_xp")
                .insert(xpDTO)
                .execute()
        }

        // Slot tracking: userSlotsTotal/userSlotsUsed are not DB columns on profiles.
        // They are tracked locally on the User model for plan-based limits.
        currentUser?.userSlotsUsed += 1
        // Reload first page of users instead of fetching all users into memory
        userPagination.reset()
        let freshUsers = try await dataService.fetchAllUsers(
            schoolId: admin.schoolId,
            offset: userPagination.offset,
            limit: userPagination.pageSize
        )
        allUsers = freshUsers
        userPagination.offset = freshUsers.count
        userPagination.hasMore = freshUsers.count >= userPagination.pageSize
    }

    func deleteUser(userId: UUID) async throws {
        guard let admin = currentUser, admin.role == .admin || admin.role == .superAdmin else {
            throw UserManagementError.unauthorized
        }
        guard userId != admin.id else {
            throw UserManagementError.cannotDeleteSelf
        }
        try await dataService.deleteUser(userId: userId)
        allUsers.removeAll { $0.id == userId }
        if currentUser?.userSlotsUsed ?? 0 > 0 {
            currentUser?.userSlotsUsed -= 1
        }

        // Audit: record user deletion (FERPA/GDPR)
        await auditLog.log(
            AuditAction.delete,
            entityType: AuditEntityType.user,
            entityId: userId.uuidString,
            details: ["deleted_by": admin.id.uuidString]
        )
    }

    // MARK: - Teacher: Create Course
    // classCode is NOT on the courses table — it lives in the class_codes table.
    // After creating the course, we insert a row into class_codes.
    func createCourse(
        title: String,
        description: String,
        colorName: String,
        iconSystemName: String = "book.fill",
        subject: String? = nil,
        gradeLevel: String? = nil,
        semester: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        credits: Double? = nil
    ) async throws {
        guard let user = currentUser else { return }

        // Input validation
        let sanitizedTitle = InputValidator.sanitizeText(title)
        let courseNameResult = InputValidator.validateCourseName(sanitizedTitle)
        guard courseNameResult.valid else {
            dataError = courseNameResult.message
            throw ValidationError.invalidInput(courseNameResult.message)
        }
        let sanitizedDescription = InputValidator.sanitizeHTML(InputValidator.sanitizeText(description))

        let classCode = "\(sanitizedTitle.prefix(4).uppercased())-\(Int.random(in: 1000...9999))"

        let dto = InsertCourseDTO(
            tenantId: nil,
            name: sanitizedTitle,
            description: sanitizedDescription,
            subject: subject,
            gradeLevel: gradeLevel,
            createdBy: user.id,
            semester: semester,
            startDate: startDate,
            endDate: endDate,
            syllabusUrl: nil,
            credits: credits,
            status: nil,
            iconSystemName: iconSystemName,
            colorName: colorName
        )
        if !isDemoMode {
            let createdCourse = try await dataService.createCourse(dto)

            // Insert class code into the class_codes table
            let classCodeDTO = InsertClassCodeDTO(
                tenantId: nil,
                courseId: createdCourse.id,
                code: classCode,
                isActive: true,
                expiresAt: nil,
                maxUses: nil,
                createdBy: user.id
            )
            try await supabaseClient
                .from("class_codes")
                .insert(classCodeDTO)
                .execute()

            courses = try await dataService.fetchCourses(for: user.id, role: user.role, schoolId: user.schoolId)

            // Audit: record course creation
            await auditLog.log(
                AuditAction.create,
                entityType: AuditEntityType.course,
                entityId: createdCourse.id.uuidString,
                details: ["title": sanitizedTitle, "created_by": user.id.uuidString]
            )
        } else {
            let newCourse = Course(
                id: UUID(), title: sanitizedTitle, description: sanitizedDescription,
                teacherName: user.fullName, iconSystemName: iconSystemName,
                colorName: colorName, modules: [], enrolledStudentCount: 0,
                progress: 0, classCode: classCode
            )
            courses.append(newCourse)
        }
    }

    // MARK: - Teacher: Create Assignment
    // InsertAssignmentDTO uses 'maxPoints' (via CodingKey mapped to 'max_points')
    func createAssignment(courseId: UUID, title: String, instructions: String, dueDate: Date, points: Int) async throws {
        guard let user = currentUser else { return }

        // Input validation
        let sanitizedTitle = InputValidator.sanitizeText(title)
        let titleResult = InputValidator.validateAssignmentTitle(sanitizedTitle)
        guard titleResult.valid else {
            dataError = titleResult.message
            throw ValidationError.invalidInput(titleResult.message)
        }
        guard InputValidator.validatePoints(points) else {
            dataError = "Points must be between 0 and 1000."
            throw ValidationError.invalidInput("Points must be between 0 and 1000.")
        }
        let dueDateResult = InputValidator.validateDueDate(dueDate)
        guard dueDateResult.valid else {
            dataError = dueDateResult.message
            throw ValidationError.invalidInput(dueDateResult.message)
        }
        let sanitizedInstructions = InputValidator.sanitizeHTML(InputValidator.sanitizeText(instructions))

        let xpReward = points / 2

        if !isDemoMode {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                tenantId: nil,
                courseId: courseId,
                title: sanitizedTitle,
                description: nil,
                instructions: sanitizedInstructions,
                type: nil,
                createdBy: user.id,
                dueDate: formatter.string(from: dueDate),
                availableDate: nil,
                maxPoints: points,
                submissionType: nil,
                allowLateSubmission: nil,
                lateSubmissionDays: nil,
                status: nil
            )
            try await dataService.createAssignment(dto)
            let courseIds = courses.map(\.id)
            assignments = try await dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)

            // Audit: record assignment creation
            await auditLog.log(
                AuditAction.create,
                entityType: AuditEntityType.assignment,
                entityId: courseId.uuidString,
                details: ["title": title, "course_id": courseId.uuidString, "points": "\(points)"]
            )
        } else {
            let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"
            let newAssignment = Assignment(
                id: UUID(), title: sanitizedTitle, courseId: courseId, courseName: courseName,
                instructions: sanitizedInstructions, dueDate: dueDate, points: points,
                isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: xpReward,
                studentId: nil, studentName: nil
            )
            assignments.append(newAssignment)
        }
    }

    // MARK: - Create Announcement
    // InsertAnnouncementDTO uses 'createdBy' (not 'authorId'), and no 'isPinned' field
    func createAnnouncement(title: String, content: String, isPinned: Bool) async throws {
        guard let user = currentUser else { return }

        if !isDemoMode {
            let dto = InsertAnnouncementDTO(
                tenantId: nil,
                courseId: nil,
                title: title,
                content: content,
                createdBy: user.id,
                publishedAt: nil,
                expiresAt: nil,
                status: isPinned ? "pinned" : nil
            )
            try await dataService.createAnnouncement(dto)
            announcements = try await dataService.fetchAnnouncements()
        } else {
            let newAnnouncement = Announcement(
                id: UUID(), title: title, content: content,
                authorName: user.fullName, date: Date(), isPinned: isPinned
            )
            announcements.insert(newAnnouncement, at: 0)
        }
    }

    // MARK: - Student Actions
    func completeLesson(_ lesson: Lesson, in course: Course) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == course.id }) else { return }
        for moduleIndex in courses[courseIndex].modules.indices {
            if let lessonIndex = courses[courseIndex].modules[moduleIndex].lessons.firstIndex(where: { $0.id == lesson.id }) {
                courses[courseIndex].modules[moduleIndex].lessons[lessonIndex].isCompleted = true

                if !isDemoMode, let user = currentUser {
                    let tenantUUID = user.schoolId.flatMap { UUID(uuidString: $0) } ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                    Task {
                        try? await dataService.completeLesson(studentId: user.id, lessonId: lesson.id, courseId: course.id, tenantId: tenantUUID)
                    }
                }
                syncProfile()
                break
            }
        }
    }

    func submitAssignment(_ assignment: Assignment, text: String) {
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        // Prevent double-submission: if already submitted locally, bail out
        guard !assignments[index].isSubmitted else { return }
        assignments[index].isSubmitted = true
        assignments[index].submission = text

        // Extract and store attachment URLs from the submission text
        let urls = Assignment.extractAttachmentURLs(from: text)
        if !urls.isEmpty {
            assignments[index].attachmentURLs = urls
        }

        if !isDemoMode, let user = currentUser {
            Task {
                try? await dataService.submitAssignment(assignmentId: assignment.id, studentId: user.id, content: text)
            }

            // Audit: record assignment submission
            Task {
                await auditLog.log(
                    AuditAction.create,
                    entityType: AuditEntityType.assignment,
                    entityId: assignment.id.uuidString,
                    details: ["action": "submit", "student_id": user.id.uuidString, "course_id": assignment.courseId.uuidString]
                )
            }
        }

        // Cancel reminders for the now-submitted assignment and refresh count
        Task {
            await dueDateReminderService.cancelReminders(for: assignment.id)
        }

        syncProfile()
    }

    func submitQuiz(_ quiz: Quiz, answers: [Int]) -> Double {
        guard let index = quizzes.firstIndex(where: { $0.id == quiz.id }) else { return 0 }
        var correct = 0
        for (i, answer) in answers.enumerated() {
            if i < quiz.questions.count && answer == quiz.questions[i].correctIndex {
                correct += 1
            }
        }
        let score = Double(correct) / Double(quiz.questions.count) * 100
        quizzes[index].isCompleted = true
        quizzes[index].score = score

        if !isDemoMode, let user = currentUser {
            Task {
                try? await dataService.submitQuizAttempt(quizId: quiz.id, studentId: user.id, score: score)
            }
        }
        syncProfile()
        return score
    }

    // MARK: - Conversations
    func createConversation(title: String, recipientNames: [String]) async throws {
        guard let user = currentUser else { return }

        if !isDemoMode {
            // Build participant list: current user + recipients
            // For now, recipients are matched by name from allUsers or treated as display names
            var participants: [(userId: UUID, userName: String)] = [
                (userId: user.id, userName: user.fullName)
            ]
            // Try to match recipient names to known profiles
            for name in recipientNames {
                if let match = allUsers.first(where: {
                    "\($0.firstName ?? "") \($0.lastName ?? "")".localizedStandardContains(name)
                }) {
                    participants.append((userId: match.id, userName: "\(match.firstName ?? "") \(match.lastName ?? "")"))
                } else {
                    // Create a placeholder participant with a generated UUID
                    participants.append((userId: UUID(), userName: name))
                }
            }

            _ = try await dataService.createConversation(
                title: title,
                participantIds: participants
            )

            // Refresh conversations to pick up the new one
            conversations = try await dataService.fetchConversations(for: user.id)
        } else {
            let newConversation = Conversation(
                id: UUID(),
                participantNames: [user.fullName] + recipientNames,
                title: title,
                lastMessage: "",
                lastMessageDate: Date(),
                unreadCount: 0,
                messages: [],
                avatarSystemName: recipientNames.count > 1 ? "person.3.fill" : "person.crop.circle.fill"
            )
            conversations.insert(newConversation, at: 0)
        }
    }

    func sendMessage(in conversationId: UUID, text: String) {
        // Input validation and sanitization
        let messageResult = InputValidator.validateMessage(text)
        guard messageResult.valid else {
            dataError = messageResult.message
            return
        }
        let sanitizedText = InputValidator.sanitizeHTML(InputValidator.sanitizeText(text))

        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let message = ChatMessage(id: UUID(), senderName: currentUser?.fullName ?? "You", content: sanitizedText, timestamp: Date(), isFromCurrentUser: true)
        let previousLastMessage = conversations[index].lastMessage
        let previousLastMessageDate = conversations[index].lastMessageDate
        conversations[index].messages.append(message)
        conversations[index].lastMessage = sanitizedText
        conversations[index].lastMessageDate = Date()

        if !isDemoMode, let user = currentUser {
            Task {
                do {
                    try await dataService.sendMessage(
                        conversationId: conversationId,
                        senderId: user.id,
                        senderName: user.fullName,
                        content: sanitizedText
                    )
                } catch {
                    // Rollback the optimistic message on failure
                    if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                        conversations[idx].messages.removeAll { $0.id == message.id }
                        conversations[idx].lastMessage = previousLastMessage
                        conversations[idx].lastMessageDate = previousLastMessageDate
                    }
                    dataError = "Failed to send message. Please try again."
                    #if DEBUG
                    print("[AppViewModel] sendMessage failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Student: Enroll by Class Code
    func enrollByClassCode(_ classCode: String) async throws -> String {
        guard let user = currentUser, user.role == .student else {
            throw EnrollmentError.invalidClassCode
        }

        let trimmedCode = classCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDemoMode {
            guard !trimmedCode.isEmpty else {
                throw EnrollmentError.invalidClassCode
            }
            let mockCourses = mockService.sampleCourses()
            if let match = mockCourses.first(where: { $0.classCode.lowercased() == trimmedCode.lowercased() }) {
                if courses.contains(where: { $0.id == match.id }) {
                    throw EnrollmentError.alreadyEnrolled
                }
                courses.append(match)
                return match.title
            }
            throw EnrollmentError.invalidClassCode
        }

        let courseName = try await dataService.enrollByClassCode(studentId: user.id, classCode: trimmedCode)
        courses = try await dataService.fetchCourses(for: user.id, role: user.role, schoolId: user.schoolId)
        let courseIds = courses.map(\.id)
        assignments = try await dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
        return courseName
    }

    // MARK: - Teacher: Grade Submission
    func gradeSubmission(assignmentId: UUID, studentId: UUID?, score: Double, letterGrade: String, feedback: String?) async throws {
        isLoading = true
        gradeError = nil
        defer { isLoading = false }

        // Input validation: score must be non-negative
        guard score >= 0 else {
            gradeError = "Score cannot be negative."
            throw ValidationError.invalidInput("Score cannot be negative.")
        }

        guard let assignment = assignments.first(where: { $0.id == assignmentId && $0.studentId == studentId }) ??
              assignments.first(where: { $0.id == assignmentId }) else {
            gradeError = "Assignment not found"
            throw NSError(domain: "AppViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Assignment not found"])
        }

        // Validate that the score does not exceed the assignment's max points
        let maxPossible = Double(assignment.points)
        guard score <= maxPossible else {
            gradeError = "Score cannot exceed the maximum points (\(assignment.points))."
            throw ValidationError.invalidInput("Score cannot exceed the maximum points (\(assignment.points)).")
        }

        // Validate the resulting percentage is within grade range
        let computedPercentage = maxPossible > 0 ? (score / maxPossible) * 100 : 0
        guard InputValidator.validateGrade(computedPercentage) else {
            gradeError = "Computed grade percentage is out of range (0-200)."
            throw ValidationError.invalidInput("Computed grade percentage is out of range.")
        }

        // Use the studentId passed in, then fall back to the assignment's studentId, then currentUser as last resort
        let resolvedStudentId = studentId ?? assignment.studentId ?? currentUser?.id ?? UUID()

        let maxScore = Double(assignment.points)
        let percentage = maxScore > 0 ? (score / maxScore) * 100 : 0

        if isDemoMode {
            if let index = assignments.firstIndex(where: { $0.id == assignmentId && $0.studentId == studentId }) ??
               assignments.firstIndex(where: { $0.id == assignmentId }) {
                assignments[index].grade = percentage
                assignments[index].feedback = feedback
            }
            return
        }

        do {
            try await dataService.gradeSubmission(
                studentId: resolvedStudentId,
                courseId: assignment.courseId,
                assignmentId: assignmentId,
                score: score,
                maxScore: maxScore,
                letterGrade: letterGrade,
                feedback: feedback ?? ""
            )
            refreshData()

            // Audit: record grade change (FERPA compliance — grade changes must be tracked)
            await auditLog.log(
                AuditAction.gradeChange,
                entityType: AuditEntityType.grade,
                entityId: assignmentId.uuidString,
                details: [
                    "student_id": resolvedStudentId.uuidString,
                    "score": "\(score)",
                    "max_score": "\(maxScore)",
                    "letter_grade": letterGrade,
                    "graded_by": currentUser?.id.uuidString ?? "unknown"
                ]
            )
        } catch {
            gradeError = "Failed to grade submission: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Teacher: Create Quiz
    func createQuiz(courseId: UUID, title: String, questions: [QuizQuestion], timeLimit: Int, dueDate: Date, xpReward: Int) async throws {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            let newQuiz = Quiz(
                id: UUID(),
                title: title,
                courseId: courseId,
                courseName: courses.first(where: { $0.id == courseId })?.title ?? "Unknown",
                questions: questions,
                timeLimit: timeLimit,
                dueDate: dueDate,
                isCompleted: false,
                score: nil,
                xpReward: xpReward
            )
            quizzes.append(newQuiz)
            return
        }

        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dueDateString = formatter.string(from: dueDate)

            let quizDTO = try await dataService.createQuiz(
                courseId: courseId,
                title: title,
                timeLimit: timeLimit,
                dueDate: dueDateString,
                xpReward: xpReward
            )

            // Create each question for the quiz
            for question in questions {
                try await dataService.createQuizQuestion(
                    quizId: quizDTO.id,
                    text: question.text,
                    options: question.options,
                    correctIndex: question.correctIndex
                )
            }

            refreshData()
        } catch {
            dataError = "Failed to create quiz: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Teacher: Create Lesson
    func createLesson(courseId: UUID, moduleId: UUID, title: String, content: String, duration: Int, type: LessonType, xpReward: Int) async throws {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            for courseIndex in courses.indices {
                if let modIndex = courses[courseIndex].modules.firstIndex(where: { $0.id == moduleId }) {
                    let newLesson = Lesson(
                        id: UUID(),
                        title: title,
                        content: content,
                        duration: duration,
                        isCompleted: false,
                        type: type,
                        xpReward: xpReward
                    )
                    courses[courseIndex].modules[modIndex].lessons.append(newLesson)
                    return
                }
            }
            return
        }

        do {
            let orderIndex = courses.first(where: { $0.id == courseId })?
                .modules.first(where: { $0.id == moduleId })?
                .lessons.count ?? 0
            _ = try await dataService.createLesson(
                moduleId: moduleId,
                title: title,
                content: content,
                duration: duration,
                type: type.rawValue,
                xpReward: xpReward,
                orderIndex: orderIndex
            )
            refreshData()
        } catch {
            dataError = "Failed to create lesson: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Teacher: Create Module
    func createModule(courseId: UUID, title: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let orderIndex = courses.first(where: { $0.id == courseId })?.modules.count ?? 0

        if isDemoMode {
            if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
                let newModule = Module(
                    id: UUID(),
                    title: title,
                    lessons: [],
                    orderIndex: orderIndex
                )
                courses[courseIndex].modules.append(newModule)
            }
            return
        }

        do {
            _ = try await dataService.createModule(
                courseId: courseId,
                title: title,
                orderIndex: orderIndex
            )
            refreshData()
        } catch {
            dataError = "Failed to create module: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Teacher: Take Attendance
    func takeAttendance(records: [(studentId: UUID, courseId: UUID, courseName: String, date: String, status: String)]) async {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            for record in records {
                let newRecord = AttendanceRecord(
                    id: UUID(),
                    date: ISO8601DateFormatter().date(from: record.date) ?? Date(),
                    status: AttendanceStatus(rawValue: record.status) ?? .present,
                    courseName: record.courseName,
                    studentName: nil
                )
                attendance.append(newRecord)
            }
            return
        }

        do {
            try await dataService.takeAttendance(records: records)
            refreshData()
        } catch {
            dataError = "Failed to record attendance: \(error.localizedDescription)"
        }
    }

    // MARK: - Conversations: Create with Participant IDs
    func createConversation(title: String, participantIds: [(userId: UUID, userName: String)]) async {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            let names = participantIds.map(\.userName)
            let newConversation = Conversation(
                id: UUID(),
                participantNames: names,
                title: title,
                lastMessage: "",
                lastMessageDate: Date(),
                unreadCount: 0,
                messages: [],
                avatarSystemName: names.count > 2 ? "person.3.fill" : "person.crop.circle.fill"
            )
            conversations.insert(newConversation, at: 0)
            return
        }

        do {
            _ = try await dataService.createConversation(
                title: title,
                participantIds: participantIds
            )
            if let user = currentUser {
                conversations = try await dataService.fetchConversations(for: user.id)
            }
        } catch {
            dataError = "Failed to create conversation: \(error.localizedDescription)"
        }
    }

    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await dataService.resetPassword(email: email)
        } catch {
            throw error
        }
    }

    // MARK: - Delete Announcement
    func deleteAnnouncement(_ id: UUID) async {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            announcements.removeAll { $0.id == id }
            return
        }

        do {
            try await dataService.deleteAnnouncement(announcementId: id)
            announcements.removeAll { $0.id == id }
        } catch {
            dataError = "Failed to delete announcement: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Students in Course
    func fetchStudentsInCourse(_ courseId: UUID) async -> [User] {
        isLoading = true
        defer { isLoading = false }

        if isDemoMode {
            // Return some mock student users in demo mode
            return []
        }

        do {
            let profileDTOs = try await dataService.fetchStudentsInCourse(courseId: courseId)
            return profileDTOs.map { $0.toUser() }
        } catch {
            dataError = "Failed to fetch students: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Course Management
    func updateCourseDetails(courseId: UUID, title: String, description: String, colorName: String, iconSystemName: String) async throws {
        if !isDemoMode {
            try await dataService.updateCourse(courseId: courseId, title: title, description: description, colorName: colorName, iconSystemName: iconSystemName)
        }
        if let index = courses.firstIndex(where: { $0.id == courseId }) {
            courses[index].title = title
            courses[index].description = description
            courses[index].colorName = colorName
            courses[index].iconSystemName = iconSystemName
        }
    }

    func deleteCourseAndClean(courseId: UUID) async throws {
        if !isDemoMode {
            try await dataService.deleteCourse(courseId: courseId)
        }
        courses.removeAll { $0.id == courseId }
        assignments.removeAll { $0.courseId == courseId }
    }

    func deleteModule(courseId: UUID, moduleId: UUID) async throws {
        if !isDemoMode {
            try await dataService.deleteModule(moduleId: moduleId)
        }
        if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
            courses[courseIndex].modules.removeAll { $0.id == moduleId }
        }
    }

    func deleteLesson(courseId: UUID, moduleId: UUID, lessonId: UUID) async throws {
        if !isDemoMode {
            try await dataService.deleteLesson(lessonId: lessonId)
        }
        if let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
           let moduleIndex = courses[courseIndex].modules.firstIndex(where: { $0.id == moduleId }) {
            courses[courseIndex].modules[moduleIndex].lessons.removeAll { $0.id == lessonId }
        }
    }

    func updateAssignmentDetails(assignmentId: UUID, title: String?, instructions: String?, dueDate: Date?, points: Int?) async throws {
        if !isDemoMode {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dueDateString = dueDate.map { formatter.string(from: $0) }
            try await dataService.updateAssignment(assignmentId: assignmentId, title: title, instructions: instructions, dueDate: dueDateString, points: points)
        }
        for index in assignments.indices where assignments[index].id == assignmentId {
            if let title { assignments[index].title = title }
            if let instructions { assignments[index].instructions = instructions }
            if let dueDate { assignments[index].dueDate = dueDate }
            if let points { assignments[index].points = points }
        }
    }

    func deleteAssignmentAndClean(assignmentId: UUID) async throws {
        if !isDemoMode {
            try await dataService.deleteAssignment(assignmentId: assignmentId)
        }
        assignments.removeAll { $0.id == assignmentId }
    }

    func unenrollStudent(studentId: UUID, courseId: UUID) async throws {
        if !isDemoMode {
            try await dataService.unenrollStudent(studentId: studentId, courseId: courseId)
        }
        if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
            courses[courseIndex].enrolledStudentCount = max(0, courses[courseIndex].enrolledStudentCount - 1)
        }
    }

    // MARK: - Attendance + Parent
    // Uses attendance_records table (not "attendance") and attendance_date column (not "date")
    func fetchAttendanceForCourse(courseId: UUID) async -> [AttendanceRecord] {
        if isDemoMode {
            return attendance.filter { record in
                courses.first(where: { $0.title == record.courseName })?.id == courseId
            }
        }
        do {
            let dtos: [AttendanceDTO] = try await supabaseClient
                .from("attendance_records")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .order("attendance_date", ascending: false)
                .execute()
                .value

            // attendance_date is a plain "yyyy-MM-dd" string, not ISO8601
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            dateFmt.timeZone = TimeZone(identifier: "UTC")

            // Look up course name from loaded courses since AttendanceDTO has no courseName column
            let resolvedCourseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"

            return dtos.map { dto in
                AttendanceRecord(
                    id: dto.id,
                    date: dateFmt.date(from: dto.date ?? "") ?? Date(),
                    status: AttendanceStatus(rawValue: dto.status) ?? .present,
                    courseName: resolvedCourseName,
                    studentName: nil
                )
            }
        } catch {
            return []
        }
    }

    // Role is not on profiles; need to use tenant_memberships to filter teachers
    func fetchTeachersForChild(childId: UUID) async -> [ProfileDTO] {
        if isDemoMode {
            // In demo mode, return empty since ProfileDTO has no role property
            return []
        }
        do {
            // Fetch teacher user IDs from tenant_memberships
            let memberships: [TenantMembershipDTO] = try await supabaseClient
                .from("tenant_memberships")
                .select()
                .eq("role", value: "Teacher")
                .execute()
                .value
            let teacherIds = memberships.map(\.userId)
            if teacherIds.isEmpty { return [] }

            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: teacherIds.map(\.uuidString))
                .execute()
                .value
            return profiles
        } catch {
            return []
        }
    }

    // MARK: - Parent Alerts & Notifications

    /// Scans every linked child for low grades, absences today, and upcoming due
    /// dates within 24 hours, then populates `parentAlerts` and fires local
    /// notifications for each new alert.
    func scheduleParentAlerts() {
        guard currentUser?.role == .parent else { return }

        var alerts: [ParentAlert] = []
        let now = Date()
        let calendar = Calendar.current

        for child in children {
            // 1. Low grades (< 70%)
            for course in child.courses where course.numericGrade < 70 {
                alerts.append(ParentAlert(
                    type: .lowGrade,
                    childId: child.id,
                    childName: child.name,
                    title: "Low Grade: \(course.courseName)",
                    message: "\(child.name) has a \(String(format: "%.0f", course.numericGrade))% in \(course.courseName).",
                    courseName: course.courseName
                ))
            }

            // 2. Attendance alert -- flag children whose rate is at or below 90 %
            if child.attendanceRate <= 0.90 {
                alerts.append(ParentAlert(
                    type: .absence,
                    childId: child.id,
                    childName: child.name,
                    title: "Attendance Alert",
                    message: "\(child.name)'s attendance rate is \(Int(child.attendanceRate * 100))%. Please contact the school if needed.",
                    courseName: "General"
                ))
            }

            // 3. Due dates within 24 hours
            for assignment in child.recentAssignments {
                guard !assignment.isSubmitted,
                      assignment.dueDate > now,
                      let dayAhead = calendar.date(byAdding: .hour, value: 24, to: now),
                      assignment.dueDate <= dayAhead else { continue }

                alerts.append(ParentAlert(
                    type: .upcomingDueDate,
                    childId: child.id,
                    childName: child.name,
                    title: "Due Soon: \(assignment.title)",
                    message: "\(assignment.title) for \(assignment.courseName) is due \(assignment.dueDate.formatted(.relative(presentation: .named))).",
                    courseName: assignment.courseName
                ))
            }
        }

        parentAlerts = alerts

        // Schedule a local notification for each unread alert
        Task.detached(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            for alert in alerts where !alert.isRead {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.message
                content.sound = .default
                content.categoryIdentifier = "PARENT_ALERT"
                content.userInfo = [
                    "type": alert.type.rawValue,
                    "childId": alert.childId.uuidString,
                    "alertId": alert.id.uuidString
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let identifier = "parent-alert-\(alert.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    #if DEBUG
                    print("[AppViewModel] Failed to schedule parent alert notification: \(error)")
                    #endif
                }
            }
        }
    }

    /// Mark a single parent alert as read.
    func markParentAlertRead(_ alertId: UUID) {
        guard let index = parentAlerts.firstIndex(where: { $0.id == alertId }) else { return }
        parentAlerts[index].isRead = true
    }

    /// Mark all parent alerts as read.
    func markAllParentAlertsRead() {
        for index in parentAlerts.indices {
            parentAlerts[index].isRead = true
        }
    }

    // MARK: - Profile Editing
    func updateProfileDetails(firstName: String, lastName: String, avatar: String) async throws {
        guard let user = currentUser else { return }

        if !isDemoMode {
            let dto = UpdateProfileDetailsDTO(firstName: firstName, lastName: lastName, avatarUrl: avatar)
            try await supabaseClient
                .from("profiles")
                .update(dto)
                .eq("id", value: user.id.uuidString)
                .execute()
        }
        currentUser?.firstName = firstName
        currentUser?.lastName = lastName
        currentUser?.avatarSystemName = avatar
    }

    // MARK: - Biometric Lock / Unlock

    func enableBiometric() {
        biometricService.checkBiometricAvailability()
        guard biometricService.isBiometricAvailable else { return }
        biometricEnabled = true
    }

    func disableBiometric() {
        biometricEnabled = false
        isAppLocked = false
    }

    func lockApp() {
        guard biometricEnabled, isAuthenticated else { return }
        isAppLocked = true
        biometricService.isUnlocked = false
    }

    func unlockApp() {
        isAppLocked = false
        biometricService.isUnlocked = true
    }

    func unlockWithBiometric() {
        Task {
            do {
                let success = try await biometricService.authenticate()
                if success {
                    unlockApp()
                }
            } catch {
                #if DEBUG
                print("[AppViewModel] Biometric unlock failed: \(error)")
                #endif
            }
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") || message.contains("invalid_credentials") {
            return "Invalid email or password"
        } else if message.contains("email not confirmed") {
            return "Please confirm your email before signing in"
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection"
        }
        return "Sign in failed. Please try again."
    }
}

nonisolated enum ValidationError: LocalizedError, Sendable {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message): message
        }
    }
}

nonisolated enum UserManagementError: LocalizedError, Sendable {
    case unauthorized
    case noSlotsRemaining
    case cannotDeleteSelf

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Only admins can manage users."
        case .noSlotsRemaining: "You have used all available user slots. Upgrade your plan to add more users."
        case .cannotDeleteSelf: "You cannot delete your own account."
        }
    }
}
