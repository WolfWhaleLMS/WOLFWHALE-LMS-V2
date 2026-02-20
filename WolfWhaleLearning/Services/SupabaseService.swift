import Foundation
import Supabase

let supabaseClient: SupabaseClient = {
    let urlString = Config.SUPABASE_URL
    let anonKey = Config.SUPABASE_ANON_KEY
    guard let url = URL(string: urlString) else {
        // Return a client with a placeholder URL that will fail gracefully on API calls
        // rather than crashing the entire app on launch
        return SupabaseClient(supabaseURL: URL(string: "https://placeholder.supabase.co")!, supabaseKey: anonKey)
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
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
                .from("course_enrollments")
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
                .eq("created_by", value: userId.uuidString)
                .execute()
                .value
        case .admin, .parent, .superAdmin:
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

        let completedLessonIds: Set<UUID> = []

        // --- Batch fetch enrollment counts for all courses ---
        let allEnrollments: [EnrollmentDTO] = try await supabaseClient
            .from("course_enrollments")
            .select()
            .in("course_id", values: allCourseIds.map(\.uuidString))
            .execute()
            .value
        var enrollmentCountByCourse: [UUID: Int] = [:]
        for enrollment in allEnrollments {
            enrollmentCountByCourse[enrollment.courseId, default: 0] += 1
        }

        // --- Batch fetch all teacher/creator names ---
        let creatorIds = Array(Set(courseDTOs.compactMap(\.createdBy)))
        var teacherNameMap: [UUID: String] = [:]
        if !creatorIds.isEmpty {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: creatorIds.map(\.uuidString))
                .execute()
                .value
            for p in profiles {
                teacherNameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
            }
        }

        // --- Group lessons by module ---
        var lessonsByModule: [UUID: [LessonDTO]] = [:]
        for lesson in allLessonDTOs {
            guard let modId = lesson.moduleId else { continue }
            lessonsByModule[modId, default: []].append(lesson)
        }

        // --- Group modules by course ---
        var modulesByCourse: [UUID: [ModuleDTO]] = [:]
        for mod in allModuleDTOs {
            modulesByCourse[mod.courseId, default: []].append(mod)
        }

        // --- Batch fetch class codes for all courses from class_codes table ---
        var classCodeMap: [UUID: String] = [:]
        let classCodes: [ClassCodeDTO] = try await supabaseClient
            .from("class_codes")
            .select()
            .in("course_id", values: allCourseIds.map(\.uuidString))
            .execute()
            .value
        for cc in classCodes {
            classCodeMap[cc.courseId] = cc.code
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
                        duration: 15,
                        isCompleted: completedLessonIds.contains(l.id),
                        type: LessonType(rawValue: l.status ?? "Reading") ?? .reading,
                        xpReward: 25
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
            let teacherName = dto.createdBy.flatMap { teacherNameMap[$0] } ?? "Unknown"
            let totalLessons = modules.reduce(0) { $0 + $1.lessons.count }
            let completedLessons = modules.reduce(0) { $0 + $1.lessons.filter(\.isCompleted).count }
            let progress = totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0

            courses.append(Course(
                id: dto.id,
                title: dto.name,
                description: dto.description ?? "",
                teacherName: teacherName,
                iconSystemName: dto.iconSystemName ?? "book.fill",
                colorName: dto.colorName ?? "blue",
                modules: modules,
                enrolledStudentCount: enrollmentCount,
                progress: progress,
                classCode: classCodeMap[dto.id] ?? ""
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

        let completedLessonIds: Set<UUID> = []

        var lessonsByModule: [UUID: [LessonDTO]] = [:]
        for lesson in allLessonDTOs {
            guard let modId = lesson.moduleId else { continue }
            lessonsByModule[modId, default: []].append(lesson)
        }

        var modules: [Module] = []
        for mDto in moduleDTOs {
            let lessonDTOs = lessonsByModule[mDto.id] ?? []
            let lessons = lessonDTOs.map { l in
                Lesson(
                    id: l.id,
                    title: l.title,
                    content: l.content ?? "",
                    duration: 15,
                    isCompleted: completedLessonIds.contains(l.id),
                    type: LessonType(rawValue: l.status ?? "Reading") ?? .reading,
                    xpReward: 25
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
            .from("course_enrollments")
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
            return "\(profile.firstName ?? "") \(profile.lastName ?? "")"
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
            courseNames[c.id] = c.name
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
                    points: dto.maxPoints ?? 100,
                    isSubmitted: sub != nil,
                    submission: sub?.submissionText,
                    grade: nil,
                    feedback: nil,
                    xpReward: 50,
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
                    studentNames[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
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
                        points: dto.maxPoints ?? 100,
                        isSubmitted: false,
                        submission: nil,
                        grade: nil,
                        feedback: nil,
                        xpReward: 50,
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
                            points: dto.maxPoints ?? 100,
                            isSubmitted: true,
                            submission: sub.submissionText,
                            grade: nil,
                            feedback: nil,
                            xpReward: 50,
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
        let dto = InsertSubmissionDTO(tenantId: nil, assignmentId: assignmentId, studentId: studentId, submissionText: content, filePath: nil, submissionUrl: nil, status: "submitted")
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
        for c in courseDTOs { courseNames[c.id] = c.name }

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

        // --- Batch fetch all options for all questions ---
        let allQuestionIds = allQuestionDTOs.map(\.id)
        var allOptionDTOs: [QuizOptionDTO] = []
        if !allQuestionIds.isEmpty {
            allOptionDTOs = try await supabaseClient
                .from("quiz_options")
                .select()
                .in("question_id", values: allQuestionIds.map(\.uuidString))
                .order("order_index")
                .execute()
                .value
        }

        // Group options by question
        var optionsByQuestion: [UUID: [QuizOptionDTO]] = [:]
        for opt in allOptionDTOs {
            optionsByQuestion[opt.questionId, default: []].append(opt)
        }

        // Group questions by quiz
        var questionsByQuiz: [UUID: [QuizQuestionDTO]] = [:]
        for q in allQuestionDTOs {
            questionsByQuiz[q.quizId, default: []].append(q)
        }

        var quizzes: [Quiz] = []
        for dto in quizDTOs {
            let questionDTOs = questionsByQuiz[dto.id] ?? []
            let questions = questionDTOs.map { q in
                let opts = optionsByQuestion[q.id] ?? []
                let optionTexts = opts.map(\.optionText)
                let correctIdx = opts.firstIndex(where: { $0.isCorrect == true }) ?? 0
                return QuizQuestion(
                    id: q.id,
                    text: q.questionText,
                    options: optionTexts,
                    correctIndex: correctIdx
                )
            }

            let attempt = attemptMap[dto.id]
            quizzes.append(Quiz(
                id: dto.id,
                title: dto.title,
                courseId: dto.courseId,
                courseName: courseNames[dto.courseId] ?? "Unknown",
                questions: questions,
                timeLimit: dto.timeLimitMinutes ?? 30,
                dueDate: Date(),
                isCompleted: attempt != nil,
                score: attempt?.score,
                xpReward: 100
            ))
        }
        return quizzes
    }

    func submitQuizAttempt(quizId: UUID, studentId: UUID, score: Double) async throws {
        let dto = InsertQuizAttemptDTO(quizId: quizId, studentId: studentId, tenantId: nil, score: score, totalPoints: nil, percentage: nil, passed: nil, attemptNumber: nil)
        try await supabaseClient
            .from("quiz_attempts")
            .insert(dto)
            .execute()
    }

    // MARK: - Grades

    func fetchGrades(for studentId: UUID, courseIds: [UUID]) async throws -> [GradeEntry] {
        if courseIds.isEmpty { return [] }

        let allGradeDTOs: [GradeDTO] = try await supabaseClient
            .from("grades")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .in("course_id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .in("id", values: courseIds.map(\.uuidString))
            .execute()
            .value

        // Fetch assignments for these courses so we can show actual titles on grades
        let assignmentDTOs: [AssignmentDTO] = try await supabaseClient
            .from("assignments")
            .select()
            .in("course_id", values: courseIds.map(\.uuidString))
            .execute()
            .value
        let assignmentNames: [UUID: String] = Dictionary(
            assignmentDTOs.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )

        var courseMap: [UUID: CourseDTO] = [:]
        for c in courseDTOs { courseMap[c.id] = c }

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
                    title: assignmentNames[g.assignmentId ?? UUID()] ?? "Assignment",
                    score: g.pointsEarned ?? 0,
                    maxScore: 100,
                    date: parseDate(g.gradedAt),
                    type: "Assignment"
                )
            }

            let avg = assignmentGrades.isEmpty ? 0 :
                assignmentGrades.reduce(0.0) { $0 + ($1.score / $1.maxScore * 100) } / Double(assignmentGrades.count)

            let letter = letterGrade(for: avg)

            gradeEntries.append(GradeEntry(
                id: course.id,
                courseId: course.id,
                courseName: course.name,
                courseIcon: "book.fill",
                courseColor: "blue",
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

        // Resolve creator names
        let creatorIds = Array(Set(dtos.compactMap(\.createdBy)))
        var nameMap: [UUID: String] = [:]
        if !creatorIds.isEmpty {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: creatorIds.map(\.uuidString))
                .execute()
                .value
            for p in profiles {
                nameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
            }
        }

        return dtos.map { dto in
            let authorName = dto.createdBy.flatMap { nameMap[$0] } ?? "Admin"
            return Announcement(
                id: dto.id,
                title: dto.title,
                content: dto.content ?? "",
                authorName: authorName,
                date: parseDate(dto.createdAt),
                isPinned: false
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
        let members: [ConversationMemberDTO] = try await supabaseClient
            .from("conversation_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let conversationIds = members.map(\.conversationId)
        if conversationIds.isEmpty { return [] }

        let convDTOs: [ConversationDTO] = try await supabaseClient
            .from("conversations")
            .select()
            .in("id", values: conversationIds.map(\.uuidString))
            .limit(50)
            .execute()
            .value

        if convDTOs.isEmpty { return [] }

        let convIds = convDTOs.map(\.id)

        // --- Batch fetch last 30 messages per conversation (most recent) ---
        let allMessageDTOs: [MessageDTO] = try await supabaseClient
            .from("messages")
            .select()
            .in("conversation_id", values: convIds.map(\.uuidString))
            .order("created_at", ascending: false)
            .limit(30 * convIds.count)
            .execute()
            .value

        // Resolve sender names
        let senderIds = Array(Set(allMessageDTOs.map(\.senderId)))
        var senderNameMap: [UUID: String] = [:]
        if !senderIds.isEmpty {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: senderIds.map(\.uuidString))
                .execute()
                .value
            for p in profiles {
                senderNameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
            }
        }

        // Group messages by conversation
        var messagesByConv: [UUID: [MessageDTO]] = [:]
        for m in allMessageDTOs {
            messagesByConv[m.conversationId, default: []].append(m)
        }

        // --- Batch fetch all members for all conversations at once ---
        let allMembers: [ConversationMemberDTO] = try await supabaseClient
            .from("conversation_members")
            .select()
            .in("conversation_id", values: convIds.map(\.uuidString))
            .execute()
            .value

        // Group members by conversation
        var membersByConv: [UUID: [ConversationMemberDTO]] = [:]
        for m in allMembers {
            membersByConv[m.conversationId, default: []].append(m)
        }

        var conversations: [Conversation] = []
        for conv in convDTOs {
            let messageDTOs = messagesByConv[conv.id] ?? []
            let messages = messageDTOs.map { m in
                ChatMessage(
                    id: m.id,
                    senderName: senderNameMap[m.senderId] ?? "Unknown",
                    content: m.content,
                    timestamp: parseDate(m.createdAt),
                    isFromCurrentUser: m.senderId == userId
                )
            }

            let convMembers = membersByConv[conv.id] ?? []
            let otherCount = convMembers.filter { $0.userId != userId }.count

            conversations.append(Conversation(
                id: conv.id,
                participantNames: [],
                title: conv.subject ?? "Conversation",
                lastMessage: messages.last?.content ?? "",
                lastMessageDate: messages.last?.timestamp ?? parseDate(conv.createdAt),
                unreadCount: 0,
                messages: messages,
                avatarSystemName: otherCount > 1 ? "person.3.fill" : "person.crop.circle.fill"
            ))
        }

        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    func sendMessage(conversationId: UUID, senderId: UUID, senderName: String, content: String) async throws {
        let dto = InsertMessageDTO(tenantId: nil, conversationId: conversationId, senderId: senderId, content: content, attachments: nil)
        try await supabaseClient
            .from("messages")
            .insert(dto)
            .execute()
    }

    func fetchOlderMessages(conversationId: UUID, before: Date, limit: Int = 30) async throws -> [MessageDTO] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let beforeString = formatter.string(from: before)

        let messages: [MessageDTO] = try await supabaseClient
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .lt("created_at", value: beforeString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return messages.reversed()
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
                title: dto.name,
                description: dto.description ?? "",
                iconSystemName: dto.icon ?? "star.fill",
                isUnlocked: unlockedIds.contains(dto.id),
                unlockedDate: unlockedDates[dto.id],
                xpReward: dto.xpReward ?? 50,
                rarity: AchievementRarity(rawValue: dto.tier ?? "Common") ?? .common
            )
        }
    }

    // MARK: - Leaderboard

    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        let xpEntries: [StudentXpDTO] = try await supabaseClient
            .from("student_xp")
            .select()
            .order("total_xp", ascending: false)
            .limit(20)
            .execute()
            .value

        if xpEntries.isEmpty { return [] }

        let studentIds = xpEntries.map(\.studentId)
        let profiles: [ProfileDTO] = try await supabaseClient
            .from("profiles")
            .select()
            .in("id", values: studentIds.map(\.uuidString))
            .execute()
            .value
        var nameMap: [UUID: String] = [:]
        for p in profiles {
            nameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
        }

        return xpEntries.enumerated().map { index, entry in
            LeaderboardEntry(
                id: entry.studentId,
                userName: nameMap[entry.studentId] ?? "Unknown",
                xp: entry.totalXp ?? 0,
                level: entry.currentLevel ?? 1,
                rank: index + 1,
                avatarSystemName: "person.crop.circle.fill"
            )
        }
    }

    // MARK: - Attendance

    func fetchAttendance(for studentId: UUID) async throws -> [AttendanceRecord] {
        let dtos: [AttendanceDTO] = try await supabaseClient
            .from("attendance_records")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .order("attendance_date", ascending: false)
            .limit(50)
            .execute()
            .value

        return dtos.map { dto in
            AttendanceRecord(
                id: dto.id,
                date: parseDate(dto.attendanceDate),
                status: AttendanceStatus(rawValue: dto.status) ?? .present,
                courseName: "All Classes",
                studentName: nil
            )
        }
    }

    // MARK: - Lesson Completion

    func completeLesson(studentId: UUID, lessonId: UUID, courseId: UUID, tenantId: UUID) async throws {
        let dto = InsertLessonCompletionDTO(
            studentId: studentId,
            lessonId: lessonId,
            courseId: courseId,
            tenantId: tenantId
        )
        try await supabaseClient
            .from("lesson_completions")
            .insert(dto)
            .execute()
    }

    func fetchLessonCompletions(studentId: UUID, courseId: UUID) async throws -> [LessonCompletionDTO] {
        try await supabaseClient
            .from("lesson_completions")
            .select()
            .eq("student_id", value: studentId)
            .eq("course_id", value: courseId)
            .execute()
            .value
    }

    // MARK: - Admin: Users

    func fetchAllUsers(schoolId: String?, offset: Int = 0, limit: Int = 50) async throws -> [ProfileDTO] {
        if let schoolId, let tenantUUID = UUID(uuidString: schoolId) {
            let memberships: [TenantMembershipDTO] = try await supabaseClient
                .from("tenant_memberships")
                .select()
                .eq("tenant_id", value: tenantUUID.uuidString)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            let userIds = memberships.map(\.userId)
            if userIds.isEmpty { return [] }

            // Build role lookup from memberships
            var roleByUser: [UUID: String] = [:]
            for m in memberships { roleByUser[m.userId] = m.role }

            var profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: userIds.map(\.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value

            // Populate transient role property on each profile
            for i in profiles.indices {
                profiles[i].role = roleByUser[profiles[i].id] ?? ""
            }

            return profiles
        } else {
            // No school filter -- fetch all profiles and all memberships
            var profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            let allMemberships: [TenantMembershipDTO] = try await supabaseClient
                .from("tenant_memberships")
                .select()
                .limit(500)
                .execute()
                .value
            var roleByUser: [UUID: String] = [:]
            for m in allMemberships { roleByUser[m.userId] = m.role }

            for i in profiles.indices {
                profiles[i].role = roleByUser[profiles[i].id] ?? ""
            }

            return profiles
        }
    }

    func deleteUser(userId: UUID) async throws {
        try await supabaseClient.rpc("delete_user_complete", params: ["target_user_id": userId.uuidString]).execute()
    }

    // MARK: - Admin: School Metrics

    func fetchSchoolMetrics(schoolId: String?) async throws -> SchoolMetrics {
        let profiles = try await fetchAllUsers(schoolId: schoolId)

        let allMemberships: [TenantMembershipDTO] = try await supabaseClient
            .from("tenant_memberships")
            .select()
            .limit(500)
            .execute()
            .value
        var roleByUser: [UUID: String] = [:]
        for m in allMemberships { roleByUser[m.userId] = m.role }

        let students = profiles.filter { roleByUser[$0.id] == "Student" }.count
        let teachers = profiles.filter { roleByUser[$0.id] == "Teacher" }.count
        let active = profiles.count

        let courses: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .limit(100)
            .execute()
            .value

        let attendanceRate = try await calculateRealAttendanceRate(courseId: nil)

        let studentProfiles = Array(profiles.filter { roleByUser[$0.id] == "Student" }.prefix(200))
        let studentIds = studentProfiles.map(\.id)

        var averageGPA = 0.0
        if !studentIds.isEmpty {
            let allEnrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .in("student_id", values: studentIds.map(\.uuidString))
                .execute()
                .value

            let allCourseIds = Array(Set(allEnrollments.map(\.courseId)))

            if !allCourseIds.isEmpty {
                let allGrades: [GradeDTO] = try await supabaseClient
                    .from("grades")
                    .select()
                    .in("student_id", values: studentIds.map(\.uuidString))
                    .in("course_id", values: allCourseIds.map(\.uuidString))
                    .execute()
                    .value

                var enrollmentsByStudent: [UUID: [EnrollmentDTO]] = [:]
                for e in allEnrollments {
                    enrollmentsByStudent[e.studentId, default: []].append(e)
                }

                var gradesByStudentCourse: [UUID: [UUID: [GradeDTO]]] = [:]
                for g in allGrades {
                    gradesByStudentCourse[g.studentId, default: [:]][g.courseId, default: []].append(g)
                }

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
                            let score = g.pointsEarned ?? 0
                            let maxScore = 100.0
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
        let links: [StudentParentDTO] = try await supabaseClient
            .from("student_parents")
            .select()
            .eq("parent_id", value: parentId.uuidString)
            .execute()
            .value

        if links.isEmpty { return [] }

        let childIds = links.map(\.studentId)

        let childProfiles: [ProfileDTO] = try await supabaseClient
            .from("profiles")
            .select()
            .in("id", values: childIds.map(\.uuidString))
            .execute()
            .value
        var profileMap: [UUID: ProfileDTO] = [:]
        for p in childProfiles { profileMap[p.id] = p }

        let allEnrollments: [EnrollmentDTO] = try await supabaseClient
            .from("course_enrollments")
            .select()
            .in("student_id", values: childIds.map(\.uuidString))
            .execute()
            .value

        var enrollmentsByChild: [UUID: [EnrollmentDTO]] = [:]
        for e in allEnrollments {
            enrollmentsByChild[e.studentId, default: []].append(e)
        }

        let allCourseIds = Array(Set(allEnrollments.map(\.courseId)))

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

        var gradesByStudentCourse: [UUID: [UUID: [GradeDTO]]] = [:]
        for g in allGrades {
            gradesByStudentCourse[g.studentId, default: [:]][g.courseId, default: []].append(g)
        }

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

        var allSubmissions: [SubmissionDTO] = []
        if !childIds.isEmpty {
            allSubmissions = try await supabaseClient
                .from("submissions")
                .select()
                .in("student_id", values: childIds.map(\.uuidString))
                .execute()
                .value
        }
        var submissionsByStudent: [UUID: [UUID: SubmissionDTO]] = [:]
        for s in allSubmissions {
            submissionsByStudent[s.studentId, default: [:]][s.assignmentId] = s
        }

        var assignmentsByCourse: [UUID: [AssignmentDTO]] = [:]
        for a in allAssignmentDTOs {
            assignmentsByCourse[a.courseId, default: []].append(a)
        }

        let allAttendance: [AttendanceDTO] = try await supabaseClient
            .from("attendance_records")
            .select()
            .in("student_id", values: childIds.map(\.uuidString))
            .limit(500)
            .execute()
            .value
        var attendanceByChild: [UUID: [AttendanceDTO]] = [:]
        for a in allAttendance {
            attendanceByChild[a.studentId, default: []].append(a)
        }

        var children: [ChildInfo] = []
        for link in links {
            guard let profile = profileMap[link.studentId] else { continue }

            let childEnrollments = enrollmentsByChild[link.studentId] ?? []
            let childCourseIds = childEnrollments.map(\.courseId)

            var gradeEntries: [GradeEntry] = []
            for courseId in childCourseIds {
                guard let course = courseMap[courseId] else { continue }
                let gradeDTOs = gradesByStudentCourse[link.studentId]?[courseId] ?? []
                if gradeDTOs.isEmpty { continue }

                let assignmentGrades = gradeDTOs.map { g in
                    AssignmentGrade(
                        id: g.id,
                        title: "Assignment",
                        score: g.pointsEarned ?? 0,
                        maxScore: 100,
                        date: parseDate(g.gradedAt),
                        type: "Assignment"
                    )
                }

                let avg = assignmentGrades.isEmpty ? 0 :
                    assignmentGrades.reduce(0.0) { $0 + ($1.score / $1.maxScore * 100) } / Double(assignmentGrades.count)
                let letter = letterGrade(for: avg)

                gradeEntries.append(GradeEntry(
                    id: course.id,
                    courseId: course.id,
                    courseName: course.name,
                    courseIcon: "book.fill",
                    courseColor: "blue",
                    letterGrade: letter,
                    numericGrade: avg,
                    assignmentGrades: assignmentGrades
                ))
            }

            let childSubmissions = submissionsByStudent[link.studentId] ?? [:]
            var childAssignments: [Assignment] = []
            for courseId in childCourseIds {
                let courseName = courseMap[courseId]?.name ?? "Unknown"
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
                        points: dto.maxPoints ?? 100,
                        isSubmitted: sub != nil,
                        submission: sub?.submissionText,
                        grade: nil,
                        feedback: nil,
                        xpReward: 50,
                        studentId: nil,
                        studentName: nil
                    ))
                }
            }

            let avg = gradeEntries.isEmpty ? 0 : gradeEntries.reduce(0.0) { $0 + $1.numericGrade } / Double(gradeEntries.count)
            let gpa = avg / 100.0 * 4.0

            let childAttendance = attendanceByChild[link.studentId] ?? []
            let presentCount = childAttendance.filter { $0.status.lowercased() == "present" }.count
            let totalCount = childAttendance.count
            let attendanceRate = totalCount > 0 ? Double(presentCount) / Double(totalCount) : 0.0

            children.append(ChildInfo(
                id: link.studentId,
                name: "\(profile.firstName ?? "") \(profile.lastName ?? "")",
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

    func updateProfile(userId: UUID, update: UpdateStudentXpDTO) async throws {
        try await supabaseClient
            .from("student_xp")
            .update(update)
            .eq("student_id", value: userId.uuidString)
            .execute()
    }

    func resetPassword(email: String) async throws {
        try await supabaseClient.auth.resetPasswordForEmail(email)
    }

    // MARK: - Grades (Create)

    func gradeSubmission(studentId: UUID, courseId: UUID, assignmentId: UUID, score: Double, maxScore: Double, letterGrade: String, feedback: String) async throws {
        let percentage = maxScore > 0 ? (score / maxScore * 100) : 0
        let dto = InsertGradeDTO(
            tenantId: nil,
            submissionId: nil,
            assignmentId: assignmentId,
            studentId: studentId,
            courseId: courseId,
            pointsEarned: score,
            percentage: percentage,
            letterGrade: letterGrade,
            feedback: feedback,
            gradedBy: nil,
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
            tenantId: nil,
            courseId: courseId,
            assignmentId: nil,
            title: title,
            description: nil,
            timeLimitMinutes: timeLimit,
            shuffleQuestions: nil,
            shuffleAnswers: nil,
            showResults: nil,
            maxAttempts: nil,
            passingScore: nil,
            status: nil,
            createdBy: nil
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
        let questionDTO = InsertQuizQuestionDTO(
            quizId: quizId,
            type: "multiple_choice",
            questionText: text,
            points: 1.0,
            orderIndex: nil,
            explanation: nil
        )
        // Insert question and get back the ID
        let question: QuizQuestionDTO = try await supabaseClient
            .from("quiz_questions")
            .insert(questionDTO)
            .select()
            .single()
            .execute()
            .value

        // Insert options
        let optionDTOs = options.enumerated().map { idx, optText in
            InsertQuizOptionDTO(
                questionId: question.id,
                optionText: optText,
                isCorrect: idx == correctIndex,
                orderIndex: idx
            )
        }
        try await supabaseClient
            .from("quiz_options")
            .insert(optionDTOs)
            .execute()
    }

    // MARK: - Lessons (Create)

    func createLesson(moduleId: UUID, title: String, content: String, duration: Int, type: String, xpReward: Int, orderIndex: Int) async throws -> LessonDTO {
        let dto = InsertLessonDTO(
            tenantId: nil,
            courseId: nil,
            title: title,
            description: nil,
            content: content,
            orderIndex: orderIndex,
            createdBy: nil,
            status: type,
            moduleId: moduleId
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
            tenantId: nil,
            courseId: courseId,
            createdBy: nil,
            title: title,
            description: nil,
            orderIndex: orderIndex,
            status: nil
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

    private static let enrollmentRateLimiter = EnrollmentRateLimiter()

    func enrollStudent(studentId: UUID, courseId: UUID) async throws {
        let dto = InsertEnrollmentDTO(
            tenantId: nil,
            courseId: courseId,
            studentId: studentId,
            teacherId: nil,
            status: "active",
            enrolledAt: formatDate(Date())
        )
        try await supabaseClient
            .from("course_enrollments")
            .insert(dto)
            .execute()
    }

    func enrollByClassCode(studentId: UUID, classCode: String) async throws -> String {
        try DataService.enrollmentRateLimiter.checkRateLimit(userId: studentId)

        let codes: [ClassCodeDTO] = try await supabaseClient
            .from("class_codes")
            .select()
            .eq("code", value: classCode)
            .limit(1)
            .execute()
            .value

        guard let codeEntry = codes.first else {
            throw EnrollmentError.invalidClassCode
        }

        let courseDTOs: [CourseDTO] = try await supabaseClient
            .from("courses")
            .select()
            .eq("id", value: codeEntry.courseId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let course = courseDTOs.first else {
            throw EnrollmentError.invalidClassCode
        }

        let existing: [EnrollmentDTO] = try await supabaseClient
            .from("course_enrollments")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .eq("course_id", value: codeEntry.courseId.uuidString)
            .execute()
            .value

        if !existing.isEmpty {
            throw EnrollmentError.alreadyEnrolled
        }

        try await enrollStudent(studentId: studentId, courseId: codeEntry.courseId)
        return course.name
    }

    // MARK: - Tenant Lookup

    func lookupTenantByInviteCode(_ code: String) async throws -> UUID? {
        struct TenantResult: Decodable { let id: UUID }
        let results: [TenantResult] = try await supabaseClient
            .from("tenants")
            .select("id")
            .eq("invite_code", value: code.uppercased().trimmingCharacters(in: .whitespaces))
            .limit(1)
            .execute()
            .value
        return results.first?.id
    }

    // MARK: - Attendance (Create)

    func takeAttendance(records: [(studentId: UUID, courseId: UUID, courseName: String, date: String, status: String)]) async throws {
        let dtos = records.map { record in
            InsertAttendanceDTO(
                tenantId: nil,
                courseId: record.courseId,
                studentId: record.studentId,
                attendanceDate: record.date,
                status: record.status,
                notes: nil,
                markedBy: nil
            )
        }
        try await supabaseClient
            .from("attendance_records")
            .insert(dtos)
            .execute()
    }

    func calculateRealAttendanceRate(courseId: UUID?) async throws -> Double {
        let records: [AttendanceDTO]
        if let courseId {
            records = try await supabaseClient
                .from("attendance_records")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .limit(1000)
                .execute()
                .value
        } else {
            records = try await supabaseClient
                .from("attendance_records")
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
        let dto = UpdateCourseDTO(name: title, description: description, subject: nil, gradeLevel: nil, semester: nil, startDate: nil, endDate: nil, syllabusUrl: nil, credits: nil, status: nil)
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
        let dto = UpdateAssignmentDTO(title: title, description: nil, instructions: instructions, type: nil, dueDate: dueDate, availableDate: nil, maxPoints: points, submissionType: nil, allowLateSubmission: nil, lateSubmissionDays: nil, status: nil)
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
        let convDTO = InsertConversationDTO(tenantId: nil, type: "direct", subject: title, createdBy: nil, courseId: nil)
        let conversation: ConversationDTO = try await supabaseClient
            .from("conversations")
            .insert(convDTO)
            .select()
            .single()
            .execute()
            .value

        let memberDTOs = participantIds.map { participant in
            InsertConversationMemberDTO(
                conversationId: conversation.id,
                userId: participant.userId
            )
        }
        try await supabaseClient
            .from("conversation_members")
            .insert(memberDTOs)
            .execute()

        return conversation
    }

    // MARK: - Students in Course

    func fetchStudentsInCourse(courseId: UUID) async throws -> [ProfileDTO] {
        let enrollments: [EnrollmentDTO] = try await supabaseClient
            .from("course_enrollments")
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
            .from("lessons")
            .delete()
            .eq("id", value: lessonId.uuidString)
            .execute()
    }

    func unenrollStudent(studentId: UUID, courseId: UUID) async throws {
        try await supabaseClient
            .from("course_enrollments")
            .delete()
            .eq("student_id", value: studentId.uuidString)
            .eq("course_id", value: courseId.uuidString)
            .execute()
    }

    // MARK: - Paginated Fetches

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
            courseNames[c.id] = c.name
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
                    points: dto.maxPoints ?? 100,
                    isSubmitted: sub != nil,
                    submission: sub?.submissionText,
                    grade: nil,
                    feedback: nil,
                    xpReward: 50,
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
                    studentNames[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
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
                        points: dto.maxPoints ?? 100,
                        isSubmitted: false,
                        submission: nil,
                        grade: nil,
                        feedback: nil,
                        xpReward: 50,
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
                            points: dto.maxPoints ?? 100,
                            isSubmitted: true,
                            submission: sub.submissionText,
                            grade: nil,
                            feedback: nil,
                            xpReward: 50,
                            studentId: sub.studentId,
                            studentName: studentNames[sub.studentId] ?? "Unknown Student"
                        ))
                    }
                }
            }
            return results
        }
    }

    func fetchAttendancePaginated(for studentId: UUID, offset: Int, limit: Int) async throws -> [AttendanceRecord] {
        let dtos: [AttendanceDTO] = try await supabaseClient
            .from("attendance_records")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .order("attendance_date", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return dtos.map { dto in
            AttendanceRecord(
                id: dto.id,
                date: parseDate(dto.attendanceDate),
                status: AttendanceStatus(rawValue: dto.status) ?? .present,
                courseName: "All Classes",
                studentName: nil
            )
        }
    }

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
                authorName: "Admin",
                date: parseDate(dto.createdAt),
                isPinned: false
            )
        }
    }

    func fetchAllUsersPaginated(schoolId: String?, offset: Int, limit: Int) async throws -> [ProfileDTO] {
        if let schoolId, let tenantUUID = UUID(uuidString: schoolId) {
            let memberships: [TenantMembershipDTO] = try await supabaseClient
                .from("tenant_memberships")
                .select()
                .eq("tenant_id", value: tenantUUID.uuidString)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            let userIds = memberships.map(\.userId)
            if userIds.isEmpty { return [] }

            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .in("id", values: userIds.map(\.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value

            return profiles
        } else {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            return profiles
        }
    }
}

final class EnrollmentRateLimiter: @unchecked Sendable {
    private var attempts: [(userId: UUID, time: Date)] = []
    private let maxAttempts = 5
    private let window: TimeInterval = 60
    private let lock = NSLock()

    func checkRateLimit(userId: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-window)
        attempts.removeAll { $0.time < cutoff }
        let recentAttempts = attempts.filter { $0.userId == userId }
        guard recentAttempts.count < maxAttempts else {
            throw NSError(domain: "RateLimit", code: 429, userInfo: [NSLocalizedDescriptionKey: "Too many enrollment attempts. Please wait a minute."])
        }
        attempts.append((userId: userId, time: Date()))
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
