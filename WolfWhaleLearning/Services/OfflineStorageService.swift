import Foundation

// MARK: - Codable Wrappers for Offline Storage

/// Codable representation of Course (and nested Module/Lesson) for local persistence.
private struct CodableCourse: Codable {
    let id: UUID
    var title: String
    var description: String
    var teacherName: String
    var iconSystemName: String
    var colorName: String
    var modules: [CodableModule]
    var enrolledStudentCount: Int
    var progress: Double
    var classCode: String

    init(from course: Course) {
        id = course.id
        title = course.title
        description = course.description
        teacherName = course.teacherName
        iconSystemName = course.iconSystemName
        colorName = course.colorName
        modules = course.modules.map { CodableModule(from: $0) }
        enrolledStudentCount = course.enrolledStudentCount
        progress = course.progress
        classCode = course.classCode
    }

    func toModel() -> Course {
        Course(
            id: id, title: title, description: description,
            teacherName: teacherName, iconSystemName: iconSystemName,
            colorName: colorName, modules: modules.map { $0.toModel() },
            enrolledStudentCount: enrolledStudentCount, progress: progress,
            classCode: classCode
        )
    }
}

private struct CodableModule: Codable {
    let id: UUID
    var title: String
    var lessons: [CodableLesson]
    var orderIndex: Int

    init(from module: Module) {
        id = module.id
        title = module.title
        lessons = module.lessons.map { CodableLesson(from: $0) }
        orderIndex = module.orderIndex
    }

    func toModel() -> Module {
        Module(id: id, title: title, lessons: lessons.map { $0.toModel() }, orderIndex: orderIndex)
    }
}

private struct CodableLesson: Codable {
    let id: UUID
    var title: String
    var content: String
    var duration: Int
    var isCompleted: Bool
    var type: String
    var xpReward: Int

    init(from lesson: Lesson) {
        id = lesson.id
        title = lesson.title
        content = lesson.content
        duration = lesson.duration
        isCompleted = lesson.isCompleted
        type = lesson.type.rawValue
        xpReward = lesson.xpReward
    }

    func toModel() -> Lesson {
        Lesson(
            id: id, title: title, content: content, duration: duration,
            isCompleted: isCompleted, type: LessonType(rawValue: type) ?? .reading,
            xpReward: xpReward
        )
    }
}

private struct CodableAssignment: Codable {
    let id: UUID
    var title: String
    var courseId: UUID
    var courseName: String
    var instructions: String
    var dueDate: Date
    var points: Int
    var isSubmitted: Bool
    var submission: String?
    var grade: Double?
    var feedback: String?
    var xpReward: Int
    var studentId: UUID?
    var studentName: String?

    init(from a: Assignment) {
        id = a.id; title = a.title; courseId = a.courseId; courseName = a.courseName
        instructions = a.instructions; dueDate = a.dueDate; points = a.points
        isSubmitted = a.isSubmitted; submission = a.submission; grade = a.grade
        feedback = a.feedback; xpReward = a.xpReward; studentId = a.studentId
        studentName = a.studentName
    }

    func toModel() -> Assignment {
        Assignment(
            id: id, title: title, courseId: courseId, courseName: courseName,
            instructions: instructions, dueDate: dueDate, points: points,
            isSubmitted: isSubmitted, submission: submission, grade: grade,
            feedback: feedback, xpReward: xpReward, studentId: studentId,
            studentName: studentName
        )
    }
}

private struct CodableGradeEntry: Codable {
    let id: UUID
    var courseId: UUID
    var courseName: String
    var courseIcon: String
    var courseColor: String
    var letterGrade: String
    var numericGrade: Double
    var assignmentGrades: [CodableAssignmentGrade]

    init(from g: GradeEntry) {
        id = g.id; courseId = g.courseId; courseName = g.courseName
        courseIcon = g.courseIcon; courseColor = g.courseColor
        letterGrade = g.letterGrade; numericGrade = g.numericGrade
        assignmentGrades = g.assignmentGrades.map { CodableAssignmentGrade(from: $0) }
    }

