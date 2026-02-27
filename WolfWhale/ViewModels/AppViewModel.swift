import SwiftUI
import Supabase
import UserNotifications
import os

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

    // MARK: - Login Rate Limiting
    private var loginAttemptCount = 0
    private var loginLockoutUntil: Date?
    private let maxLoginAttempts = 5
    var isLoginLockedOut: Bool {
        guard let lockoutUntil = loginLockoutUntil else { return false }
        if Date() >= lockoutUntil {
            loginLockoutUntil = nil
            loginAttemptCount = 0
            return false
        }
        return true
    }
    var loginLockoutRemainingSeconds: Int {
        guard let lockoutUntil = loginLockoutUntil else { return 0 }
        return max(0, Int(lockoutUntil.timeIntervalSinceNow.rounded(.up)))
    }

    var courses: [Course] = []
    var assignments: [Assignment] = []
    var quizzes: [Quiz] = []
    var grades: [GradeEntry] = []
    var attendance: [AttendanceRecord] = []
    var achievements: [Achievement] = []
    // leaderboard removed (XP system disabled)
    var conversations: [Conversation] = []
    var announcements: [Announcement] = []
    var children: [ChildInfo] = []
    var parentAlerts: [ParentAlert] = []
    var schoolMetrics: SchoolMetrics?
    var allUsers: [ProfileDTO] = []
    var rubrics: [Rubric] = []
    var courseSchedules: [CourseSchedule] = []
    var discussionThreads: [DiscussionThread] = []
    var discussionReplies: [DiscussionReply] = []
    var dataError: String?
    var gradeError: String?
    var enrollmentError: String?
    var enrollmentRequests: [EnrollmentRequest] = []
    var allAvailableCourses: [Course] = []

    // MARK: - Conference Scheduling
    var conferences: [Conference] = []
    var teacherAvailableSlots: [TeacherAvailableSlot] = []

    // MARK: - Absence Alert Toggle
    var absenceAlertEnabled: Bool = true

    // MARK: - Badges (XP system removed)
    var badges: [Badge] = []

    // MARK: - Pagination State
    var coursePagination = PaginationState(pageSize: 50)
    var assignmentPagination = PaginationState(pageSize: 50)
    var conversationPagination = PaginationState(pageSize: 50)
    var userPagination = PaginationState(pageSize: 30)

    // MARK: - Lazy Loading Flags
    private var assignmentsLoaded = false
    private var conversationsLoaded = false
    private var gradesLoaded = false
    // leaderboard removed (XP system)
    private var quizzesLoaded = false
    private var attendanceLoaded = false
    private var achievementsLoaded = false

    /// Resets lazy loading flags so data will be re-fetched on next access.
    /// Called periodically by auto-refresh to prevent stale data.
    private func resetLazyLoadingFlags() {
        assignmentsLoaded = false
        conversationsLoaded = false
        gradesLoaded = false
        quizzesLoaded = false
        attendanceLoaded = false
        achievementsLoaded = false
    }

    // MARK: - Cached Derived Data
    /// Cached at-risk students to avoid O(C×A×S) recomputation on every view render.
    var cachedAtRiskStudents: [AtRiskStudent] = []

    /// Cached weighted grade results for every course.
    /// Updated by `refreshDerivedProperties()` instead of recomputing on every access.
    var cachedCourseGradeResults: [CourseGradeResult] = []

    // MARK: - Search Debouncing
    private var searchTask: Task<Void, Never>?

    var isDemoMode = false
    private let mockService = MockDataService.shared
    let dataService = DataService.shared
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    /// Auto-refresh interval in seconds (5 minutes).
    private let autoRefreshInterval: TimeInterval = 300
    let networkMonitor = NetworkMonitor()

    // MARK: - Task Management
    /// Tracks in-flight async tasks by key so they can be cancelled on logout
    /// or when a newer request supersedes the previous one.
    private var activeTasks: [String: Task<Void, Never>] = [:]

    /// Cancels all tracked active tasks. Called during logout/cleanup
    /// to prevent stale network responses from writing to cleared state.
    func cancelAllTasks() {
        searchTask?.cancel()
        searchTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    // MARK: - Logging
    /// Centralized logger that works in both debug and release builds.
    /// In release, only errors are logged (via os.Logger). In debug, all levels print.
    private func log(_ message: String, level: LogLevel = .info) {
        #if DEBUG
        print("[AppViewModel] \(message)")
        #else
        if level == .error {
            // In production, use os.Logger for error tracking
            os_log(.error, "[AppViewModel] %{public}@", message)
        }
        #endif
    }

    private enum LogLevel { case info, error }

    // MARK: - Session Expiry Detection

    /// Checks if an error indicates an expired/invalid session and logs the user out if so.
    private func handlePotentialAuthError(_ error: Error) {
        let errorString = String(describing: error)
        if errorString.contains("401") || errorString.contains("JWT") || errorString.contains("token") || errorString.contains("session_not_found") {
            log("Session expired — logging out", level: .error)
            logout()
            loginError = "Your session has expired. Please sign in again."
        }
    }

    // MARK: - Audit Logging (FERPA/GDPR Compliance)
    private let auditLog = AuditLogService()

    // MARK: - Grade Calculation (Weighted)
    var gradeService = GradeCalculationService()

    /// Weighted grade results for every course the student is enrolled in.
    /// Returns the cached value populated by `refreshDerivedProperties()`.
    /// Call `computeCourseGradeResults()` directly only when you need a fresh snapshot.
    var courseGradeResults: [CourseGradeResult] {
        cachedCourseGradeResults
    }

    /// Recomputes weighted grade results from scratch. O(n) grouping pass.
    /// The result is stored in `cachedCourseGradeResults` by `refreshDerivedProperties()`.
    func computeCourseGradeResults() -> [CourseGradeResult] {
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

    /// Tracks whether a Supabase session has been saved (for Face ID re-login on next launch).
    var hasSavedSession: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSavedSession) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.hasSavedSession) }
    }

    /// When true, the UI should show a biometric prompt instead of the login form.
    var showBiometricPrompt: Bool = false

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
    var offlineModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_offline_mode_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "wolfwhale_offline_mode_enabled")
            if newValue { saveDataToOfflineStorage() }
        }
    }
    var isSyncingOffline = false
    var offlineStorage = OfflineStorageService()
    // Conflict resolution for offline sync (server-wins strategy)
    private var _conflictResolution: ConflictResolutionService?
    var conflictResolution: ConflictResolutionService {
        if let existing = _conflictResolution { return existing }
        let service = ConflictResolutionService()
        service.configure(offlineStorage: offlineStorage, networkMonitor: networkMonitor)
        _conflictResolution = service
        return service
    }
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

    // MARK: - Feature Sub-ViewModels
    // These sub-ViewModels hold domain-specific state and logic.
    // AppViewModel creates them lazily and delegates to them.
    // Views can access them via appViewModel.gradesVM, appViewModel.discussionsVM, etc.

    private var _gradesVM: GradesViewModel?
    /// Grade-related state and logic: weighted calculations, grade curves, CSV export, late penalties, etc.
    var gradesVM: GradesViewModel {
        if let existing = _gradesVM { return existing }
        let vm = GradesViewModel()
        _gradesVM = vm
        return vm
    }

    private var _discussionsVM: DiscussionViewModel?
    /// Discussion forum state and logic: threads, replies, pinning.
    var discussionsVM: DiscussionViewModel {
        if let existing = _discussionsVM { return existing }
        let vm = DiscussionViewModel()
        _discussionsVM = vm
        return vm
    }

    private var _peerReviewVM: PeerReviewViewModel?
    /// Peer review state and logic: assigning reviewers, submitting reviews, templates.
    var peerReviewVM: PeerReviewViewModel {
        if let existing = _peerReviewVM { return existing }
        let vm = PeerReviewViewModel()
        _peerReviewVM = vm
        return vm
    }

    private var _parentFeaturesVM: ParentFeaturesViewModel?
    /// Parent-specific state and logic: children, alerts, conferences.
    var parentFeaturesVM: ParentFeaturesViewModel {
        if let existing = _parentFeaturesVM { return existing }
        let vm = ParentFeaturesViewModel()
        _parentFeaturesVM = vm
        return vm
    }

    private var _academicCalendarVM: AcademicCalendarViewModel?
    /// Academic calendar state and logic: terms, events, grading periods, report cards.
    var academicCalendarVM: AcademicCalendarViewModel {
        if let existing = _academicCalendarVM { return existing }
        let vm = AcademicCalendarViewModel()
        _academicCalendarVM = vm
        return vm
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
    /// Recomputes `cachedCourseGradeResults` so that `gpa`, `weightedAveragePercent`,
    /// and `overallLetterGrade` all reflect the new weights immediately.
    func invalidateGradeCalculations() {
        cachedCourseGradeResults = computeCourseGradeResults()
    }

    private(set) var upcomingAssignments: [Assignment] = []
    private(set) var overdueAssignments: [Assignment] = []
    private(set) var totalUnreadMessages: Int = 0
    private(set) var pendingGradingCount: Int = 0

    /// Recomputes cached derived properties. Call after assignments, conversations, or grades change.
    /// Uses a single pass over `assignments` instead of 4 separate filter passes.
    func refreshDerivedProperties() {
        // Single-pass over assignments: bucket into upcoming, overdue, and pending-grading
        var upcoming: [Assignment] = []
        var overdue: [Assignment] = []
        var pendingGrading = 0

        for assignment in assignments {
            if assignment.isOverdue {
                overdue.append(assignment)
            } else if !assignment.isSubmitted {
                upcoming.append(assignment)
            }
            if assignment.isSubmitted && assignment.grade == nil {
                pendingGrading += 1
            }
        }

        upcomingAssignments = upcoming.sorted { $0.dueDate < $1.dueDate }
        overdueAssignments = overdue
        pendingGradingCount = pendingGrading
        totalUnreadMessages = conversations.reduce(0) { $0 + $1.unreadCount }

        // Refresh cached grade computations so gpa/weightedAveragePercent stay current
        cachedCourseGradeResults = computeCourseGradeResults()
    }

    var pendingEnrollmentCount: Int {
        enrollmentRequests.filter { $0.status == .pending }.count
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

            // If a previous session was saved and biometrics are available,
            // require Face ID / Touch ID before restoring the session.
            if hasSavedSession && biometricService.isBiometricAvailable {
                showBiometricPrompt = true
                return
            }

            do {
                // Add a timeout so the app doesn't hang on a black screen
                let session = try await withThrowingTaskGroup(of: Session.self) { group in
                    group.addTask {
                        try await supabaseClient.auth.session
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                        throw CancellationError()
                    }
                    guard let result = try await group.next() else {
                        throw URLError(.timedOut)
                    }
                    group.cancelAll()
                    return result
                }
                try await fetchProfile(userId: session.user.id)

                // Cache role/tenant in PostgreSQL session vars for faster RLS checks
                try? await supabaseClient.rpc("set_user_session_vars").execute()

                await loadData()
                isAuthenticated = true
                startAutoRefresh()
                startNetworkObserver()

                // Re-register push token on session restore
                pushService.registerForRemoteNotifications()
                await pushService.sendTokenToServer(userId: session.user.id)
            } catch {
                // Session is gone or expired — clear saved session flag
                hasSavedSession = false
                #if DEBUG
                print("[AppViewModel] Session check failed: \(error)")
                #endif
            }
        }
    }

    /// Authenticates with Face ID / Touch ID and restores the cached Supabase session.
    /// On failure, hides the biometric prompt so the normal login form is shown.
    func authenticateWithBiometric() {
        Task {
            do {
                try await biometricService.authenticate()

                // Biometric success — restore the Supabase session
                let session = try await withThrowingTaskGroup(of: Session.self) { group in
                    group.addTask {
                        try await supabaseClient.auth.session
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                        throw CancellationError()
                    }
                    guard let result = try await group.next() else {
                        throw URLError(.timedOut)
                    }
                    group.cancelAll()
                    return result
                }
                try await fetchProfile(userId: session.user.id)

                // Cache role/tenant in PostgreSQL session vars for faster RLS checks
                try? await supabaseClient.rpc("set_user_session_vars").execute()

                await loadData()
                isAuthenticated = true
                showBiometricPrompt = false
                startAutoRefresh()
                startNetworkObserver()

                // Re-register push token on session restore
                pushService.registerForRemoteNotifications()
                await pushService.sendTokenToServer(userId: session.user.id)
            } catch {
                // Biometric failed or session expired — fall back to login form
                showBiometricPrompt = false
                hasSavedSession = false
                #if DEBUG
                print("[AppViewModel] Biometric auth failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Authentication

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Please enter your email and password"
            return
        }

        // Rate limiting: block login if locked out
        if isLoginLockedOut {
            loginError = "Too many failed attempts. Try again in \(loginLockoutRemainingSeconds)s."
            return
        }

        isLoading = true
        loginError = nil

        Task {
            do {
                try await supabaseClient.auth.signIn(email: email, password: password)
                let session = try await supabaseClient.auth.session
                try await fetchProfile(userId: session.user.id)

                // Cache role/tenant in PostgreSQL session vars for faster RLS checks
                try? await supabaseClient.rpc("set_user_session_vars").execute()

                await loadData()
                isAuthenticated = true
                startAutoRefresh()
                startNetworkObserver()

                // Save session flag so Face ID auto-login works on next launch
                hasSavedSession = true

                // Register device for remote push notifications
                pushService.registerForRemoteNotifications()
                await pushService.sendTokenToServer(userId: session.user.id)

                // Audit: record successful login
                auditLog.setUser(session.user.id)
                await auditLog.log(AuditAction.login, entityType: AuditEntityType.user, entityId: session.user.id.uuidString)

                // Reset rate limiting on success
                loginAttemptCount = 0
                loginLockoutUntil = nil

                // Clear password from memory after successful login
                password = ""
            } catch {
                loginError = mapAuthError(error)
                password = ""

                // Track failed attempts and apply exponential lockout
                loginAttemptCount += 1
                if loginAttemptCount >= maxLoginAttempts {
                    let lockoutSeconds = min(30 * pow(2.0, Double(loginAttemptCount - maxLoginAttempts)), 300)
                    loginLockoutUntil = Date().addingTimeInterval(lockoutSeconds)
                    loginError = "Too many failed attempts. Try again in \(Int(lockoutSeconds))s."
                }
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
                "role": .string(role.rawValue.lowercased())
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
            role: role.rawValue.lowercased(),
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

    // MARK: - Cleanup

    func logout() {
        // Audit: record logout before clearing state
        if !isDemoMode {
            Task { await auditLog.log(AuditAction.logout, entityType: AuditEntityType.user, entityId: currentUser?.id.uuidString) }
            Task { await auditLog.clearUser() }
        }

        // 1. Cancel any pending background refresh and all active data tasks to prevent network storms
        refreshTask?.cancel()
        refreshTask = nil
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        cancelAllTasks()

        if !isDemoMode {
            Task {
                // Remove push token from server before signing out
                if let userId = currentUser?.id {
                    await pushService.removeTokenFromServer(userId: userId)
                }
                pushService.clearAllNotifications()
                do {
                    try await supabaseClient.auth.signOut()
                } catch {
                    self.log("Sign out error: \(error)", level: .error)
                    // Still clear local state even on sign-out error
                }
            }
        }

        // Always invalidate cache, even in demo mode, to prevent data leakage
        Task { await CacheService.shared.invalidateAll() }

        // 2. Stop radio playback so audio doesn't persist after logout
        RadioService.shared.stop()

        // 3. Clear offline storage and user scope
        offlineStorage.clearAllData()
        offlineStorage.clearCurrentUser()

        // 4. Clear Siri / App Intents cached data from both standard and App Group UserDefaults
        //    so the next user doesn't see stale grades, assignments, or schedule
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.upcomingAssignments)
        defaults.removeObject(forKey: UserDefaultsKeys.gradesSummary)
        defaults.removeObject(forKey: UserDefaultsKeys.scheduleToday)

        // FERPA: Clear wellness/health data so the next user doesn't see previous user's data
        defaults.removeObject(forKey: UserDefaultsKeys.hydrationGlasses)
        defaults.removeObject(forKey: UserDefaultsKeys.hydrationDate)

        // Clear any residual audit log entries queued in UserDefaults (already flushed above,
        // but wipe the local queue to prevent data leakage if flush failed)
        defaults.removeObject(forKey: UserDefaultsKeys.auditLogOfflineQueue)

        // Clear Spotlight index counter
        defaults.removeObject(forKey: UserDefaultsKeys.spotlightIndexedCount)

        // FERPA: Also clear from App Group suite and revoke auth flag
        if let sharedDefaults = UserDefaults(suiteName: UserDefaultsKeys.widgetAppGroup) {
            sharedDefaults.set(false, forKey: "wolfwhale_is_authenticated")
            sharedDefaults.removeObject(forKey: UserDefaultsKeys.upcomingAssignments)
            sharedDefaults.removeObject(forKey: UserDefaultsKeys.gradesSummary)
            sharedDefaults.removeObject(forKey: UserDefaultsKeys.scheduleToday)
        }

        // 5. Remove all pending local notification reminders for the previous user
        //    and clear any deep-link state so they don't carry over
        notificationService.cancelAllNotifications()
        notificationService.clearDeepLinks()

        // 5a. Cancel all due-date reminders managed by the integration service
        Task { await dueDateReminderService.cancelAllReminders() }

        // 6. Reset biometric lock state, saved session flag, and deep-link navigation so the next login starts clean
        isAppLocked = false
        hasSavedSession = false
        showBiometricPrompt = false
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
        _conflictResolution = nil
        _speechService = nil
        _recommendationService = nil
        _healthService = nil
        _documentScannerService = nil
        _drawingService = nil
        #if canImport(GroupActivities)
        _sharePlayService = nil
        #endif

        // 7a. Clear feature sub-ViewModels so they are re-created fresh for the next user
        _gradesVM = nil
        _discussionsVM = nil
        _peerReviewVM = nil
        _parentFeaturesVM = nil
        _academicCalendarVM = nil

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
        conversations = []
        announcements = []
        children = []
        parentAlerts = []
        conferences = []
        teacherAvailableSlots = []
        schoolMetrics = nil
        allUsers = []
        discussionThreads = []
        discussionReplies = []
        dataError = nil
        gradeError = nil
        submissionError = nil
        enrollmentError = nil
        enrollmentRequests = []
        loginError = nil
        isDataLoading = false
    }

    // MARK: - Auth Wrappers (used by Views instead of touching supabaseClient directly)

    /// Re-authenticates the user by signing in with the given credentials.
    /// Used by BiometricLockView and DeleteAccountView for password fallback / re-auth.
    func reAuthenticate(email: String, password: String) async throws {
        _ = try await supabaseClient.auth.signIn(email: email, password: password)
    }

    /// Changes the user's password after verifying the current one.
    /// Used by ChangePasswordView instead of calling supabaseClient directly.
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let session = try await supabaseClient.auth.session
        guard let email = session.user.email else {
            throw NSError(domain: "AppViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to determine your email address."])
        }
        // Verify current password
        _ = try await supabaseClient.auth.signIn(email: email, password: currentPassword)
        // Update to new password
        try await supabaseClient.auth.update(user: .init(password: newPassword))
    }

    /// Signs up a new user, creates their profile and tenant membership.
    /// Used by SignUpView instead of calling supabaseClient directly.
    func signUpNewUser(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        tenantCode: String
    ) async throws -> UUID {
        // Look up tenant by invite code
        struct TenantLookup: Decodable { let id: UUID }
        let tenantResponse: [TenantLookup] = try await supabaseClient
            .from("tenants")
            .select("id")
            .eq("invite_code", value: tenantCode)
            .limit(1)
            .execute()
            .value

        guard let tenant = tenantResponse.first else {
            throw NSError(domain: "AppViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid school code. Please check with your administrator."])
        }

        let result = try await supabaseClient.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName),
                "role": .string(role.rawValue)
            ]
        )

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

        let membership = InsertTenantMembershipDTO(
            userId: result.user.id,
            tenantId: tenant.id,
            role: role.rawValue,
            status: "active",
            joinedAt: ISO8601DateFormatter().string(from: Date()),
            invitedAt: nil,
            invitedBy: nil
        )
        try await supabaseClient
            .from("tenant_memberships")
            .insert(membership)
            .execute()

        return result.user.id
    }

    /// Sends a parent consent email for an under-13 student.
    /// Used by SignUpView after sign-up completes.
    func sendParentConsentEmail(childUserId: UUID, parentEmail: String) async {
        _ = try? await supabaseClient.rpc(
            "send_parent_consent_email",
            params: [
                "child_user_id": childUserId.uuidString,
                "parent_email": parentEmail
            ]
        ).execute()
    }

    /// Creates a new school (tenant), admin auth account, profile, and membership.
    /// Used by AdminSetupView instead of calling supabaseClient directly.
    func createSchool(
        schoolName: String,
        schoolCode: String,
        adminEmail: String,
        adminPassword: String,
        firstName: String,
        lastName: String
    ) async throws {
        // 1. Sign up admin with Supabase Auth
        let result = try await supabaseClient.auth.signUp(
            email: adminEmail,
            password: adminPassword,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName),
                "role": .string(UserRole.admin.rawValue)
            ]
        )

        // 2. Create tenant record
        let tenantId = UUID()
        let tenantRecord = InsertTenantDTO(
            id: tenantId,
            name: schoolName,
            slug: schoolCode,
            status: "active"
        )
        try await supabaseClient
            .from("tenants")
            .insert(tenantRecord)
            .execute()

        // 3. Create admin profile
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

        // 4. Create tenant membership
        let membership = InsertTenantMembershipDTO(
            userId: result.user.id,
            tenantId: tenantId,
            role: UserRole.admin.rawValue,
            status: "active",
            joinedAt: ISO8601DateFormatter().string(from: Date()),
            invitedAt: nil,
            invitedBy: nil
        )
        try await supabaseClient
            .from("tenant_memberships")
            .insert(membership)
            .execute()
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
        let role = memberships.first.flatMap { UserRole.from($0.role) } ?? .student

        // Derive schoolId from tenant_memberships.tenant_id
        let tenantId = memberships.first?.tenantId?.uuidString

        var user = profile.toUser(email: userEmail, role: role, streak: 0)
        user.schoolId = tenantId
        currentUser = user
    }

    // MARK: - Sync streak to student_xp table (NOT profiles)
    func syncProfile() {
        guard let user = currentUser, !isDemoMode else { return }
        Task {
            do {
                let update = UpdateStudentXpDTO(
                    streakDays: user.streak
                )
                _ = try await supabaseClient
                    .from("student_xp")
                    .update(update)
                    .eq("student_id", value: user.id.uuidString)
                    .execute()
            } catch {
                dataError = "Unable to sync profile. Please try again."
                #if DEBUG
                print("[AppViewModel] Sync profile error: \(error)")
                #endif
            }
        }
    }

    // MARK: - Data Fetching

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
                await loadOfflineData()
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
            do {
                announcements = try await dataService.fetchAnnouncements()
            } catch {
                log("Fetch announcements error: \(error)", level: .error)
                // Non-blocking: announcements are supplementary
            }

            // Per-role essential data for the dashboard
            switch user.role {
            case .student:
                // Students need grades summary on the dashboard
                let courseIds = courses.map(\.id)
                do {
                    grades = try await dataService.fetchGrades(for: user.id, courseIds: courseIds)
                } catch {
                    gradeError = "Unable to load grades. Please try again."
                    log("Fetch grades error: \(error)", level: .error)
                }
                gradesLoaded = true

            case .teacher:
                // Courses already loaded above — that is what teachers see on dashboard
                break

            case .parent:
                do {
                    children = try await dataService.fetchChildren(for: user.id)
                } catch {
                    dataError = "Unable to load children data. Please try again."
                    log("Fetch children error: \(error)", level: .error)
                }
                scheduleParentAlerts()

            case .admin, .superAdmin:
                // Load school metrics and first page of users for admin dashboard
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.userPagination.reset()
                        do {
                            let newUsers = try await self.dataService.fetchAllUsers(
                                schoolId: user.schoolId,
                                offset: self.userPagination.offset,
                                limit: self.userPagination.pageSize
                            )
                            self.allUsers = newUsers
                            self.userPagination.offset = newUsers.count
                            self.userPagination.hasMore = newUsers.count >= self.userPagination.pageSize
                        } catch {
                            self.dataError = "Unable to load users. Please try again."
                            self.log("Fetch all users error: \(error)", level: .error)
                        }
                    }
                    group.addTask { @MainActor in
                        do {
                            self.schoolMetrics = try await self.dataService.fetchSchoolMetrics(schoolId: user.schoolId)
                        } catch {
                            self.log("Fetch school metrics error: \(error)", level: .error)
                        }
                    }
                }
            }
            isDataLoading = false
            refreshDerivedProperties()

            // Move expensive I/O operations off the main thread
            let assignmentsForReminders = assignments
            Task.detached(priority: .utility) { @MainActor [weak self] in
                self?.cacheDataForExtensions()
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
            log("loadData failed: \(error)", level: .error)
            handlePotentialAuthError(error)
            if offlineStorage.hasOfflineData {
                dataError = "Could not load data. Using offline data."
                await loadOfflineData()
            } else {
                dataError = "Could not load data. Using offline mode."
                loadMockData()
            }
        }
    }

    // MARK: - Lazy "If Needed" Loaders

    /// Called when user opens the Assignments tab. Loads assignments only if not already loaded.
    /// Cancels any prior in-flight assignments fetch before starting a new one.
    func loadAssignmentsIfNeeded() {
        guard !assignmentsLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["assignments"]?.cancel()
        activeTasks["assignments"] = Task {
            let courseIds = courses.map(\.id)
            assignmentPagination.reset()
            do {
                try Task.checkCancellation()
                let newAssignments = try await dataService.fetchAssignments(
                    for: user.id,
                    role: user.role,
                    courseIds: courseIds,
                    offset: assignmentPagination.offset,
                    limit: assignmentPagination.pageSize
                )
                try Task.checkCancellation()
                assignments = newAssignments
                assignmentPagination.offset = newAssignments.count
                assignmentPagination.hasMore = newAssignments.count >= assignmentPagination.pageSize
                assignmentsLoaded = true
                refreshDerivedProperties()
                saveDataToOfflineStorage()

                // Schedule due-date reminders for newly loaded assignments
                notificationService.scheduleDueDateRemindersIfEnabled(assignments: newAssignments)
                await dueDateReminderService.refreshReminders(assignments: newAssignments)
            } catch is CancellationError {
                // Expected when task is cancelled during logout or superseded — no action needed
            } catch {
                dataError = "Unable to load assignments. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch assignments error: \(error)")
                #endif
                assignmentsLoaded = true
            }
        }
    }

    /// Called when user opens the Messages tab. Loads conversations only if not already loaded.
    /// Cancels any prior in-flight conversations fetch before starting a new one.
    func loadConversationsIfNeeded() {
        guard !conversationsLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["conversations"]?.cancel()
        activeTasks["conversations"] = Task {
            conversationPagination.reset()
            do {
                try Task.checkCancellation()
                let newConversations = try await dataService.fetchConversations(
                    for: user.id,
                    offset: conversationPagination.offset,
                    limit: conversationPagination.pageSize
                )
                try Task.checkCancellation()
                conversations = newConversations
                conversationPagination.offset = newConversations.count
                conversationPagination.hasMore = newConversations.count >= conversationPagination.pageSize
                refreshDerivedProperties()
                saveDataToOfflineStorage()
            } catch is CancellationError {
                // Expected — no action needed
            } catch {
                dataError = "Unable to load conversations. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch conversations error: \(error)")
                #endif
            }
            conversationsLoaded = true
        }
    }

    /// Called when user opens the Grades tab. Loads grades only if not already loaded.
    /// Cancels any prior in-flight grades fetch before starting a new one.
    func loadGradesIfNeeded() {
        guard !gradesLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["grades"]?.cancel()
        activeTasks["grades"] = Task {
            let courseIds = courses.map(\.id)
            do {
                try Task.checkCancellation()
                grades = try await dataService.fetchGrades(for: user.id, courseIds: courseIds)
                try Task.checkCancellation()
            } catch is CancellationError {
                // Expected — no action needed
            } catch {
                gradeError = "Unable to load grades. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch grades error: \(error)")
                #endif
            }
            gradesLoaded = true
        }
    }

    // loadLeaderboardIfNeeded removed — XP system disabled

    /// Called when user opens the Quizzes section. Loads quizzes only if not already loaded.
    /// Cancels any prior in-flight quizzes fetch before starting a new one.
    func loadQuizzesIfNeeded() {
        guard !quizzesLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["quizzes"]?.cancel()
        activeTasks["quizzes"] = Task {
            let courseIds = courses.map(\.id)
            do {
                try Task.checkCancellation()
                quizzes = try await dataService.fetchQuizzes(for: user.id, courseIds: courseIds)
                try Task.checkCancellation()
                saveDataToOfflineStorage()
            } catch is CancellationError {
                // Expected — no action needed
            } catch {
                dataError = "Unable to load quizzes. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch quizzes error: \(error)")
                #endif
            }
            quizzesLoaded = true
        }
    }

    /// Called when user opens the Attendance section. Loads attendance only if not already loaded.
    /// Cancels any prior in-flight attendance fetch before starting a new one.
    func loadAttendanceIfNeeded() {
        guard !attendanceLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["attendance"]?.cancel()
        activeTasks["attendance"] = Task {
            do {
                try Task.checkCancellation()
                attendance = try await dataService.fetchAttendance(for: user.id)
                try Task.checkCancellation()
            } catch is CancellationError {
                // Expected — no action needed
            } catch {
                dataError = "Unable to load attendance records. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch attendance error: \(error)")
                #endif
            }
            attendanceLoaded = true
        }
    }

    /// Called when user opens the Achievements section. Loads achievements only if not already loaded.
    /// Cancels any prior in-flight achievements fetch before starting a new one.
    func loadAchievementsIfNeeded() {
        guard !achievementsLoaded, !isDemoMode, let user = currentUser else { return }
        activeTasks["achievements"]?.cancel()
        activeTasks["achievements"] = Task {
            do {
                try Task.checkCancellation()
                achievements = try await dataService.fetchAchievements(for: user.id)
                try Task.checkCancellation()
            } catch is CancellationError {
                // Expected — no action needed
            } catch {
                dataError = "Unable to load achievements. Please try again."
                #if DEBUG
                print("[AppViewModel] Fetch achievements error: \(error)")
                #endif
            }
            achievementsLoaded = true
        }
    }


    // XP loading removed — system disabled

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
            refreshDerivedProperties()
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
            refreshDerivedProperties()
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

    // MARK: - Search

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

    // Leaderboard removed — XP system disabled

    private func loadMockData() {
        courses = mockService.sampleCourses()
        assignments = mockService.sampleAssignments()
        quizzes = mockService.sampleQuizzes()
        grades = mockService.sampleGrades()
        attendance = mockService.sampleAttendance()
        achievements = mockService.sampleAchievements()
        // leaderboard removed (XP system disabled)
        conversations = mockService.sampleConversations()
        announcements = mockService.sampleAnnouncements()
        children = mockService.sampleChildren()
        schoolMetrics = mockService.sampleSchoolMetrics()

        // Populate course schedules for demo mode
        courseSchedules = generateMockSchedules(for: courses)

        // Populate conference scheduling demo data
        loadDemoConferenceData()

        refreshDerivedProperties()

        cacheDataForExtensions()
    }

    /// Builds a realistic weekly timetable from the enrolled courses.
    private func generateMockSchedules(for enrolledCourses: [Course]) -> [CourseSchedule] {
        // Each tuple: (dayOfWeek, startMinute, roomNumber)
        let slots: [(DayOfWeek, Int, String)] = [
            // Algebra II  -- MWF 8:00-8:50 AM, Room 204
            (.monday, 480, "Room 204"),
            (.wednesday, 480, "Room 204"),
            (.friday, 480, "Room 204"),
            // AP Biology -- TTh 9:00-10:15 AM, Lab 112
            (.tuesday, 540, "Lab 112"),
            (.thursday, 540, "Lab 112"),
            // World History -- MWF 10:30-11:20 AM, Room 310
            (.monday, 630, "Room 310"),
            (.wednesday, 630, "Room 310"),
            (.friday, 630, "Room 310"),
            // English Literature -- TTh 1:00-2:15 PM, Room 105
            (.tuesday, 780, "Room 105"),
            (.thursday, 780, "Room 105"),
            // Intro to Computer Science -- MW 2:30-3:20 PM, Lab 218
            (.monday, 870, "Lab 218"),
            (.wednesday, 870, "Lab 218"),
        ]

        let mwfDuration = 50
        let tthDuration = 75

        var schedules: [CourseSchedule] = []

        for (index, course) in enrolledCourses.enumerated() {
            let courseSlots: [(DayOfWeek, Int, String)]
            switch index {
            case 0: courseSlots = Array(slots[0...2])
            case 1: courseSlots = Array(slots[3...4])
            case 2: courseSlots = Array(slots[5...7])
            case 3: courseSlots = Array(slots[8...9])
            case 4: courseSlots = Array(slots[10...11])
            default: continue
            }

            for (day, start, room) in courseSlots {
                let isTTh = (day == .tuesday || day == .thursday)
                let duration = isTTh ? tthDuration : mwfDuration
                schedules.append(
                    CourseSchedule(
                        id: UUID(),
                        courseId: course.id,
                        dayOfWeek: day,
                        startMinute: start,
                        endMinute: start + duration,
                        roomNumber: room
                    )
                )
            }
        }

        return schedules
    }

    // MARK: - Offline Storage Helpers

    /// Sync all data for offline use. Called when user enables offline mode or taps "Sync Now".
    /// When reconnecting after being offline, runs conflict resolution (server-wins) before
    /// updating the local cache, so users are notified if their offline edits were overwritten.
    func syncForOfflineUse() async {
        isSyncingOffline = true
        if networkMonitor.isConnected {
            // Fetch fresh server data
            await loadData()

            // Run conflict resolution against what we had cached locally
            await conflictResolution.resolveConflicts(
                serverCourses: courses,
                serverAssignments: assignments,
                serverGrades: grades,
                serverConversations: conversations
            )
        }
        saveDataToOfflineStorage()
        offlineModeEnabled = true
        isSyncingOffline = false
    }

    private func saveDataToOfflineStorage() {
        offlineStorage.saveCourses(courses)
        offlineStorage.saveAssignments(assignments)
        offlineStorage.saveGrades(grades)
        offlineStorage.saveConversations(conversations)
        if let user = currentUser {
            offlineStorage.saveUserProfile(user)
        }
        // Build and persist metadata for conflict detection on next sync
        let metadata = conflictResolution.buildMetadata(
            courses: courses,
            assignments: assignments,
            grades: grades,
            conversations: conversations
        )
        offlineStorage.saveMetadata(metadata)
        offlineStorage.lastSyncDate = Date()
    }

    private func loadOfflineData() async {
        // Ensure offline storage is scoped to the current user before loading
        if let userId = currentUser?.id {
            offlineStorage.setCurrentUser(userId)
        }
        courses = await offlineStorage.loadCourses()
        assignments = await offlineStorage.loadAssignments()
        grades = await offlineStorage.loadGrades()
        conversations = await offlineStorage.loadConversations()
        if currentUser == nil {
            currentUser = await offlineStorage.loadUserProfile()
        }
        refreshDerivedProperties()
        cacheDataForExtensions()
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
        guard let user = currentUser, !isDemoMode else { return }
        guard networkMonitor.isConnected else {
            dataError = "You're offline. Pull to refresh when connected."
            return
        }
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
        guard let user = currentUser, !isDemoMode else { return }
        guard networkMonitor.isConnected else {
            dataError = "You're offline. Pull to refresh when connected."
            return
        }
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
            refreshDerivedProperties()
        } catch {
            dataError = "Could not refresh assignments."
            #if DEBUG
            print("[AppViewModel] refreshAssignments failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only grades from the data service. Used by pull-to-refresh on the grades view.
    func refreshGrades() async {
        guard let user = currentUser, !isDemoMode else { return }
        guard networkMonitor.isConnected else {
            dataError = "You're offline. Pull to refresh when connected."
            return
        }
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
        guard let user = currentUser, !isDemoMode else { return }
        guard networkMonitor.isConnected else {
            dataError = "You're offline. Pull to refresh when connected."
            return
        }
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
            refreshDerivedProperties()
        } catch {
            dataError = "Could not refresh conversations."
            #if DEBUG
            print("[AppViewModel] refreshConversations failed: \(error)")
            #endif
        }
    }

    /// Re-fetches only attendance records from the data service. Used by pull-to-refresh on the attendance view.
    func refreshAttendance() async {
        guard let user = currentUser, !isDemoMode else { return }
        guard networkMonitor.isConnected else {
            dataError = "You're offline. Pull to refresh when connected."
            return
        }
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
                // Reduce refresh frequency on cellular (10 min) or Low Data Mode (15 min).
                let interval: Double = networkMonitor.isConstrained ? 900 : (networkMonitor.isExpensive ? 600 : autoRefreshInterval)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, isAuthenticated, !isDemoMode, networkMonitor.isConnected else { continue }
                // Reset lazy-loading flags before refreshing so stale
                // on-demand data (assignments, conversations, etc.) is
                // re-fetched when the user next navigates to those screens.
                resetLazyLoadingFlags()
                await loadData()
            }
        }
    }

    /// Observes network connectivity changes and triggers a data refresh when coming back online.
    func startNetworkObserver() {
        Task { [weak self] in
            var wasOffline = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self else { return }
                let isOnline = self.networkMonitor.isConnected
                if wasOffline && isOnline && self.isAuthenticated {
                    #if DEBUG
                    print("[AppViewModel] Back online — syncing data")
                    #endif
                    await self.loadData()
                    self.dataError = nil
                }
                wasOffline = !isOnline
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
        guard isAuthenticated, !isDemoMode, !isAppLocked else { return }
        startAutoRefresh()
        startNetworkObserver()

        // Sync the due-date reminder count from the notification center.
        // This is lightweight (local query only) and keeps the badge accurate
        // even when offline.
        Task { await dueDateReminderService.syncScheduledCount() }

        // Only refresh if we have a network connection
        guard networkMonitor.isConnected else { return }
        refreshData()
    }

    // MARK: - Cache Data for Extensions (Siri Intents + Widgets)
    /// Writes lightweight JSON summaries to the shared App Group UserDefaults so
    /// both App Intents (Siri) and WidgetKit widgets can read grades, assignments,
    /// and schedule without needing a live Supabase session.
    func cacheDataForExtensions() {
        guard let defaults = UserDefaults(suiteName: UserDefaultsKeys.widgetAppGroup) else { return }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // FERPA: Set auth flag so widgets/intents can verify user is signed in
        defaults.set(isAuthenticated, forKey: "wolfwhale_is_authenticated")

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
                "role": .string(role.rawValue.lowercased())
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
            role: role.rawValue.lowercased(),
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

        // Audit: record user creation (FERPA compliance -- admin actions must be tracked)
        await auditLog.log(
            AuditAction.create,
            entityType: AuditEntityType.user,
            entityId: result.user.id.uuidString,
            details: [
                "email": email,
                "role": role.rawValue,
                "created_by": admin.id.uuidString
            ]
        )
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

    // MARK: - Assignment Management

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
            refreshDerivedProperties()

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
            refreshDerivedProperties()
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

        // Send local notification for the new announcement
        notificationService.sendAnnouncementNotificationIfEnabled(title: title, body: content)
    }

    // MARK: - Student Actions
    func completeLesson(_ lesson: Lesson, in course: Course) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == course.id }) else { return }
        for moduleIndex in courses[courseIndex].modules.indices {
            if let lessonIndex = courses[courseIndex].modules[moduleIndex].lessons.firstIndex(where: { $0.id == lesson.id }) {
                courses[courseIndex].modules[moduleIndex].lessons[lessonIndex].isCompleted = true

                if !isDemoMode, let user = currentUser {
                    let tenantUUID = user.schoolId.flatMap { UUID(uuidString: $0) } ?? UUID()
                    let ci = courseIndex, mi = moduleIndex, li = lessonIndex
                    Task {
                        do {
                            try await dataService.completeLesson(studentId: user.id, lessonId: lesson.id, courseId: course.id, tenantId: tenantUUID)
                        } catch {
                            // Revert optimistic update — lesson completion was not persisted
                            courses[ci].modules[mi].lessons[li].isCompleted = false
                            dataError = UserFacingError.sanitize(error).localizedDescription
                            #if DEBUG
                            print("[AppViewModel] completeLesson failed: \(error)")
                            #endif
                        }
                    }
                }
                syncProfile()
                break
            }
        }
    }

    /// Error surfaced to the student when a submission fails to persist.
    var submissionError: String?

    func submitAssignment(_ assignment: Assignment, text: String) {
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        // Prevent double-submission: if already submitted locally, bail out
        guard !assignments[index].isSubmitted else { return }

        // Save previous state for rollback
        let previousIsSubmitted = assignments[index].isSubmitted
        let previousSubmission = assignments[index].submission
        let previousAttachmentURLs = assignments[index].attachmentURLs

        assignments[index].isSubmitted = true
        assignments[index].submission = text

        // Extract and store attachment URLs from the submission text
        let urls = Assignment.extractAttachmentURLs(from: text)
        if !urls.isEmpty {
            assignments[index].attachmentURLs = urls
        }

        if !isDemoMode, let user = currentUser {
            let assignmentId = assignment.id
            Task {
                do {
                    try await dataService.submitAssignment(assignmentId: assignmentId, studentId: user.id, content: text)

                    // Audit: record assignment submission (only on success)
                    await auditLog.log(
                        AuditAction.create,
                        entityType: AuditEntityType.assignment,
                        entityId: assignmentId.uuidString,
                        details: ["action": "submit", "student_id": user.id.uuidString, "course_id": assignment.courseId.uuidString]
                    )
                } catch {
                    // Revert optimistic update — student's submission was NOT saved
                    if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) {
                        assignments[idx].isSubmitted = previousIsSubmitted
                        assignments[idx].submission = previousSubmission
                        assignments[idx].attachmentURLs = previousAttachmentURLs
                    }
                    submissionError = UserFacingError.sanitize(error).localizedDescription
                    #if DEBUG
                    print("[AppViewModel] submitAssignment failed: \(error)")
                    #endif
                }
            }
        }

        // Cancel reminders for the now-submitted assignment and refresh count
        Task {
            await dueDateReminderService.cancelReminders(for: assignment.id)
        }

        syncProfile()
    }

    /// Legacy submit for backward compatibility (MC-only quizzes).
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
            let quizId = quiz.id
            Task {
                do {
                    try await dataService.submitQuizAttempt(quizId: quizId, studentId: user.id, score: score)
                } catch {
                    // Revert optimistic update — quiz attempt was not persisted
                    if let idx = quizzes.firstIndex(where: { $0.id == quizId }) {
                        quizzes[idx].isCompleted = false
                        quizzes[idx].score = nil
                    }
                    submissionError = UserFacingError.sanitize(error).localizedDescription
                    #if DEBUG
                    print("[AppViewModel] submitQuiz failed: \(error)")
                    #endif
                }
            }
        }
        syncProfile()
        return score
    }

    /// Result from submitting an advanced quiz with multiple question types.
    struct AdvancedQuizResult {
        let score: Double           // percentage of auto-graded questions correct
        let hasPendingReview: Bool  // true if essay or matching questions need teacher review
    }

    /// Submits a quiz that may contain multiple question types. Auto-grades what it can,
    /// flags essay and matching for manual review.
    func submitAdvancedQuiz(
        _ quiz: Quiz,
        selectedAnswers: [Int],
        fillInAnswers: [String],
        matchingSelections: [[String]],
        essayTexts: [String]
    ) -> AdvancedQuizResult {
        guard let index = quizzes.firstIndex(where: { $0.id == quiz.id }) else {
            return AdvancedQuizResult(score: 0, hasPendingReview: false)
        }

        var autoGradableCount = 0
        var correctCount = 0
        var hasPending = false

        for (i, question) in quiz.questions.enumerated() {
            switch question.questionType {
            case .multipleChoice, .trueFalse:
                autoGradableCount += 1
                if i < selectedAnswers.count && selectedAnswers[i] == question.correctIndex {
                    correctCount += 1
                }

            case .fillInBlank:
                autoGradableCount += 1
                if i < fillInAnswers.count {
                    let studentAnswer = fillInAnswers[i]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    let isCorrect = question.acceptedAnswers.contains { accepted in
                        accepted.trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased() == studentAnswer
                    }
                    if isCorrect { correctCount += 1 }
                }

            case .matching:
                hasPending = true

            case .essay:
                hasPending = true
            }
        }

        let score: Double
        if autoGradableCount > 0 {
            score = Double(correctCount) / Double(autoGradableCount) * 100
        } else {
            score = 0
        }

        quizzes[index].isCompleted = true
        quizzes[index].score = score

        if !isDemoMode, let user = currentUser {
            let quizId = quiz.id
            Task {
                do {
                    try await dataService.submitQuizAttempt(quizId: quizId, studentId: user.id, score: score)
                } catch {
                    // Revert optimistic update — quiz attempt was not persisted
                    if let idx = quizzes.firstIndex(where: { $0.id == quizId }) {
                        quizzes[idx].isCompleted = false
                        quizzes[idx].score = nil
                    }
                    submissionError = UserFacingError.sanitize(error).localizedDescription
                    #if DEBUG
                    print("[AppViewModel] submitAdvancedQuiz failed: \(error)")
                    #endif
                }
            }
        }
        syncProfile()
        return AdvancedQuizResult(score: score, hasPendingReview: hasPending)
    }

    // MARK: - Messaging

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
            refreshDerivedProperties()
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
            refreshDerivedProperties()
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
        refreshDerivedProperties()
        return courseName
    }

    // MARK: - Student: Load Course Catalog

    /// Fetches all courses in the student's school and filters out already-enrolled courses.
    /// Populates `allAvailableCourses` with courses the student is NOT currently enrolled in.
    func loadCourseCatalog() async {
        guard let user = currentUser, user.role == .student else { return }

        if isDemoMode {
            let allMock = mockService.sampleCourses()
            let enrolledIds = Set(courses.map(\.id))
            let extraCourses: [Course] = [
                Course(
                    id: UUID(), title: "Computer Science 101",
                    description: "Introduction to programming, algorithms, and computational thinking.",
                    teacherName: "Mr. Alan Turing", iconSystemName: "desktopcomputer", colorName: "cyan",
                    modules: [], enrolledStudentCount: 22, progress: 0, classCode: "CS-101"
                ),
                Course(
                    id: UUID(), title: "Creative Writing",
                    description: "Explore fiction, poetry, and narrative through weekly workshops.",
                    teacherName: "Ms. Maya Angelou", iconSystemName: "pencil.and.outline", colorName: "orange",
                    modules: [], enrolledStudentCount: 18, progress: 0, classCode: "CW-2024"
                ),
                Course(
                    id: UUID(), title: "Music Theory",
                    description: "Fundamentals of rhythm, melody, harmony, and composition.",
                    teacherName: "Dr. Ludwig Bach", iconSystemName: "music.note.list", colorName: "indigo",
                    modules: [], enrolledStudentCount: 15, progress: 0, classCode: "MUS-2024"
                ),
                Course(
                    id: UUID(), title: "Physical Education",
                    description: "Fitness, team sports, and healthy lifestyle habits.",
                    teacherName: "Coach Jordan", iconSystemName: "figure.run", colorName: "red",
                    modules: [], enrolledStudentCount: 30, progress: 0, classCode: "PE-2024"
                ),
            ]
            allAvailableCourses = (allMock + extraCourses).filter { !enrolledIds.contains($0.id) }
            return
        }

        do {
            let allSchoolCourses = try await dataService.fetchCourses(
                for: user.id,
                role: .admin,
                schoolId: user.schoolId
            )
            let enrolledIds = Set(courses.map(\.id))
            allAvailableCourses = allSchoolCourses.filter { !enrolledIds.contains($0.id) }
        } catch {
            #if DEBUG
            print("[AppViewModel] loadCourseCatalog failed: \(error)")
            #endif
        }
    }

    // MARK: - Enrollment Approval Workflow

    private let enrollmentWorkflowService = EnrollmentService()

    /// Student: request enrollment in a course by courseId.
    func requestEnrollment(courseId: UUID) async {
        guard let user = currentUser, user.role == .student else { return }
        let success = await enrollmentWorkflowService.requestEnrollment(courseId: courseId, studentId: user.id)
        if !success {
            enrollmentError = enrollmentWorkflowService.error
        }
    }

    /// Teacher: load all pending enrollment requests for courses they own.
    func loadEnrollmentRequests() async {
        guard let user = currentUser, user.role == .teacher else { return }
        await enrollmentWorkflowService.fetchPendingRequests(teacherId: user.id)
        enrollmentRequests = enrollmentWorkflowService.pendingRequests
    }

    /// Teacher: approve a pending enrollment request.
    func approveEnrollment(requestId: UUID) async {
        guard let user = currentUser else { return }
        let success = await enrollmentWorkflowService.approveEnrollment(requestId: requestId, reviewerId: user.id)
        if success {
            enrollmentRequests.removeAll { $0.id == requestId }
        } else {
            enrollmentError = enrollmentWorkflowService.error
        }
    }

    /// Teacher: deny a pending enrollment request.
    func denyEnrollment(requestId: UUID) async {
        guard let user = currentUser else { return }
        let success = await enrollmentWorkflowService.denyEnrollment(requestId: requestId, reviewerId: user.id, reason: nil)
        if success {
            enrollmentRequests.removeAll { $0.id == requestId }
        } else {
            enrollmentError = enrollmentWorkflowService.error
        }
    }

    // MARK: - Grade Management

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

            // Send local notification for the posted grade
            let gradeDisplay = "\(letterGrade) (\(Int(percentage))%)"
            notificationService.sendGradeNotificationIfEnabled(
                assignmentTitle: assignment.title,
                grade: gradeDisplay,
                assignmentId: assignmentId
            )

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
            gradeError = UserFacingError.sanitize(error).localizedDescription
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
                    questionType: question.questionType.rawValue,
                    options: question.options,
                    correctIndex: question.correctIndex,
                    acceptedAnswers: question.acceptedAnswers,
                    matchingPairs: question.matchingPairs,
                    essayPrompt: question.essayPrompt,
                    essayMinWords: question.essayMinWords,
                    explanation: question.explanation
                )
            }

            refreshData()
        } catch {
            dataError = UserFacingError.sanitize(error).localizedDescription
            throw error
        }
    }

    // MARK: - Teacher: Create Lesson
    func createLesson(courseId: UUID, moduleId: UUID, title: String, content: String, duration: Int, type: LessonType, xpReward: Int, slideResources: [SlideResource] = []) async throws {
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
                        xpReward: xpReward,
                        slideResources: slideResources
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
            dataError = UserFacingError.sanitize(error).localizedDescription
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
            dataError = UserFacingError.sanitize(error).localizedDescription
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
            dataError = UserFacingError.sanitize(error).localizedDescription
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
            refreshDerivedProperties()
            return
        }

        do {
            _ = try await dataService.createConversation(
                title: title,
                participantIds: participantIds
            )
            if let user = currentUser {
                conversations = try await dataService.fetchConversations(for: user.id)
                refreshDerivedProperties()
            }
        } catch {
            dataError = UserFacingError.sanitize(error).localizedDescription
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
            dataError = UserFacingError.sanitize(error).localizedDescription
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
            dataError = UserFacingError.sanitize(error).localizedDescription
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

            // Audit: record assignment deletion (FERPA compliance)
            await auditLog.log(
                AuditAction.delete,
                entityType: AuditEntityType.assignment,
                entityId: assignmentId.uuidString,
                details: ["deleted_by": currentUser?.id.uuidString ?? "unknown"]
            )
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

        // Audit: record student unenrollment (FERPA compliance -- enrollment changes must be tracked)
        if !isDemoMode {
            await auditLog.log(
                AuditAction.delete,
                entityType: AuditEntityType.enrollment,
                entityId: courseId.uuidString,
                details: [
                    "student_id": studentId.uuidString,
                    "course_id": courseId.uuidString,
                    "action": "unenroll",
                    "performed_by": currentUser?.id.uuidString ?? "unknown"
                ]
            )
        }
    }

    // MARK: - Attendance Report Generation

    /// Generates an attendance report for a specific course or school-wide within a date range.
    /// Pass `nil` for `courseId` to generate a school-wide report (admin).
    func generateAttendanceReport(courseId: String?, startDate: Date, endDate: Date) -> AttendanceReport {
        let calendar = Calendar.current

        // Filter records by date range
        var filtered = attendance.filter { record in
            let recordDay = calendar.startOfDay(for: record.date)
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: endDate)
            return recordDay >= start && recordDay <= end
        }

        // Filter by course if specified
        var resolvedCourseName: String? = nil
        if let courseId, let courseUUID = UUID(uuidString: courseId) {
            let matchingCourse = courses.first(where: { $0.id == courseUUID })
            resolvedCourseName = matchingCourse?.title
            if let name = resolvedCourseName {
                filtered = filtered.filter { $0.courseName == name }
            }
        }

        // Count statuses
        let presentCount = filtered.filter { $0.status == .present }.count
        let absentCount = filtered.filter { $0.status == .absent }.count
        let tardyCount = filtered.filter { $0.status == .tardy }.count
        let excusedCount = filtered.filter { $0.status == .excused }.count

        // Calculate unique days
        let uniqueDays = Set(filtered.map { calendar.startOfDay(for: $0.date) })
        let totalDays = uniqueDays.count

        // Build per-student breakdowns
        let studentGroups = Dictionary(grouping: filtered) { $0.studentName ?? "Unknown" }
        let studentBreakdowns: [StudentAttendanceBreakdown] = studentGroups.map { name, records in
            StudentAttendanceBreakdown(
                id: UUID(),
                studentName: name,
                presentCount: records.filter { $0.status == .present }.count,
                absentCount: records.filter { $0.status == .absent }.count,
                tardyCount: records.filter { $0.status == .tardy }.count,
                excusedCount: records.filter { $0.status == .excused }.count
            )
        }.sorted { $0.studentName < $1.studentName }

        // Build daily rates sorted by date
        let dailyGroups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        let dailyRates: [DailyAttendanceRate] = dailyGroups.map { date, records in
            let present = records.filter { $0.status == .present || $0.status == .tardy }.count
            return DailyAttendanceRate(
                id: UUID(),
                date: date,
                totalCount: records.count,
                presentCount: present
            )
        }.sorted { $0.date < $1.date }

        return AttendanceReport(
            startDate: startDate,
            endDate: endDate,
            courseName: resolvedCourseName,
            totalDays: totalDays,
            totalRecords: filtered.count,
            presentCount: presentCount,
            absentCount: absentCount,
            tardyCount: tardyCount,
            excusedCount: excusedCount,
            studentBreakdowns: studentBreakdowns,
            dailyRates: dailyRates
        )
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

    // Role is not on profiles; need to use tenant_memberships to filter teachers.
    // Optimized: only fetch teachers who teach courses the child is enrolled in,
    // rather than fetching ALL teachers for the entire tenant.
    func fetchTeachersForChild(childId: UUID) async -> [ProfileDTO] {
        if isDemoMode {
            // In demo mode, return empty since ProfileDTO has no role property
            return []
        }
        do {
            // 1. Get the child's enrolled course IDs
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: childId.uuidString)
                .execute()
                .value
            let courseIds = enrollments.map(\.courseId)
            if courseIds.isEmpty { return [] }

            // 2. Get the courses to find their teacher (created_by) IDs
            let courseDTOs: [CourseDTO] = try await supabaseClient
                .from("courses")
                .select()
                .in("id", values: courseIds.map(\.uuidString))
                .execute()
                .value
            let teacherIds = Array(Set(courseDTOs.compactMap(\.createdBy)))
            if teacherIds.isEmpty { return [] }

            // 3. Fetch only those teacher profiles
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
            guard self != nil else { return }
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
        biometricService.lock()
    }

    func unlockApp() {
        isAppLocked = false
        biometricService.markUnlockedAfterPasswordVerification()
        // Resume data refresh that was blocked while locked
        handleForegroundResume()
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
        let message = String(describing: error).lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") || message.contains("invalid_credentials") {
            return "Invalid email or password"
        } else if message.contains("email not confirmed") {
            return "Please confirm your email before signing in"
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection"
        }
        return "Sign in failed. Please try again."
    }

    // MARK: - Rubrics

    /// Loads all rubrics for a given course. Falls back to local storage in demo mode.
    func loadRubrics(for courseId: UUID) async {
        if isDemoMode {
            // In demo mode rubrics are already stored in-memory; nothing to fetch.
            return
        }

        do {
            // Attempt to fetch rubrics from a Supabase `rubrics` table
            let rows: [Rubric] = try await supabaseClient
                .from("rubrics")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Merge fetched rubrics into the local array (avoid duplicates)
            let existingIds = Set(rubrics.map(\.id))
            let newOnes = rows.filter { !existingIds.contains($0.id) }
            rubrics.append(contentsOf: newOnes)
            // Update any that already exist
            for row in rows {
                if let idx = rubrics.firstIndex(where: { $0.id == row.id }) {
                    rubrics[idx] = row
                }
            }
        } catch {
            #if DEBUG
            print("[AppViewModel] Failed to load rubrics: \(error)")
            #endif
            // Non-fatal — teacher can still create rubrics locally
        }
    }

    /// Creates a new rubric and adds it to local state. Persists to Supabase when not in demo mode.
    func createRubric(title: String, courseId: UUID, criteria: [RubricCriterion]) async throws {
        guard currentUser != nil else { return }

        let sanitizedTitle = InputValidator.sanitizeText(title)
        guard !sanitizedTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            dataError = "Rubric title cannot be empty."
            throw ValidationError.invalidInput("Rubric title cannot be empty.")
        }
        guard !criteria.isEmpty else {
            dataError = "Rubric must have at least one criterion."
            throw ValidationError.invalidInput("Rubric must have at least one criterion.")
        }

        let rubric = Rubric(
            id: UUID(),
            title: sanitizedTitle,
            courseId: courseId,
            criteria: criteria,
            createdAt: Date()
        )

        if !isDemoMode {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let criteriaJSON = try encoder.encode(criteria)
                let criteriaString = String(data: criteriaJSON, encoding: .utf8) ?? "[]"

                try await supabaseClient
                    .from("rubrics")
                    .insert([
                        "id": rubric.id.uuidString,
                        "course_id": courseId.uuidString,
                        "title": sanitizedTitle,
                        "criteria": criteriaString,
                        "created_at": ISO8601DateFormatter().string(from: rubric.createdAt)
                    ])
                    .execute()
            } catch {
                #if DEBUG
                print("[AppViewModel] Failed to persist rubric: \(error)")
                #endif
                // Still add locally so the teacher can use it this session
            }
        }

        rubrics.append(rubric)
    }

    /// Returns the rubric for a given ID, if it exists in local state.
    func rubric(for id: UUID?) -> Rubric? {
        guard let id else { return nil }
        return rubrics.first(where: { $0.id == id })
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
