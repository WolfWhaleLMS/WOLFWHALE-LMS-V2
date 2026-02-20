import SwiftUI
import Supabase

@Observable
@MainActor
class AppViewModel {
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
    var schoolMetrics: SchoolMetrics?
    var allUsers: [ProfileDTO] = []
    var dataError: String?
    var gradeError: String?
    var enrollmentError: String?

    var isDemoMode = false
    private let mockService = MockDataService.shared
    private let dataService = DataService.shared
    let networkMonitor = NetworkMonitor()

    // MARK: - Notifications
    var notificationService = NotificationService()

    // MARK: - Biometric Auth
    var biometricService = BiometricAuthService()
    var isAppLocked: Bool = false

    var biometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }

    // MARK: - Calendar Sync
    var calendarService = CalendarService()
    var calendarSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_calendar_sync_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_calendar_sync_enabled") }
    }

    var gpa: Double {
        guard !grades.isEmpty else { return 0 }
        return grades.reduce(0) { $0 + $1.numericGrade } / Double(grades.count)
    }

    var upcomingAssignments: [Assignment] {
        assignments.filter { !$0.isSubmitted && !$0.isOverdue }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var overdueAssignments: [Assignment] {
        assignments.filter { $0.isOverdue }
    }

    var pendingGradingCount: Int {
        assignments.filter { $0.isSubmitted && $0.grade == nil }.count
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
            } catch {
                loginError = mapAuthError(error)
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
        if !isDemoMode {
            Task {
                try? await supabaseClient.auth.signOut()
                await CacheService.shared.invalidateAll()
            }
        }
        isDemoMode = false
        withAnimation(.smooth) {
            isAuthenticated = false
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
            schoolMetrics = nil
            allUsers = []
        }
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
            try? await supabaseClient
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

        guard networkMonitor.isConnected else {
            dataError = "No internet connection. Using offline mode."
            loadMockData()
            return
        }

        isDataLoading = true
        dataError = nil

        do {
            courses = try await dataService.fetchCourses(for: user.id, role: user.role)
            let courseIds = courses.map(\.id)

            // Batch common fetches concurrently using TaskGroup
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    self.assignments = (try? await self.dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)) ?? []
                }
                group.addTask { @MainActor in
                    self.announcements = (try? await self.dataService.fetchAnnouncements()) ?? []
                }
                group.addTask { @MainActor in
                    self.conversations = (try? await self.dataService.fetchConversations(for: user.id)) ?? []
                }
            }

            switch user.role {
            case .student:
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.quizzes = (try? await self.dataService.fetchQuizzes(for: user.id, courseIds: courseIds)) ?? []
                    }
                    group.addTask { @MainActor in
                        self.grades = (try? await self.dataService.fetchGrades(for: user.id, courseIds: courseIds)) ?? []
                    }
                    group.addTask { @MainActor in
                        self.attendance = (try? await self.dataService.fetchAttendance(for: user.id)) ?? []
                    }
                    group.addTask { @MainActor in
                        self.achievements = (try? await self.dataService.fetchAchievements(for: user.id)) ?? []
                    }
                    group.addTask { @MainActor in
                        await self.loadLeaderboard()
                    }
                }

            case .teacher:
                break

            case .parent:
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.children = (try? await self.dataService.fetchChildren(for: user.id)) ?? []
                    }
                    group.addTask { @MainActor in
                        self.allUsers = (try? await self.dataService.fetchAllUsers(schoolId: user.schoolId)) ?? []
                    }
                }

            case .admin, .superAdmin:
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.allUsers = (try? await self.dataService.fetchAllUsers(schoolId: user.schoolId)) ?? []
                    }
                    group.addTask { @MainActor in
                        self.schoolMetrics = try? await self.dataService.fetchSchoolMetrics(schoolId: user.schoolId)
                    }
                }
            }
            isDataLoading = false
            cacheDataForSiri()
            notificationService.scheduleAllAssignmentReminders(assignments: assignments)
        } catch {
            isDataLoading = false
            dataError = "Could not load data. Using offline mode."
            loadMockData()
        }
    }

    func loadLeaderboard() async {
        if let cached: [LeaderboardEntry] = await CacheService.shared.get("leaderboard") {
            leaderboard = cached
            return
        }
        do {
            leaderboard = try await dataService.fetchLeaderboard()
            await CacheService.shared.set("leaderboard", value: leaderboard, ttl: 60)
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
        cacheDataForSiri()
    }

    func refreshData() {
        Task {
            await loadData()
        }
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
            defaults.set(data, forKey: "wolfwhale_upcoming_assignments")
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
            defaults.set(data, forKey: "wolfwhale_grades_summary")
        }

        // 3. Today's schedule (derived from enrolled courses)
        let scheduleEntries = courses.map { course in
            CachedScheduleEntry(courseName: course.title, time: nil)
        }
        if let data = try? JSONEncoder().encode(scheduleEntries) {
            defaults.set(data, forKey: "wolfwhale_schedule_today")
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

        let trimFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimLast = lastName.trimmingCharacters(in: .whitespaces)

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
        allUsers = try await dataService.fetchAllUsers(schoolId: admin.schoolId)
    }

    func deleteUser(userId: UUID) async throws {
        guard let admin = currentUser, admin.role == .admin else {
            throw UserManagementError.unauthorized
        }
        try await dataService.deleteUser(userId: userId)
        allUsers.removeAll { $0.id == userId }
        if currentUser?.userSlotsUsed ?? 0 > 0 {
            currentUser?.userSlotsUsed -= 1
        }
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
        let classCode = "\(title.prefix(4).uppercased())-\(Int.random(in: 1000...9999))"

        let dto = InsertCourseDTO(
            tenantId: nil,
            name: title,
            description: description,
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

            courses = try await dataService.fetchCourses(for: user.id, role: user.role)
        } else {
            let newCourse = Course(
                id: UUID(), title: title, description: description,
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
        let xpReward = points / 2

        if !isDemoMode {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                tenantId: nil,
                courseId: courseId,
                title: title,
                description: nil,
                instructions: instructions,
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
        } else {
            let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"
            let newAssignment = Assignment(
                id: UUID(), title: title, courseId: courseId, courseName: courseName,
                instructions: instructions, dueDate: dueDate, points: points,
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
                status: nil
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
                    let tenantUUID = user.schoolId.flatMap { UUID(uuidString: $0) }
                    if let tenantUUID {
                        Task {
                            try? await dataService.completeLesson(studentId: user.id, lessonId: lesson.id, courseId: course.id, tenantId: tenantUUID)
                        }
                    }
                }
                syncProfile()
                break
            }
        }
    }

    func submitAssignment(_ assignment: Assignment, text: String) {
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        assignments[index].isSubmitted = true
        assignments[index].submission = text

        if !isDemoMode, let user = currentUser {
            Task {
                try? await dataService.submitAssignment(assignmentId: assignment.id, studentId: user.id, content: text)
            }
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
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let message = ChatMessage(id: UUID(), senderName: currentUser?.fullName ?? "You", content: text, timestamp: Date(), isFromCurrentUser: true)
        conversations[index].messages.append(message)
        conversations[index].lastMessage = text
        conversations[index].lastMessageDate = Date()

        if !isDemoMode, let user = currentUser {
            Task {
                try? await dataService.sendMessage(
                    conversationId: conversationId,
                    senderId: user.id,
                    senderName: user.fullName,
                    content: text
                )
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
        courses = try await dataService.fetchCourses(for: user.id, role: user.role)
        let courseIds = courses.map(\.id)
        assignments = try await dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
        return courseName
    }

    // MARK: - Teacher: Grade Submission
    func gradeSubmission(assignmentId: UUID, studentId: UUID?, score: Double, letterGrade: String, feedback: String?) async throws {
        isLoading = true
        gradeError = nil
        defer { isLoading = false }

        guard let assignment = assignments.first(where: { $0.id == assignmentId && $0.studentId == studentId }) ??
              assignments.first(where: { $0.id == assignmentId }) else {
            gradeError = "Assignment not found"
            throw NSError(domain: "AppViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Assignment not found"])
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
            return dtos.map { dto in
                AttendanceRecord(
                    id: dto.id,
                    date: ISO8601DateFormatter().date(from: dto.date ?? "") ?? Date(),
                    status: AttendanceStatus(rawValue: dto.status) ?? .present,
                    courseName: dto.courseName ?? "Unknown",
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

nonisolated enum UserManagementError: LocalizedError, Sendable {
    case unauthorized
    case noSlotsRemaining

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Only admins can manage users."
        case .noSlotsRemaining: "You have used all available user slots. Upgrade your plan to add more users."
        }
    }
}
