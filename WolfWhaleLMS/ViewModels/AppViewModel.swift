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
    var gradeError: String?
    var enrollmentError: String?

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
                    "\($0.firstName) \($0.lastName)".localizedStandardContains(name)
                }) {
                    participants.append((userId: match.id, userName: "\(match.firstName) \(match.lastName)"))
                } else {
                    // Create a placeholder participant with a generated UUID
                    participants.append((userId: UUID(), userName: name))
                }
            }

            let convDTO = try await dataService.createConversation(
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
    func gradeSubmission(assignmentId: UUID, score: Double, letterGrade: String, feedback: String?) async throws {
        isLoading = true
        gradeError = nil
        defer { isLoading = false }

        guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
            gradeError = "Assignment not found"
            throw NSError(domain: "AppViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Assignment not found"])
        }

        let maxScore = Double(assignment.points)
        let percentage = maxScore > 0 ? (score / maxScore) * 100 : 0

        if isDemoMode {
            if let index = assignments.firstIndex(where: { $0.id == assignmentId }) {
                assignments[index].grade = percentage
                assignments[index].feedback = feedback
            }
            return
        }

        do {
            try await dataService.gradeSubmission(
                studentId: currentUser?.id ?? UUID(),
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
