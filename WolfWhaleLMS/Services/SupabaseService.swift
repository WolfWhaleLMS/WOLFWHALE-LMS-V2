import Foundation
import Supabase

nonisolated(unsafe) let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: Config.SUPABASE_URL.isEmpty ? "https://placeholder.supabase.co" : Config.SUPABASE_URL)!,
    supabaseKey: Config.SUPABASE_ANON_KEY
)

struct DataService {
    static let shared = DataService()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str) ?? dateFormatter.date(from: str) ?? Date()
    }

    private func formatDate(_ date: Date) -> String {
        iso8601.string(from: date)
    }

    // MARK: - Courses

    func fetchCourses(for userId: UUID, role: UserRole) async throws -> [Course] {
        var courseDTOs: [CourseDTO] = []

        switch role {
        case .student:
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("enrollments")
                .select()
                .eq("student_id", value: userId.uuidString)
                .execute()
                .value
            let courseIds = enrollments.map(\.courseId)
            if !courseIds.isEmpty {
                courseDTOs = try await supabaseClient
                    .from("courses")
                    .select()
                    .in("id", values: courseIds.map(\.uuidString))
                    .execute()
                    .value
            }
        case .teacher:
            courseDTOs = try await supabaseClient
                .from("courses")
                .select()
                .eq("teacher_id", value: userId.uuidString)
                .execute()
                .value
        case .admin, .parent:
            courseDTOs = try await supabaseClient
                .from("courses")
                .select()
                .execute()
                .value
        }

        var courses: [Course] = []
        for dto in courseDTOs {
            let modules = try await fetchModules(for: dto.id, studentId: role == .student ? userId : nil)
            let enrollmentCount = try await fetchEnrollmentCount(for: dto.id)
            let teacherName = try await fetchTeacherName(for: dto.teacherId)
            let totalLessons = modules.reduce(0) { $0 + $1.lessons.count }
            let completedLessons = modules.reduce(0) { $0 + $1.lessons.filter(\.isCompleted).count }
            let progress = totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0

            courses.append(Course(
                id: dto.id,
                title: dto.title,
                description: dto.description ?? "",
                teacherName: teacherName,
                iconSystemName: dto.iconSystemName ?? "book.fill",
                colorName: dto.colorName ?? "blue",
                modules: modules,
                enrolledStudentCount: enrollmentCount,
                progress: progress,
                classCode: dto.classCode ?? ""
            ))
        }
        return courses
    }

    private func fetchModules(for courseId: UUID, studentId: UUID?) async throws -> [Module] {
        let moduleDTOs: [ModuleDTO] = try await supabaseClient
            .from("modules")
            .select()
            .eq("course_id", value: courseId.uuidString)
            .order("order_index")
            .execute()
            .value

        var completedLessonIds: Set<UUID> = []
        if let studentId {
            let completions: [LessonCompletionDTO] = try await supabaseClient
                .from("lesson_completions")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .execute()
                .value
            completedLessonIds = Set(completions.map(\.lessonId))
        }

        var modules: [Module] = []
        for mDto in moduleDTOs {
            let lessonDTOs: [LessonDTO] = try await supabaseClient
                .from("lessons")
                .select()
                .eq("module_id", value: mDto.id.uuidString)
                .order("order_index")
                .execute()
                .value

            let lessons = lessonDTOs.map { l in
                Lesson(
                    id: l.id,
                    title: l.title,
                    content: l.content ?? "",
                    duration: l.duration ?? 15,
                    isCompleted: completedLessonIds.contains(l.id),
                    type: LessonType(rawValue: l.type ?? "Reading") ?? .reading,
                    xpReward: l.xpReward ?? 25
                )
            }
            modules.append(Module(
                id: mDto.id,
                title: mDto.title,
                lessons: lessons,
                orderIndex: mDto.orderIndex ?? 0
            ))
        }
        return modules
    }

    private func fetchEnrollmentCount(for courseId: UUID) async throws -> Int {
        let enrollments: [EnrollmentDTO] = try await supabaseClient
            .from("enrollments")
            .select()
            .eq("course_id", value: courseId.uuidString)
            .execute()
            .value
        return enrollments.count
    }

    private func fetchTeacherName(for teacherId: UUID?) async throws -> String {
        guard let teacherId else { return "Unknown" }
        do {
            let profile: ProfileDTO = try await supabaseClient
                .from("profiles")
                .select()
                .eq("id", value: teacherId.uuidString)
                .single()
                .execute()
                .value
            return "\(profile.firstName) \(profile.lastName)"
        } catch {
            return "Unknown"
        }
    }

    func createCourse(_ dto: InsertCourseDTO) async throws -> CourseDTO {
        let result: CourseDTO = try await supabaseClient
            .from("courses")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    // MARK: - Assignments

    func fetchAssignments(for userId: UUID, role: UserRole, courseIds: [UUID]) async throws -> [Assignment] {
        var assignmentDTOs: [AssignmentDTO] = []

        if courseIds.isEmpty {
            return []
        }

        assignmentDTOs = try await supabaseClient
            .from("assignments")
            .select()
            .in("course_id", values: courseIds.map(\.uuidString))
            .order("due_date")
            .execute()
            .value

        var courseNames: [UUID: String] = [:]
        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .in("id", values: courseIds.map(\.uuidString))
            .execute()
            .value
        for c in courseDTOs {
            courseNames[c.id] = c.title
        }

        var submissions: [UUID: SubmissionDTO] = [:]
        if role == .student {
            let subs: [SubmissionDTO] = try await supabaseClient
                .from("submissions")
                .select()
                .eq("student_id", value: userId.uuidString)
                .execute()
                .value
            for s in subs {
                submissions[s.assignmentId] = s
            }
        }

        return assignmentDTOs.map { dto in
            let sub = submissions[dto.id]
            return Assignment(
                id: dto.id,
                title: dto.title,
                courseId: dto.courseId,
                courseName: courseNames[dto.courseId] ?? "Unknown",
                instructions: dto.instructions ?? "",
                dueDate: parseDate(dto.dueDate),
                points: dto.points ?? 100,
                isSubmitted: sub != nil,
                submission: sub?.content,
                grade: sub?.grade,
                feedback: sub?.feedback,
                xpReward: dto.xpReward ?? 50
            )
        }
    }

    func createAssignment(_ dto: InsertAssignmentDTO) async throws {
        try await supabaseClient
            .from("assignments")
            .insert(dto)
            .execute()
    }

    func submitAssignment(assignmentId: UUID, studentId: UUID, content: String) async throws {
        let dto = InsertSubmissionDTO(assignmentId: assignmentId, studentId: studentId, content: content)
        try await supabaseClient
            .from("submissions")
            .insert(dto)
            .execute()
    }

    // MARK: - Quizzes

    func fetchQuizzes(for userId: UUID, courseIds: [UUID]) async throws -> [Quiz] {
        if courseIds.isEmpty { return [] }

        let quizDTOs: [QuizDTO] = try await supabaseClient
            .from("quizzes")
            .select()
            .in("course_id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        var courseNames: [UUID: String] = [:]
        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .in("id", values: courseIds.map(\.uuidString))
            .execute()
            .value
        for c in courseDTOs { courseNames[c.id] = c.title }

        let attempts: [QuizAttemptDTO] = try await supabaseClient
            .from("quiz_attempts")
            .select()
            .eq("student_id", value: userId.uuidString)
            .execute()
            .value
        var attemptMap: [UUID: QuizAttemptDTO] = [:]
        for a in attempts { attemptMap[a.quizId] = a }

        var quizzes: [Quiz] = []
        for dto in quizDTOs {
            let questionDTOs: [QuizQuestionDTO] = try await supabaseClient
                .from("quiz_questions")
                .select()
                .eq("quiz_id", value: dto.id.uuidString)
                .execute()
                .value

            let questions = questionDTOs.map { q in
                QuizQuestion(
                    id: q.id,
                    text: q.text,
                    options: q.options ?? [],
                    correctIndex: q.correctIndex ?? 0
                )
            }

            let attempt = attemptMap[dto.id]
            quizzes.append(Quiz(
                id: dto.id,
                title: dto.title,
                courseId: dto.courseId,
                courseName: courseNames[dto.courseId] ?? "Unknown",
                questions: questions,
                timeLimit: dto.timeLimit ?? 30,
                dueDate: parseDate(dto.dueDate),
                isCompleted: attempt != nil,
                score: attempt?.score,
                xpReward: dto.xpReward ?? 100
            ))
        }
        return quizzes
    }

    func submitQuizAttempt(quizId: UUID, studentId: UUID, score: Double) async throws {
        let dto = InsertQuizAttemptDTO(quizId: quizId, studentId: studentId, score: score)
        try await supabaseClient
            .from("quiz_attempts")
            .insert(dto)
            .execute()
    }

    // MARK: - Grades

    func fetchGrades(for studentId: UUID, courseIds: [UUID]) async throws -> [GradeEntry] {
        if courseIds.isEmpty { return [] }

        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .in("id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        var gradeEntries: [GradeEntry] = []
        for course in courseDTOs {
            let gradeDTOs: [GradeDTO] = try await supabaseClient
                .from("grades")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .eq("course_id", value: course.id.uuidString)
                .execute()
                .value

            if gradeDTOs.isEmpty { continue }

            let assignmentGrades = gradeDTOs.map { g in
                AssignmentGrade(
                    id: g.id,
                    title: g.title ?? "Assignment",
                    score: g.score ?? 0,
                    maxScore: g.maxScore ?? 100,
                    date: parseDate(g.gradedAt),
                    type: g.type ?? "Assignment"
                )
            }

            let avg = assignmentGrades.isEmpty ? 0 :
                assignmentGrades.reduce(0.0) { $0 + ($1.score / $1.maxScore * 100) } / Double(assignmentGrades.count)

            let letter = letterGrade(for: avg)

            gradeEntries.append(GradeEntry(
                id: course.id,
                courseId: course.id,
                courseName: course.title,
                courseIcon: course.iconSystemName ?? "book.fill",
                courseColor: course.colorName ?? "blue",
                letterGrade: letter,
                numericGrade: avg,
                assignmentGrades: assignmentGrades
            ))
        }
        return gradeEntries
    }

    private func letterGrade(for score: Double) -> String {
        switch score {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 60..<67: return "D"
        default: return "F"
        }
    }

    // MARK: - Announcements

    func fetchAnnouncements(tenantId: UUID? = nil) async throws -> [Announcement] {
        let dtos: [AnnouncementDTO]
        if let tenantId {
            dtos = try await supabaseClient
                .from("announcements")
                .select()
                .eq("tenant_id", value: tenantId.uuidString)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
        } else {
            dtos = try await supabaseClient
                .from("announcements")
                .select()
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
        }

        return dtos.map { dto in
            Announcement(
                id: dto.id,
                title: dto.title,
                content: dto.content ?? "",
                authorName: dto.authorName ?? "Admin",
                date: parseDate(dto.createdAt),
                isPinned: dto.isPinned ?? false
            )
        }
    }

    func createAnnouncement(_ dto: InsertAnnouncementDTO) async throws {
        try await supabaseClient
            .from("announcements")
            .insert(dto)
            .execute()
    }

    // MARK: - Conversations & Messages

    func fetchConversations(for userId: UUID) async throws -> [Conversation] {
        let participants: [ConversationParticipantDTO] = try await supabaseClient
            .from("conversation_participants")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let conversationIds = participants.map(\.conversationId)
        if conversationIds.isEmpty { return [] }

        var unreadMap: [UUID: Int] = [:]
        for p in participants { unreadMap[p.conversationId] = p.unreadCount ?? 0 }

        let convDTOs: [ConversationDTO] = try await supabaseClient
            .from("conversations")
            .select()
            .in("id", values: conversationIds.map(\.uuidString))
            .execute()
            .value

        var conversations: [Conversation] = []
        for conv in convDTOs {
            let messageDTOs: [MessageDTO] = try await supabaseClient
                .from("messages")
                .select()
                .eq("conversation_id", value: conv.id.uuidString)
                .order("created_at")
                .limit(50)
                .execute()
                .value

            let messages = messageDTOs.map { m in
                ChatMessage(
                    id: m.id,
                    senderName: m.senderName ?? "Unknown",
                    content: m.content,
                    timestamp: parseDate(m.createdAt),
                    isFromCurrentUser: m.senderId == userId
                )
            }

            let allParticipants: [ConversationParticipantDTO] = try await supabaseClient
                .from("conversation_participants")
                .select()
                .eq("conversation_id", value: conv.id.uuidString)
                .execute()
                .value

            let otherCount = allParticipants.filter { $0.userId != userId }.count

            conversations.append(Conversation(
                id: conv.id,
                participantNames: [],
                title: conv.title ?? "Conversation",
                lastMessage: messages.last?.content ?? "",
                lastMessageDate: messages.last?.timestamp ?? parseDate(conv.createdAt),
                unreadCount: unreadMap[conv.id] ?? 0,
                messages: messages,
                avatarSystemName: otherCount > 1 ? "person.3.fill" : "person.crop.circle.fill"
            ))
        }

        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    func sendMessage(conversationId: UUID, senderId: UUID, senderName: String, content: String) async throws {
        let dto = InsertMessageDTO(conversationId: conversationId, senderId: senderId, senderName: senderName, content: content)
        try await supabaseClient
            .from("messages")
            .insert(dto)
            .execute()
    }

    // MARK: - Achievements

    func fetchAchievements(for studentId: UUID) async throws -> [Achievement] {
        let allAchievements: [AchievementDTO] = try await supabaseClient
            .from("achievements")
            .select()
            .execute()
            .value

        let unlocked: [StudentAchievementDTO] = try await supabaseClient
            .from("student_achievements")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .execute()
            .value

        let unlockedIds = Set(unlocked.map(\.achievementId))
        var unlockedDates: [UUID: Date] = [:]
        for u in unlocked {
            unlockedDates[u.achievementId] = parseDate(u.unlockedAt)
        }

        return allAchievements.map { dto in
            Achievement(
                id: dto.id,
                title: dto.title,
                description: dto.description ?? "",
                iconSystemName: dto.iconSystemName ?? "star.fill",
                isUnlocked: unlockedIds.contains(dto.id),
                unlockedDate: unlockedDates[dto.id],
                xpReward: dto.xpReward ?? 50,
                rarity: AchievementRarity(rawValue: dto.rarity ?? "Common") ?? .common
            )
        }
    }

    // MARK: - Leaderboard

    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        let profiles: [ProfileDTO] = try await supabaseClient
            .from("profiles")
            .select()
            .eq("role", value: "Student")
            .order("xp", ascending: false)
            .limit(20)
            .execute()
            .value

        return profiles.enumerated().map { index, p in
            LeaderboardEntry(
                id: p.id,
                userName: "\(p.firstName) \(p.lastName)",
                xp: p.xp,
                level: p.level,
                rank: index + 1,
                avatarSystemName: "person.crop.circle.fill"
            )
        }
    }

    // MARK: - Attendance

    func fetchAttendance(for studentId: UUID) async throws -> [AttendanceRecord] {
        let dtos: [AttendanceDTO] = try await supabaseClient
            .from("attendance")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .order("date", ascending: false)
            .limit(30)
            .execute()
            .value

        return dtos.map { dto in
            AttendanceRecord(
                id: dto.id,
                date: parseDate(dto.date),
                status: AttendanceStatus(rawValue: dto.status) ?? .present,
                courseName: dto.courseName ?? "All Classes",
                studentName: nil
            )
        }
    }

    // MARK: - Lesson Completion

    func completeLesson(studentId: UUID, lessonId: UUID) async throws {
        let dto = InsertLessonCompletionDTO(studentId: studentId, lessonId: lessonId)
        try await supabaseClient
            .from("lesson_completions")
            .insert(dto)
            .execute()
    }

    // MARK: - Admin: Users

    func fetchAllUsers(schoolId: String?) async throws -> [ProfileDTO] {
        let profiles: [ProfileDTO]
        if let schoolId {
            profiles = try await supabaseClient
                .from("profiles")
                .select()
                .eq("school_id", value: schoolId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            profiles = try await supabaseClient
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return profiles
    }

    func deleteUser(userId: UUID) async throws {
        try await supabaseClient
            .from("profiles")
            .delete()
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Admin: School Metrics

    func fetchSchoolMetrics(schoolId: String?) async throws -> SchoolMetrics {
        let profiles = try await fetchAllUsers(schoolId: schoolId)
        let students = profiles.filter { $0.role == "Student" }.count
        let teachers = profiles.filter { $0.role == "Teacher" }.count
        let active = profiles.count

        let courses: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .execute()
            .value

        return SchoolMetrics(
            totalStudents: students,
            totalTeachers: teachers,
            totalCourses: courses.count,
            averageAttendance: 0.94,
            averageGPA: 3.2,
            activeUsers: active
        )
    }

    // MARK: - Parent: Children

    func fetchChildren(for parentId: UUID) async throws -> [ChildInfo] {
        let links: [ParentChildDTO] = try await supabaseClient
            .from("parent_child_links")
            .select()
            .eq("parent_id", value: parentId.uuidString)
            .execute()
            .value

        var children: [ChildInfo] = []
        for link in links {
            do {
                let profile: ProfileDTO = try await supabaseClient
                    .from("profiles")
                    .select()
                    .eq("id", value: link.childId.uuidString)
                    .single()
                    .execute()
                    .value

                let enrollments: [EnrollmentDTO] = try await supabaseClient
                    .from("enrollments")
                    .select()
                    .eq("student_id", value: link.childId.uuidString)
                    .execute()
                    .value
                let courseIds = enrollments.map(\.courseId)

                let grades = try await fetchGrades(for: link.childId, courseIds: courseIds)
                let assignments = try await fetchAssignments(for: link.childId, role: .student, courseIds: courseIds)

                let avg = grades.isEmpty ? 0 : grades.reduce(0.0) { $0 + $1.numericGrade } / Double(grades.count)
                let gpa = avg / 100.0 * 4.0

                children.append(ChildInfo(
                    id: link.childId,
                    name: "\(profile.firstName) \(profile.lastName)",
                    grade: "Student",
                    avatarSystemName: "person.crop.circle.fill",
                    gpa: gpa,
                    attendanceRate: 0.96,
                    courses: grades,
                    recentAssignments: Array(assignments.filter { !$0.isSubmitted }.prefix(3))
                ))
            } catch {
                continue
            }
        }
        return children
    }

    // MARK: - Profile

    func updateProfile(userId: UUID, update: UpdateProfileDTO) async throws {
        try await supabaseClient
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
