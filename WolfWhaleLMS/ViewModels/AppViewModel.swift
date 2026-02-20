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

    private let dataService = MockDataService.shared

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
                loadData()
                isAuthenticated = true
            } catch {
                // No valid session
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
                loadData()
                isAuthenticated = true
            } catch {
                loginError = mapAuthError(error)
            }
            isLoading = false
        }
    }

    var isDemoMode = false

    func loginAsDemo(role: UserRole) {
        isDemoMode = true
        currentUser = dataService.sampleUser(role: role)
        loadData()
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
        guard let user = currentUser else { return }
        Task {
            let update = UpdateProfileDTO(
                xp: user.xp,
                level: user.level,
                coins: user.coins,
                streak: user.streak
            )
            try? await supabaseClient
                .from("profiles")
                .update(update)
                .eq("id", value: user.id.uuidString)
                .execute()
        }
    }

    func loadData() {
        courses = dataService.sampleCourses()
        assignments = dataService.sampleAssignments()
        quizzes = dataService.sampleQuizzes()
        grades = dataService.sampleGrades()
        attendance = dataService.sampleAttendance()
        achievements = dataService.sampleAchievements()
        leaderboard = dataService.sampleLeaderboard()
        conversations = dataService.sampleConversations()
        announcements = dataService.sampleAnnouncements()
        children = dataService.sampleChildren()
        schoolMetrics = dataService.sampleSchoolMetrics()
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
    }

    // MARK: - Student Actions
    func completeLesson(_ lesson: Lesson, in course: Course) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == course.id }) else { return }
        for moduleIndex in courses[courseIndex].modules.indices {
            if let lessonIndex = courses[courseIndex].modules[moduleIndex].lessons.firstIndex(where: { $0.id == lesson.id }) {
                courses[courseIndex].modules[moduleIndex].lessons[lessonIndex].isCompleted = true
                currentUser?.xp += lesson.xpReward
                currentUser?.coins += lesson.xpReward / 5
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
        syncProfile()
        return score
    }

    func sendMessage(in conversationId: UUID, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let message = ChatMessage(id: UUID(), senderName: currentUser?.fullName ?? "You", content: text, timestamp: Date(), isFromCurrentUser: true)
        conversations[index].messages.append(message)
        conversations[index].lastMessage = text
        conversations[index].lastMessageDate = Date()
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
        case .unauthorized: "Only admins can create users."
        case .noSlotsRemaining: "You have used all available user slots. Upgrade your plan to add more users."
        }
    }
}
