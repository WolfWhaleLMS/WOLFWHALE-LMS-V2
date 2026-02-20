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

    var isDemoMode = false
    private let mockService = MockDataService.shared
    private let dataService = DataService.shared

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
            do {
                let session = try await supabaseClient.auth.session
                try await fetchProfile(userId: session.user.id)
                await loadData()
                isAuthenticated = true
            } catch {
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

    private func fetchProfile(userId: UUID) async throws {
        let profile: ProfileDTO = try await supabaseClient
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        currentUser = profile.toUser()
    }

    func syncProfile() {
        guard let user = currentUser, !isDemoMode else { return }
        Task {
            let update = UpdateProfileDTO(
                xp: user.xp,
                level: user.level,
                coins: user.coins,
                streak: user.streak
            )
            try? await dataService.updateProfile(userId: user.id, update: update)
        }
    }

    func loadData() async {
        guard let user = currentUser else { return }
        if isDemoMode {
            loadMockData()
            return
        }

        dataError = nil

        do {
            courses = try await dataService.fetchCourses(for: user.id, role: user.role)
            let courseIds = courses.map(\.id)

            async let assignmentsTask = dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
            async let announcementsTask = dataService.fetchAnnouncements()
            async let conversationsTask = dataService.fetchConversations(for: user.id)

            assignments = try await assignmentsTask
            announcements = try await announcementsTask
            conversations = try await conversationsTask

            switch user.role {
            case .student:
                async let quizzesTask = dataService.fetchQuizzes(for: user.id, courseIds: courseIds)
                async let gradesTask = dataService.fetchGrades(for: user.id, courseIds: courseIds)
                async let attendanceTask = dataService.fetchAttendance(for: user.id)
                async let achievementsTask = dataService.fetchAchievements(for: user.id)
                async let leaderboardTask = dataService.fetchLeaderboard()

                quizzes = try await quizzesTask
                grades = try await gradesTask
                attendance = try await attendanceTask
                achievements = try await achievementsTask
                leaderboard = try await leaderboardTask

            case .teacher:
                break

            case .parent:
                children = try await dataService.fetchChildren(for: user.id)

            case .admin:
                allUsers = try await dataService.fetchAllUsers(schoolId: user.schoolId)
                schoolMetrics = try await dataService.fetchSchoolMetrics(schoolId: user.schoolId)
            }
        } catch {
            dataError = "Could not load data. Using offline mode."
            loadMockData()
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
    }

    func refreshData() {
        Task {
            await loadData()
        }
    }

    // MARK: - Admin: Create User
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
        guard remainingUserSlots > 0 else {
            throw UserManagementError.noSlotsRemaining
        }

        let result = try await supabaseClient.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(firstName.trimmingCharacters(in: .whitespaces)),
                "last_name": .string(lastName.trimmingCharacters(in: .whitespaces)),
                "role": .string(role.rawValue)
            ]
        )

        let newProfile = InsertProfileDTO(
            id: result.user.id,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email,
            role: role.rawValue,
            schoolId: admin.schoolId
        )
        try await supabaseClient
            .from("profiles")
            .insert(newProfile)
            .execute()

        let slotUpdate = UpdateSlotsDTO(userSlotsUsed: admin.userSlotsUsed + 1)
        try await supabaseClient
            .from("profiles")
            .update(slotUpdate)
            .eq("id", value: admin.id.uuidString)
            .execute()

        currentUser?.userSlotsUsed += 1
        allUsers = try await dataService.fetchAllUsers(schoolId: admin.schoolId)
    }

    func deleteUser(userId: UUID) async throws {
        guard let admin = currentUser, admin.role == .admin else {
            throw UserManagementError.unauthorized
        }
        try await dataService.deleteUser(userId: userId)
        allUsers.removeAll { $0.id == userId }
        if currentUser!.userSlotsUsed > 0 {
            currentUser?.userSlotsUsed -= 1
            let slotUpdate = UpdateSlotsDTO(userSlotsUsed: currentUser!.userSlotsUsed)
            try? await supabaseClient
                .from("profiles")
                .update(slotUpdate)
                .eq("id", value: admin.id.uuidString)
                .execute()
        }
    }

    // MARK: - Teacher: Create Course
    func createCourse(title: String, description: String, colorName: String) async throws {
        guard let user = currentUser else { return }
        let classCode = "\(title.prefix(4).uppercased())-\(Int.random(in: 1000...9999))"
        let dto = InsertCourseDTO(
            title: title,
            description: description,
            teacherId: user.id,
            iconSystemName: "book.fill",
            colorName: colorName,
            classCode: classCode,
            tenantId: nil
        )
        if !isDemoMode {
            _ = try await dataService.createCourse(dto)
            courses = try await dataService.fetchCourses(for: user.id, role: user.role)
        } else {
            let newCourse = Course(
                id: UUID(), title: title, description: description,
                teacherName: user.fullName, iconSystemName: "book.fill",
                colorName: colorName, modules: [], enrolledStudentCount: 0,
                progress: 0, classCode: classCode
            )
            courses.append(newCourse)
        }
    }

    // MARK: - Teacher: Create Assignment
    func createAssignment(courseId: UUID, title: String, instructions: String, dueDate: Date, points: Int) async throws {
        guard let user = currentUser else { return }
        let xpReward = points / 2

        if !isDemoMode {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dto = InsertAssignmentDTO(
                courseId: courseId,
                title: title,
                instructions: instructions,
                dueDate: formatter.string(from: dueDate),
                points: points,
                xpReward: xpReward
            )
            try await dataService.createAssignment(dto)
            let courseIds = courses.map(\.id)
            assignments = try await dataService.fetchAssignments(for: user.id, role: user.role, courseIds: courseIds)
        } else {
            let courseName = courses.first(where: { $0.id == courseId })?.title ?? "Unknown"
            let newAssignment = Assignment(
                id: UUID(), title: title, courseId: courseId, courseName: courseName,
                instructions: instructions, dueDate: dueDate, points: points,
                isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: xpReward
            )
            assignments.append(newAssignment)
        }
    }

    // MARK: - Create Announcement
    func createAnnouncement(title: String, content: String, isPinned: Bool) async throws {
        guard let user = currentUser else { return }

        if !isDemoMode {
            let dto = InsertAnnouncementDTO(
                title: title,
                content: content,
                authorId: user.id,
                authorName: user.fullName,
                isPinned: isPinned,
                tenantId: nil
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
                currentUser?.xp += lesson.xpReward
                currentUser?.coins += lesson.xpReward / 5

                if !isDemoMode, let user = currentUser {
                    Task {
                        try? await dataService.completeLesson(studentId: user.id, lessonId: lesson.id)
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
        currentUser?.xp += assignment.xpReward
        currentUser?.coins += assignment.xpReward / 5

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
        currentUser?.xp += quiz.xpReward
        currentUser?.coins += quiz.xpReward / 5

        if !isDemoMode, let user = currentUser {
            Task {
                try? await dataService.submitQuizAttempt(quizId: quiz.id, studentId: user.id, score: score)
            }
        }
        syncProfile()
        return score
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
