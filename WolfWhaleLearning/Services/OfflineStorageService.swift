import Foundation

// MARK: - OfflineStorageService
// All model types (Course, Module, Lesson, Assignment, GradeEntry, AssignmentGrade,
// Conversation, ChatMessage, User) now conform to Codable directly,
// so no Codable wrapper types are needed.

@Observable
@MainActor
final class OfflineStorageService {

    // MARK: - State

    /// The user ID that scopes all offline data. Set via `setCurrentUser(_:)`.
    private var currentUserId: String?

    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    /// Approximate total size of cached files in bytes.
    private(set) var cachedDataSize: Int64 = 0

    // MARK: - Constants

    /// Per-user UserDefaults key for the last sync timestamp.
    private var lastSyncKey: String {
        guard let uid = currentUserId else { return "wolfwhale_offline_last_sync" }
        return "wolfwhale_offline_last_sync_\(uid)"
    }
    private static let coursesFile = "offline_courses.json"
    private static let assignmentsFile = "offline_assignments.json"
    private static let gradesFile = "offline_grades.json"
    private static let conversationsFile = "offline_conversations.json"
    private static let userProfileFile = "offline_user_profile.json"

    // MARK: - Directory (per-user)

    private var cacheDirectory: URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return URL(fileURLWithPath: NSTemporaryDirectory()) }
        // Scope offline data to the current user to prevent data leakage between users
        let subpath: String
        if let uid = currentUserId {
            subpath = "OfflineCache/\(uid)"
        } else {
            subpath = "OfflineCache"
        }
        let dir = docs.appendingPathComponent(subpath, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Init

    init() {
        recalculateCacheSize()
    }

    /// Set the current user so all offline data is scoped per-user.
    /// Must be called after login and before saving or loading offline data.
    func setCurrentUser(_ userId: UUID) {
        let previousUserId = currentUserId
        currentUserId = userId.uuidString
        // Ensure old user data isn't accessible by recalculating for the new user only
        if previousUserId != currentUserId {
            recalculateCacheSize()
        }
    }

    /// Clear the current user scope (called on logout).
    func clearCurrentUser() {
        currentUserId = nil
        cachedDataSize = 0
    }

    /// Delete the current user's entire cache directory.
    func clearCache() {
        guard currentUserId != nil else { return }
        let fm = FileManager.default
        let dir = cacheDirectory
        try? fm.removeItem(at: dir)
        cachedDataSize = 0
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
        guard currentUserId != nil else { return }
        save(courses, filename: Self.coursesFile)
        recalculateCacheSize()
    }

    func loadCourses() -> [Course] {
        guard currentUserId != nil else { return [] }
        return load(filename: Self.coursesFile) ?? []
    }

    // MARK: - Assignments

    func saveAssignments(_ assignments: [Assignment]) {
        guard currentUserId != nil else { return }
        save(assignments, filename: Self.assignmentsFile)
        recalculateCacheSize()
    }

    func loadAssignments() -> [Assignment] {
        guard currentUserId != nil else { return [] }
        return load(filename: Self.assignmentsFile) ?? []
    }

    // MARK: - Grades

    func saveGrades(_ grades: [GradeEntry]) {
        guard currentUserId != nil else { return }
        save(grades, filename: Self.gradesFile)
        recalculateCacheSize()
    }

    func loadGrades() -> [GradeEntry] {
        guard currentUserId != nil else { return [] }
        return load(filename: Self.gradesFile) ?? []
    }

    // MARK: - Conversations

    func saveConversations(_ conversations: [Conversation]) {
        guard currentUserId != nil else { return }
        save(conversations, filename: Self.conversationsFile)
        recalculateCacheSize()
    }

    func loadConversations() -> [Conversation] {
        guard currentUserId != nil else { return [] }
        return load(filename: Self.conversationsFile) ?? []
    }

    // MARK: - User Profile

    func saveUserProfile(_ user: User) {
        guard currentUserId != nil else { return }
        save(user, filename: Self.userProfileFile)
        recalculateCacheSize()
    }

    func loadUserProfile() -> User? {
        guard currentUserId != nil else { return nil }
        return load(filename: Self.userProfileFile)
    }

    // MARK: - Clear All

    func clearAllData() {
        guard currentUserId != nil else { return }
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
        guard currentUserId != nil else { return false }
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
