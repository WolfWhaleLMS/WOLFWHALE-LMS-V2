import Foundation
import Supabase

nonisolated(unsafe) let supabaseClient: SupabaseClient = {
    let urlString = Config.SUPABASE_URL.isEmpty ? "https://placeholder.supabase.co" : Config.SUPABASE_URL
    guard let url = URL(string: urlString) else {
        fatalError("Invalid Supabase URL: \(urlString). Check Config.SUPABASE_URL.")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: Config.SUPABASE_ANON_KEY)
}()

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
                .limit(100)
                .execute()
                .value
        }

        if courseDTOs.isEmpty { return [] }

        let allCourseIds = courseDTOs.map(\.id)

        // --- Batch fetch all modules for all courses at once ---
        let allModuleDTOs: [ModuleDTO] = try await supabaseClient
            .from("modules")
            .select()
            .in("course_id", values: allCourseIds.map(\.uuidString))
            .order("order_index")
            .execute()
            .value

        // --- Batch fetch all lessons for all modules at once ---
        let allModuleIds = allModuleDTOs.map(\.id)
        var allLessonDTOs: [LessonDTO] = []
        if !allModuleIds.isEmpty {
            allLessonDTOs = try await supabaseClient
                .from("lessons")
                .select()
                .in("module_id", values: allModuleIds.map(\.uuidString))
                .order("order_index")
                .execute()
                .value
        }

        // --- Batch fetch lesson completions for student role ---
        var completedLessonIds: Set<UUID> = []
        if role == .student {
            let completions: [LessonCompletionDTO] = try await supabaseClient
                .from("lesson_completions")
                .select()
                .eq("student_id", value: userId.uuidString)
                .execute()
                .value
            completedLessonIds = Set(completions.map(\.lessonId))
        }

        // --- Batch fetch enrollment counts for all courses ---
        let allEnrollments: [EnrollmentDTO] = try await supabaseClient
            .from("enrollments")
            .select()
            .in("course_id", values: allCourseIds.map(\.uuidString))
            .execute()
            .value
        var enrollmentCountByCourse: [UUID: Int] = [:]
        for enrollment in allEnrollments {
            enrollmentCountByCourse[enrollment.courseId, default: 0] += 1
        }

        // --- Batch fetch all teacher names ---
        let teacherIds = Array(Set(courseDTOs.compactMap(\.teacherId)))
        var teacherNameMap: [UUID: String] = [:]
        if !teacherIds.isEmpty {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: teacherIds.map(\.uuidString))
                .execute()
                .value
            for p in profiles {
                teacherNameMap[p.id] = "\(p.firstName) \(p.lastName)"
            }
        }

        // --- Group lessons by module ---
        var lessonsByModule: [UUID: [LessonDTO]] = [:]
        for lesson in allLessonDTOs {
            lessonsByModule[lesson.moduleId, default: []].append(lesson)
        }

        // --- Group modules by course ---
        var modulesByCourse: [UUID: [ModuleDTO]] = [:]
        for mod in allModuleDTOs {
            modulesByCourse[mod.courseId, default: []].append(mod)
        }

        // --- Assemble courses from pre-fetched data ---
        var courses: [Course] = []
        for dto in courseDTOs {
            let moduleDTOs = modulesByCourse[dto.id] ?? []
            var modules: [Module] = []
            for mDto in moduleDTOs {
                let lessonDTOs = lessonsByModule[mDto.id] ?? []
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

            let enrollmentCount = enrollmentCountByCourse[dto.id] ?? 0
            let teacherName = dto.teacherId.flatMap { teacherNameMap[$0] } ?? "Unknown"
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

    /// Kept for callers that need modules for a single course (e.g. lesson creation flows).
    private func fetchModules(for courseId: UUID, studentId: UUID?) async throws -> [Module] {
        let moduleDTOs: [ModuleDTO] = try await supabaseClient
            .from("modules")
            .select()
            .eq("course_id", value: courseId.uuidString)
            .order("order_index")
            .execute()
            .value

        let moduleIds = moduleDTOs.map(\.id)

        // Batch fetch all lessons for all modules in this course
        var allLessonDTOs: [LessonDTO] = []
        if !moduleIds.isEmpty {
            allLessonDTOs = try await supabaseClient
                .from("lessons")
                .select()
                .in("module_id", values: moduleIds.map(\.uuidString))
                .order("order_index")
                .execute()
                .value
        }

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

        // Group lessons by module
        var lessonsByModule: [UUID: [LessonDTO]] = [:]
        for lesson in allLessonDTOs {
            lessonsByModule[lesson.moduleId, default: []].append(lesson)
        }

        var modules: [Module] = []
        for mDto in moduleDTOs {
            let lessonDTOs = lessonsByModule[mDto.id] ?? []
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
            .limit(50)
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

        if role == .student {
            // Student: fetch only their own submissions
            var submissions: [UUID: SubmissionDTO] = [:]
            let subs: [SubmissionDTO] = try await supabaseClient
                .from("submissions")
                .select()
                .eq("student_id", value: userId.uuidString)
                .execute()
                .value
            for s in subs {
                submissions[s.assignmentId] = s
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
                    xpReward: dto.xpReward ?? 50,
                    studentId: nil,
                    studentName: nil
                )
            }
        } else {
            // Teacher/Admin/Parent: fetch ALL submissions for these assignments and resolve student names
            let assignmentIds = assignmentDTOs.map(\.id)
            var allSubmissions: [SubmissionDTO] = []
            if !assignmentIds.isEmpty {
                allSubmissions = try await supabaseClient
                    .from("submissions")
                    .select()
                    .in("assignment_id", values: assignmentIds.map(\.uuidString))
                    .execute()
                    .value
            }

            // Resolve student names from profiles
            let studentIds = Array(Set(allSubmissions.map(\.studentId)))
            var studentNames: [UUID: String] = [:]
            if !studentIds.isEmpty {
                let profiles: [ProfileDTO] = try await supabaseClient
                    .from("profiles")
                    .select()
                    .in("id", values: studentIds.map(\.uuidString))
                    .execute()
                    .value
                for p in profiles {
                    studentNames[p.id] = "\(p.firstName) \(p.lastName)"
                }
            }

            // Group submissions by assignment
            var submissionsByAssignment: [UUID: [SubmissionDTO]] = [:]
            for sub in allSubmissions {
                submissionsByAssignment[sub.assignmentId, default: []].append(sub)
            }

            var results: [Assignment] = []
            for dto in assignmentDTOs {
                let subs = submissionsByAssignment[dto.id] ?? []
                if subs.isEmpty {
                    // No submissions yet - show the assignment as unsubmitted
                    results.append(Assignment(
                        id: dto.id,
                        title: dto.title,
                        courseId: dto.courseId,
                        courseName: courseNames[dto.courseId] ?? "Unknown",
                        instructions: dto.instructions ?? "",
                        dueDate: parseDate(dto.dueDate),
                        points: dto.points ?? 100,
                        isSubmitted: false,
                        submission: nil,
                        grade: nil,
                        feedback: nil,
                        xpReward: dto.xpReward ?? 50,
                        studentId: nil,
                        studentName: nil
                    ))
                } else {
                    // One entry per student submission
                    for sub in subs {
                        results.append(Assignment(
                            id: dto.id,
                            title: dto.title,
                            courseId: dto.courseId,
                            courseName: courseNames[dto.courseId] ?? "Unknown",
                            instructions: dto.instructions ?? "",
                            dueDate: parseDate(dto.dueDate),
                            points: dto.points ?? 100,
                            isSubmitted: true,
                            submission: sub.content,
                            grade: sub.grade,
                            feedback: sub.feedback,
                            xpReward: dto.xpReward ?? 50,
                            studentId: sub.studentId,
                            studentName: studentNames[sub.studentId] ?? "Unknown Student"
                        ))
                    }
                }
            }
            return results
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
            .limit(50)
            .execute()
            .value

        if quizDTOs.isEmpty { return [] }

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

        // --- Batch fetch all questions for all quizzes at once ---
        let allQuizIds = quizDTOs.map(\.id)
        let allQuestionDTOs: [QuizQuestionDTO] = try await supabaseClient
            .from("quiz_questions")
            .select()
            .in("quiz_id", values: allQuizIds.map(\.uuidString))
            .execute()
            .value

        // Group questions by quiz
        var questionsByQuiz: [UUID: [QuizQuestionDTO]] = [:]
        for q in allQuestionDTOs {
            questionsByQuiz[q.quizId, default: []].append(q)
        }

        var quizzes: [Quiz] = []
        for dto in quizDTOs {
            let questionDTOs = questionsByQuiz[dto.id] ?? []
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

        // Batch fetch all grades for this student across all courses at once
        let allGradeDTOs: [GradeDTO] = try await supabaseClient
            .from("grades")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .in("course_id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        // Batch fetch all course info at once
        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .in("id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        // Build course lookup
        var courseMap: [UUID: CourseDTO] = [:]
        for c in courseDTOs { courseMap[c.id] = c }

        // Group grades by course
        var gradesByCourse: [UUID: [GradeDTO]] = [:]
        for g in allGradeDTOs {
            gradesByCourse[g.courseId, default: []].append(g)
        }

        var gradeEntries: [GradeEntry] = []
        for course in courseDTOs {
            let gradeDTOs = gradesByCourse[course.id] ?? []
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
            .limit(50)
            .execute()
            .value

        if convDTOs.isEmpty { return [] }

        let convIds = convDTOs.map(\.id)

        // --- Batch fetch all messages for all conversations at once ---
        let allMessageDTOs: [MessageDTO] = try await supabaseClient
            .from("messages")
            .select()
            .in("conversation_id", values: convIds.map(\.uuidString))
            .order("created_at")
            .limit(500)
            .execute()
            .value

        // Group messages by conversation
        var messagesByConv: [UUID: [MessageDTO]] = [:]
        for m in allMessageDTOs {
            messagesByConv[m.conversationId, default: []].append(m)
        }

        // --- Batch fetch all participants for all conversations at once ---
        let allParticipants: [ConversationParticipantDTO] = try await supabaseClient
            .from("conversation_participants")
            .select()
            .in("conversation_id", values: convIds.map(\.uuidString))
            .execute()
            .value

        // Group participants by conversation
        var participantsByConv: [UUID: [ConversationParticipantDTO]] = [:]
        for p in allParticipants {
            participantsByConv[p.conversationId, default: []].append(p)
        }

        var conversations: [Conversation] = []
        for conv in convDTOs {
            let messageDTOs = messagesByConv[conv.id] ?? []
            let messages = messageDTOs.map { m in
                ChatMessage(
                    id: m.id,
                    senderName: m.senderName ?? "Unknown",
                    content: m.content,
                    timestamp: parseDate(m.createdAt),
                    isFromCurrentUser: m.senderId == userId
                )
            }

            let convParticipants = participantsByConv[conv.id] ?? []
            let otherCount = convParticipants.filter { $0.userId != userId }.count

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
            .limit(100)
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
            .limit(50)
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
                .limit(100)
                .execute()
                .value
        } else {
            profiles = try await supabaseClient
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .limit(100)
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
            .limit(100)
            .execute()
            .value

        let attendanceRate = try await calculateRealAttendanceRate(courseId: nil)

        // --- Batch-compute average GPA: fetch all enrollments and grades at once ---
        let studentProfiles = profiles.filter { $0.role == "Student" }
        let studentIds = studentProfiles.map(\.id)

        var averageGPA = 0.0
        if !studentIds.isEmpty {
            // Batch fetch all enrollments for all students
            let allEnrollments: [EnrollmentDTO] = try await supabaseClient
                .from("enrollments")
                .select()
                .in("student_id", values: studentIds.map(\.uuidString))
                .execute()
                .value

            // Get unique course IDs from enrollments
            let allCourseIds = Array(Set(allEnrollments.map(\.courseId)))

            if !allCourseIds.isEmpty {
                // Batch fetch all grades for all students across all courses
                let allGrades: [GradeDTO] = try await supabaseClient
                    .from("grades")
                    .select()
                    .in("student_id", values: studentIds.map(\.uuidString))
                    .in("course_id", values: allCourseIds.map(\.uuidString))
                    .execute()
                    .value

                // Batch fetch all course info for GPA calculation
                let allCourseDTOs: [CourseDTO] = try await supabaseClient
                    .from("courses")
                    .select()
                    .in("id", values: allCourseIds.map(\.uuidString))
                    .execute()
                    .value
                var courseInfoMap: [UUID: CourseDTO] = [:]
                for c in allCourseDTOs { courseInfoMap[c.id] = c }

                // Group enrollments by student
                var enrollmentsByStudent: [UUID: [EnrollmentDTO]] = [:]
                for e in allEnrollments {
                    enrollmentsByStudent[e.studentId, default: []].append(e)
                }

                // Group grades by (studentId, courseId)
                var gradesByStudentCourse: [UUID: [UUID: [GradeDTO]]] = [:]
                for g in allGrades {
                    gradesByStudentCourse[g.studentId, default: [:]][g.courseId, default: []].append(g)
                }

                // Compute per-student GPA
                var totalGPA = 0.0
                var gpaCount = 0
                for student in studentProfiles {
                    let studentEnrollments = enrollmentsByStudent[student.id] ?? []
                    let studentCourseIds = studentEnrollments.map(\.courseId)
                    if studentCourseIds.isEmpty { continue }

                    var courseAverages: [Double] = []
                    for courseId in studentCourseIds {
                        let courseGrades = gradesByStudentCourse[student.id]?[courseId] ?? []
                        if courseGrades.isEmpty { continue }

                        let assignmentGrades = courseGrades.map { g -> Double in
                            let score = g.score ?? 0
                            let maxScore = g.maxScore ?? 100
                            return maxScore > 0 ? (score / maxScore * 100) : 0
                        }
                        let avg = assignmentGrades.reduce(0.0, +) / Double(assignmentGrades.count)
                        courseAverages.append(avg)
                    }

                    if courseAverages.isEmpty { continue }
                    let studentAvg = courseAverages.reduce(0.0, +) / Double(courseAverages.count)
                    totalGPA += studentAvg / 100.0 * 4.0
                    gpaCount += 1
                }
                averageGPA = gpaCount > 0 ? totalGPA / Double(gpaCount) : 0.0
            }
        }

        return SchoolMetrics(
            totalStudents: students,
            totalTeachers: teachers,
            totalCourses: courses.count,
            averageAttendance: attendanceRate,
            averageGPA: averageGPA,
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

        if links.isEmpty { return [] }

        let childIds = links.map(\.childId)

        // --- Batch fetch all child profiles at once ---
        let childProfiles: [ProfileDTO] = try await supabaseClient
            .from("profiles")
            .select()
            .in("id", values: childIds.map(\.uuidString))
            .execute()
            .value
        var profileMap: [UUID: ProfileDTO] = [:]
        for p in childProfiles { profileMap[p.id] = p }

        // --- Batch fetch all enrollments for all children at once ---
        let allEnrollments: [EnrollmentDTO] = try await supabaseClient
            .from("enrollments")
            .select()
            .in("student_id", values: childIds.map(\.uuidString))
            .execute()
            .value

        // Group enrollments by student
        var enrollmentsByChild: [UUID: [EnrollmentDTO]] = [:]
        for e in allEnrollments {
            enrollmentsByChild[e.studentId, default: []].append(e)
        }

        // Collect all unique course IDs across all children
        let allCourseIds = Array(Set(allEnrollments.map(\.courseId)))

        // --- Batch fetch all grades for all children across all courses ---
        var allGrades: [GradeDTO] = []
        if !allCourseIds.isEmpty {
            allGrades = try await supabaseClient
                .from("grades")
                .select()
                .in("student_id", values: childIds.map(\.uuidString))
                .in("course_id", values: allCourseIds.map(\.uuidString))
                .execute()
                .value
        }

        // Group grades by (studentId, courseId)
        var gradesByStudentCourse: [UUID: [UUID: [GradeDTO]]] = [:]
        for g in allGrades {
            gradesByStudentCourse[g.studentId, default: [:]][g.courseId, default: []].append(g)
        }

        // --- Batch fetch all course info ---
        var courseMap: [UUID: CourseDTO] = [:]
        if !allCourseIds.isEmpty {
            let allCourseDTOs: [CourseDTO] = try await supabaseClient
                .from("courses")
                .select()
                .in("id", values: allCourseIds.map(\.uuidString))
                .execute()
                .value
            for c in allCourseDTOs { courseMap[c.id] = c }
        }

        // --- Batch fetch all assignments for all courses ---
        var allAssignmentDTOs: [AssignmentDTO] = []
        if !allCourseIds.isEmpty {
            allAssignmentDTOs = try await supabaseClient
                .from("assignments")
                .select()
                .in("course_id", values: allCourseIds.map(\.uuidString))
                .order("due_date")
                .limit(100)
                .execute()
                .value
        }

        // --- Batch fetch all submissions for all children ---
        var allSubmissions: [SubmissionDTO] = []
        if !childIds.isEmpty {
            allSubmissions = try await supabaseClient
                .from("submissions")
                .select()
                .in("student_id", values: childIds.map(\.uuidString))
                .execute()
                .value
        }
        // Group submissions by studentId -> assignmentId
        var submissionsByStudent: [UUID: [UUID: SubmissionDTO]] = [:]
        for s in allSubmissions {
            submissionsByStudent[s.studentId, default: [:]][s.assignmentId] = s
        }

        // Group assignments by courseId
        var assignmentsByCourse: [UUID: [AssignmentDTO]] = [:]
        for a in allAssignmentDTOs {
            assignmentsByCourse[a.courseId, default: []].append(a)
        }

        // --- Batch fetch all attendance for all children ---
        let allAttendance: [AttendanceDTO] = try await supabaseClient
            .from("attendance")
            .select()
            .in("student_id", values: childIds.map(\.uuidString))
            .limit(500)
            .execute()
            .value
        // Group attendance by student
        var attendanceByChild: [UUID: [AttendanceDTO]] = [:]
        for a in allAttendance {
            attendanceByChild[a.studentId, default: []].append(a)
        }

        // --- Assemble child info from pre-fetched data ---
        var children: [ChildInfo] = []
        for link in links {
            guard let profile = profileMap[link.childId] else { continue }

            let childEnrollments = enrollmentsByChild[link.childId] ?? []
            let childCourseIds = childEnrollments.map(\.courseId)

            // Build grade entries for this child
            var gradeEntries: [GradeEntry] = []
            for courseId in childCourseIds {
                guard let course = courseMap[courseId] else { continue }
                let gradeDTOs = gradesByStudentCourse[link.childId]?[courseId] ?? []
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

            // Build assignment list for this child
            let childSubmissions = submissionsByStudent[link.childId] ?? [:]
            var childAssignments: [Assignment] = []
            for courseId in childCourseIds {
                let courseName = courseMap[courseId]?.title ?? "Unknown"
                let dtos = assignmentsByCourse[courseId] ?? []
                for dto in dtos {
                    let sub = childSubmissions[dto.id]
                    childAssignments.append(Assignment(
                        id: dto.id,
                        title: dto.title,
                        courseId: dto.courseId,
                        courseName: courseName,
                        instructions: dto.instructions ?? "",
                        dueDate: parseDate(dto.dueDate),
                        points: dto.points ?? 100,
                        isSubmitted: sub != nil,
                        submission: sub?.content,
                        grade: sub?.grade,
                        feedback: sub?.feedback,
                        xpReward: dto.xpReward ?? 50,
                        studentId: nil,
                        studentName: nil
                    ))
                }
            }

            let avg = gradeEntries.isEmpty ? 0 : gradeEntries.reduce(0.0) { $0 + $1.numericGrade } / Double(gradeEntries.count)
            let gpa = avg / 100.0 * 4.0

            let childAttendance = attendanceByChild[link.childId] ?? []
            let presentCount = childAttendance.filter { $0.status.lowercased() == "present" }.count
            let totalCount = childAttendance.count
            let attendanceRate = totalCount > 0 ? Double(presentCount) / Double(totalCount) : 0.0

            children.append(ChildInfo(
                id: link.childId,
                name: "\(profile.firstName) \(profile.lastName)",
                grade: "Student",
                avatarSystemName: "person.crop.circle.fill",
                gpa: gpa,
                attendanceRate: attendanceRate,
                courses: gradeEntries,
                recentAssignments: Array(childAssignments.filter { !$0.isSubmitted }.prefix(3))
            ))
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

    func resetPassword(email: String) async throws {
        try await supabaseClient.auth.resetPasswordForEmail(email)
    }

    // MARK: - Grades (Create)

    func gradeSubmission(studentId: UUID, courseId: UUID, assignmentId: UUID, score: Double, maxScore: Double, letterGrade: String, feedback: String) async throws {
        let dto = InsertGradeDTO(
            studentId: studentId,
            courseId: courseId,
            assignmentId: assignmentId,
            score: score,
            maxScore: maxScore,
            letterGrade: letterGrade,
            feedback: feedback,
            gradedAt: formatDate(Date())
        )
        try await supabaseClient
            .from("grades")
            .insert(dto)
            .execute()
    }

    // MARK: - Quizzes (Create)

    func createQuiz(courseId: UUID, title: String, timeLimit: Int, dueDate: String, xpReward: Int) async throws -> QuizDTO {
        let dto = InsertQuizDTO(
            courseId: courseId,
            title: title,
            timeLimit: timeLimit,
            dueDate: dueDate,
            xpReward: xpReward
        )
        let result: QuizDTO = try await supabaseClient
            .from("quizzes")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func createQuizQuestion(quizId: UUID, text: String, options: [String], correctIndex: Int) async throws {
        let dto = InsertQuizQuestionDTO(
            quizId: quizId,
            text: text,
            options: options,
            correctIndex: correctIndex
        )
        try await supabaseClient
            .from("quiz_questions")
            .insert(dto)
            .execute()
    }

    // MARK: - Lessons (Create)

    func createLesson(moduleId: UUID, title: String, content: String, duration: Int, type: String, xpReward: Int, orderIndex: Int) async throws -> LessonDTO {
        let dto = InsertLessonDTO(
            moduleId: moduleId,
            title: title,
            content: content,
            duration: duration,
            type: type,
            xpReward: xpReward,
            orderIndex: orderIndex
        )
        let result: LessonDTO = try await supabaseClient
            .from("lessons")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    // MARK: - Modules (Create)

    func createModule(courseId: UUID, title: String, orderIndex: Int) async throws -> ModuleDTO {
        let dto = InsertModuleDTO(
            courseId: courseId,
            title: title,
            orderIndex: orderIndex
        )
        let result: ModuleDTO = try await supabaseClient
            .from("modules")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    // MARK: - Enrollments

    func enrollStudent(studentId: UUID, courseId: UUID) async throws {
        let dto = InsertEnrollmentDTO(
            studentId: studentId,
            courseId: courseId,
            enrolledAt: formatDate(Date())
        )
        try await supabaseClient
            .from("enrollments")
            .insert(dto)
            .execute()
    }

    func enrollByClassCode(studentId: UUID, classCode: String) async throws -> String {
        let courses: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .eq("class_code", value: classCode)
            .limit(1)
            .execute()
            .value

        guard let course = courses.first else {
            throw EnrollmentError.invalidClassCode
        }

        // Check if already enrolled
        let existing: [EnrollmentDTO] = try await supabaseClient
            .from("enrollments")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .eq("course_id", value: course.id.uuidString)
            .execute()
            .value

        if !existing.isEmpty {
            throw EnrollmentError.alreadyEnrolled
        }

        try await enrollStudent(studentId: studentId, courseId: course.id)
        return course.title
    }

    // MARK: - Attendance (Create)

    func takeAttendance(records: [(studentId: UUID, courseId: UUID, courseName: String, date: String, status: String)]) async throws {
        let dtos = records.map { record in
            InsertAttendanceDTO(
                studentId: record.studentId,
                courseId: record.courseId,
                courseName: record.courseName,
                date: record.date,
                status: record.status
            )
        }
        try await supabaseClient
            .from("attendance")
            .insert(dtos)
            .execute()
    }

    func calculateRealAttendanceRate(courseId: UUID?) async throws -> Double {
        let records: [AttendanceDTO]
        if let courseId {
            records = try await supabaseClient
                .from("attendance")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .limit(1000)
                .execute()
                .value
        } else {
            records = try await supabaseClient
                .from("attendance")
                .select()
                .limit(1000)
                .execute()
                .value
        }

        let present = records.filter { $0.status.lowercased() == "present" }.count
        let absent = records.filter { $0.status.lowercased() == "absent" }.count
        let tardy = records.filter { $0.status.lowercased() == "tardy" }.count
        let total = present + absent + tardy

        guard total > 0 else { return 0.0 }
        return Double(present) / Double(total)
    }

    // MARK: - Courses (Update / Delete)

    func updateCourse(courseId: UUID, title: String?, description: String?, colorName: String? = nil, iconSystemName: String? = nil) async throws {
        let dto = UpdateCourseDTO(title: title, description: description, colorName: colorName, iconSystemName: iconSystemName)
        try await supabaseClient
            .from("courses")
            .update(dto)
            .eq("id", value: courseId.uuidString)
            .execute()
    }

    func deleteCourse(courseId: UUID) async throws {
        try await supabaseClient
            .from("courses")
            .delete()
            .eq("id", value: courseId.uuidString)
            .execute()
    }

    // MARK: - Assignments (Update / Delete)

    func updateAssignment(assignmentId: UUID, title: String?, instructions: String?, dueDate: String?, points: Int?) async throws {
        let dto = UpdateAssignmentDTO(title: title, instructions: instructions, dueDate: dueDate, points: points)
        try await supabaseClient
            .from("assignments")
            .update(dto)
            .eq("id", value: assignmentId.uuidString)
            .execute()
    }

    func deleteAssignment(assignmentId: UUID) async throws {
        try await supabaseClient
            .from("assignments")
            .delete()
            .eq("id", value: assignmentId.uuidString)
            .execute()
    }

    // MARK: - Announcements (Delete)

    func deleteAnnouncement(announcementId: UUID) async throws {
        try await supabaseClient
            .from("announcements")
            .delete()
            .eq("id", value: announcementId.uuidString)
            .execute()
    }

    // MARK: - Conversations (Create)

    func createConversation(title: String, participantIds: [(userId: UUID, userName: String)]) async throws -> ConversationDTO {
        let convDTO = InsertConversationDTO(title: title, createdAt: formatDate(Date()))
        let conversation: ConversationDTO = try await supabaseClient
            .from("conversations")
            .insert(convDTO)
            .select()
            .single()
            .execute()
            .value

        let participantDTOs = participantIds.map { participant in
            InsertConversationParticipantDTO(
                conversationId: conversation.id,
                userId: participant.userId,
                userName: participant.userName,
                unreadCount: 0
            )
        }
        try await supabaseClient
            .from("conversation_participants")
            .insert(participantDTOs)
            .execute()

        return conversation
    }

    // MARK: - Students in Course

    func fetchStudentsInCourse(courseId: UUID) async throws -> [ProfileDTO] {
        let enrollments: [EnrollmentDTO] = try await supabaseClient
            .from("enrollments")
            .select()
            .eq("course_id", value: courseId.uuidString)
            .execute()
            .value

        let studentIds = enrollments.map(\.studentId)
        if studentIds.isEmpty { return [] }

        let profiles: [ProfileDTO] = try await supabaseClient
            .from("profiles")
            .select()
            .in("id", values: studentIds.map(\.uuidString))
            .execute()
            .value
        return profiles
    }

    // MARK: - Module/Lesson Deletion

    func deleteModule(moduleId: UUID) async throws {
        try await supabaseClient
            .from("lessons")
            .delete()
            .eq("module_id", value: moduleId.uuidString)
            .execute()
        try await supabaseClient
            .from("modules")
            .delete()
            .eq("id", value: moduleId.uuidString)
            .execute()
    }

    func deleteLesson(lessonId: UUID) async throws {
        try await supabaseClient
            .from("lesson_completions")
            .delete()
            .eq("lesson_id", value: lessonId.uuidString)
            .execute()
        try await supabaseClient
            .from("lessons")
            .delete()
            .eq("id", value: lessonId.uuidString)
            .execute()
    }

    func unenrollStudent(studentId: UUID, courseId: UUID) async throws {
        try await supabaseClient
            .from("enrollments")
            .delete()
            .eq("student_id", value: studentId.uuidString)
            .eq("course_id", value: courseId.uuidString)
            .execute()
    }

    // MARK: - Paginated Fetches

    /// Fetches a page of assignments with offset-based pagination.
    /// Use with PaginationState for infinite-scroll or load-more patterns.
    func fetchAssignmentsPaginated(for userId: UUID, role: UserRole, courseIds: [UUID], offset: Int, limit: Int) async throws -> [Assignment] {
        if courseIds.isEmpty { return [] }

        let assignmentDTOs: [AssignmentDTO] = try await supabaseClient
            .from("assignments")
            .select()
            .in("course_id", values: courseIds.map(\.uuidString))
            .order("due_date")
            .range(from: offset, to: offset + limit - 1)
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

        if role == .student {
            var submissions: [UUID: SubmissionDTO] = [:]
            let subs: [SubmissionDTO] = try await supabaseClient
                .from("submissions")
                .select()
                .eq("student_id", value: userId.uuidString)
                .execute()
                .value
            for s in subs {
                submissions[s.assignmentId] = s
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
                    xpReward: dto.xpReward ?? 50,
                    studentId: nil,
                    studentName: nil
                )
            }
        } else {
            let assignmentIds = assignmentDTOs.map(\.id)
            var allSubmissions: [SubmissionDTO] = []
            if !assignmentIds.isEmpty {
                allSubmissions = try await supabaseClient
                    .from("submissions")
                    .select()
                    .in("assignment_id", values: assignmentIds.map(\.uuidString))
                    .execute()
                    .value
            }

            let studentIds = Array(Set(allSubmissions.map(\.studentId)))
            var studentNames: [UUID: String] = [:]
            if !studentIds.isEmpty {
                let profiles: [ProfileDTO] = try await supabaseClient
                    .from("profiles")
                    .select()
                    .in("id", values: studentIds.map(\.uuidString))
                    .execute()
                    .value
                for p in profiles {
                    studentNames[p.id] = "\(p.firstName) \(p.lastName)"
                }
            }

            var submissionsByAssignment: [UUID: [SubmissionDTO]] = [:]
            for sub in allSubmissions {
                submissionsByAssignment[sub.assignmentId, default: []].append(sub)
            }

            var results: [Assignment] = []
            for dto in assignmentDTOs {
                let subs = submissionsByAssignment[dto.id] ?? []
                if subs.isEmpty {
                    results.append(Assignment(
                        id: dto.id,
                        title: dto.title,
                        courseId: dto.courseId,
                        courseName: courseNames[dto.courseId] ?? "Unknown",
                        instructions: dto.instructions ?? "",
                        dueDate: parseDate(dto.dueDate),
                        points: dto.points ?? 100,
                        isSubmitted: false,
                        submission: nil,
                        grade: nil,
                        feedback: nil,
                        xpReward: dto.xpReward ?? 50,
                        studentId: nil,
                        studentName: nil
                    ))
                } else {
                    for sub in subs {
                        results.append(Assignment(
                            id: dto.id,
                            title: dto.title,
                            courseId: dto.courseId,
                            courseName: courseNames[dto.courseId] ?? "Unknown",
                            instructions: dto.instructions ?? "",
                            dueDate: parseDate(dto.dueDate),
                            points: dto.points ?? 100,
                            isSubmitted: true,
                            submission: sub.content,
                            grade: sub.grade,
                            feedback: sub.feedback,
                            xpReward: dto.xpReward ?? 50,
                            studentId: sub.studentId,
                            studentName: studentNames[sub.studentId] ?? "Unknown Student"
                        ))
                    }
                }
            }
            return results
        }
    }

    /// Fetches a page of attendance records with offset-based pagination.
    func fetchAttendancePaginated(for studentId: UUID, offset: Int, limit: Int) async throws -> [AttendanceRecord] {
        let dtos: [AttendanceDTO] = try await supabaseClient
            .from("attendance")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .order("date", ascending: false)
            .range(from: offset, to: offset + limit - 1)
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

    /// Fetches a page of announcements with offset-based pagination.
    func fetchAnnouncementsPaginated(tenantId: UUID? = nil, offset: Int, limit: Int) async throws -> [Announcement] {
        let dtos: [AnnouncementDTO]
        if let tenantId {
            dtos = try await supabaseClient
                .from("announcements")
                .select()
                .eq("tenant_id", value: tenantId.uuidString)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
        } else {
            dtos = try await supabaseClient
                .from("announcements")
                .select()
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
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

    /// Fetches a page of users with offset-based pagination.
    func fetchAllUsersPaginated(schoolId: String?, offset: Int, limit: Int) async throws -> [ProfileDTO] {
        let profiles: [ProfileDTO]
        if let schoolId {
            profiles = try await supabaseClient
                .from("profiles")
                .select()
                .eq("school_id", value: schoolId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
        } else {
            profiles = try await supabaseClient
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
        }
        return profiles
    }
}

nonisolated enum EnrollmentError: LocalizedError, Sendable {
    case invalidClassCode
    case alreadyEnrolled

    var errorDescription: String? {
        switch self {
        case .invalidClassCode: "Invalid class code. Please check and try again."
        case .alreadyEnrolled: "You are already enrolled in this course."
        }
    }
}