    func toModel() -> GradeEntry {
        GradeEntry(
            id: id, courseId: courseId, courseName: courseName,
            courseIcon: courseIcon, courseColor: courseColor,
            letterGrade: letterGrade, numericGrade: numericGrade,
            assignmentGrades: assignmentGrades.map { $0.toModel() }
        )
    }
}

private struct CodableAssignmentGrade: Codable {
    let id: UUID
    var title: String
    var score: Double
    var maxScore: Double
    var date: Date
    var type: String

    init(from g: AssignmentGrade) {
        id = g.id; title = g.title; score = g.score
        maxScore = g.maxScore; date = g.date; type = g.type
    }

    func toModel() -> AssignmentGrade {
        AssignmentGrade(id: id, title: title, score: score, maxScore: maxScore, date: date, type: type)
    }
}

private struct CodableConversation: Codable {
    let id: UUID
    var participantNames: [String]
    var title: String
    var lastMessage: String
    var lastMessageDate: Date
    var unreadCount: Int
    var messages: [CodableChatMessage]
    var avatarSystemName: String

    init(from c: Conversation) {
        id = c.id; participantNames = c.participantNames; title = c.title
        lastMessage = c.lastMessage; lastMessageDate = c.lastMessageDate
        unreadCount = c.unreadCount; messages = c.messages.map { CodableChatMessage(from: $0) }
        avatarSystemName = c.avatarSystemName
    }

    func toModel() -> Conversation {
        Conversation(
            id: id, participantNames: participantNames, title: title,
            lastMessage: lastMessage, lastMessageDate: lastMessageDate,
            unreadCount: unreadCount, messages: messages.map { $0.toModel() },
            avatarSystemName: avatarSystemName
        )
    }
}

private struct CodableChatMessage: Codable {
    let id: UUID
    var senderName: String
    var content: String
    var timestamp: Date
    var isFromCurrentUser: Bool

    init(from m: ChatMessage) {
        id = m.id; senderName = m.senderName; content = m.content
        timestamp = m.timestamp; isFromCurrentUser = m.isFromCurrentUser
    }

    func toModel() -> ChatMessage {
        ChatMessage(id: id, senderName: senderName, content: content, timestamp: timestamp, isFromCurrentUser: isFromCurrentUser)
    }
}

private struct CodableUser: Codable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var role: String
    var avatarSystemName: String
    var streak: Int
    var joinDate: Date
    var schoolId: String?
    var userSlotsTotal: Int
    var userSlotsUsed: Int

    init(from u: User) {
        id = u.id; firstName = u.firstName; lastName = u.lastName
        email = u.email; role = u.role.rawValue; avatarSystemName = u.avatarSystemName
        streak = u.streak; joinDate = u.joinDate; schoolId = u.schoolId
        userSlotsTotal = u.userSlotsTotal; userSlotsUsed = u.userSlotsUsed
    }

    func toModel() -> User {
        User(
            id: id, firstName: firstName, lastName: lastName,
            email: email, role: UserRole(rawValue: role) ?? .student,
            avatarSystemName: avatarSystemName, streak: streak,
            joinDate: joinDate, schoolId: schoolId,
            userSlotsTotal: userSlotsTotal, userSlotsUsed: userSlotsUsed
        )
    }
}

// MARK: - OfflineStorageService

@Observable
@MainActor
final class OfflineStorageService {

    // MARK: - State

    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncKey) }
    }

    /// Approximate total size of cached files in bytes.
    private(set) var cachedDataSize: Int64 = 0

    // MARK: - Constants

    private static let lastSyncKey = "wolfwhale_offline_last_sync"
    private static let coursesFile = "offline_courses.json"
    private static let assignmentsFile = "offline_assignments.json"
    private static let gradesFile = "offline_grades.json"
    private static let conversationsFile = "offline_conversations.json"
    private static let userProfileFile = "offline_user_profile.json"

    // MARK: - Directory

    private var cacheDirectory: URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return URL(fileURLWithPath: NSTemporaryDirectory()) }
        let dir = docs.appendingPathComponent("OfflineCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Init

    init() {
        recalculateCacheSize()
    }

    // MARK: - Generic Helpers

    private func save<T: Encodable>(_ data: T, filename: String) {
        // Capture the URL on the main actor, then perform file I/O off the main thread
        let url = cacheDirectory.appendingPathComponent(filename)
        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(data)
                try jsonData.write(to: url, options: .atomic)
            } catch {
                #if DEBUG
                print("[OfflineStorage] Failed to save \(filename): \(error)")
                #endif
            }
        }
    }

    private func load<T: Decodable>(filename: String) -> T? {
        // Note: load is synchronous by design so callers can use the return value immediately.
        // For large datasets, callers should invoke from a background context.
        let url = cacheDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[OfflineStorage] Failed to load \(filename): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Courses

    func saveCourses(_ courses: [Course]) {
        save(courses.map { CodableCourse(from: $0) }, filename: Self.coursesFile)
        recalculateCacheSize()
    }

    func loadCourses() -> [Course] {
        let codable: [CodableCourse]? = load(filename: Self.coursesFile)
        return codable?.map { $0.toModel() } ?? []
    }

    // MARK: - Assignments

    func saveAssignments(_ assignments: [Assignment]) {
        save(assignments.map { CodableAssignment(from: $0) }, filename: Self.assignmentsFile)
        recalculateCacheSize()
    }

    func loadAssignments() -> [Assignment] {
        let codable: [CodableAssignment]? = load(filename: Self.assignmentsFile)
        return codable?.map { $0.toModel() } ?? []
    }

    // MARK: - Grades

    func saveGrades(_ grades: [GradeEntry]) {
        save(grades.map { CodableGradeEntry(from: $0) }, filename: Self.gradesFile)
        recalculateCacheSize()
    }

    func loadGrades() -> [GradeEntry] {
        let codable: [CodableGradeEntry]? = load(filename: Self.gradesFile)
        return codable?.map { $0.toModel() } ?? []
    }

    // MARK: - Conversations

    func saveConversations(_ conversations: [Conversation]) {
        save(conversations.map { CodableConversation(from: $0) }, filename: Self.conversationsFile)
        recalculateCacheSize()
    }

    func loadConversations() -> [Conversation] {
        let codable: [CodableConversation]? = load(filename: Self.conversationsFile)
        return codable?.map { $0.toModel() } ?? []
    }

    // MARK: - User Profile

    func saveUserProfile(_ user: User) {
        save(CodableUser(from: user), filename: Self.userProfileFile)
        recalculateCacheSize()
    }

    func loadUserProfile() -> User? {
        let codable: CodableUser? = load(filename: Self.userProfileFile)
        return codable?.toModel()
    }

    // MARK: - Clear All

    func clearAllData() {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fm.removeItem(at: file)
            }
        }
        lastSyncDate = nil
        cachedDataSize = 0
    }

    // MARK: - Has Offline Data

    var hasOfflineData: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: cacheDirectory.appendingPathComponent(Self.coursesFile).path)
            || fm.fileExists(atPath: cacheDirectory.appendingPathComponent(Self.assignmentsFile).path)
    }

    // MARK: - Cache Size

    func recalculateCacheSize() {
        let fm = FileManager.default
        var total: Int64 = 0
        if let contents = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let size = attrs[.size] as? Int64 {
                    total += size
                }
            }
        }
        cachedDataSize = total
    }

    /// Human-readable string of cached data size.
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cachedDataSize, countStyle: .file)
    }

    /// Breakdown of individual file sizes for the settings UI.
    var storageBreakdown: [(label: String, size: Int64)] {
        let files: [(String, String)] = [
            ("Courses", Self.coursesFile),
            ("Assignments", Self.assignmentsFile),
            ("Grades", Self.gradesFile),
            ("Conversations", Self.conversationsFile),
            ("User Profile", Self.userProfileFile),
        ]
        let fm = FileManager.default
        return files.compactMap { label, filename in
            let url = cacheDirectory.appendingPathComponent(filename)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 else {
                return nil
            }
            return (label, size)
        }
    }
}
