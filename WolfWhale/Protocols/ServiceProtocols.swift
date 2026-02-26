import Foundation
import SwiftUI
import Supabase

// MARK: - Auth Service Protocol

/// Abstracts Supabase authentication so ViewModels can be tested
/// against a mock without hitting the network.
protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> Session
    func signUp(email: String, password: String, fullName: String) async throws
    func signOut() async throws
    func sendPasswordReset(email: String) async throws -> Bool
    func refreshSession() async throws -> Session
    func deleteAccount(userId: UUID) async throws
    func updatePassword(newPassword: String) async throws
}

// MARK: - Data Fetching Protocol

/// Abstracts Supabase data reads so the data layer can be swapped
/// for mock/offline implementations.
protocol DataServiceProtocol: Sendable {
    func fetchCourses(tenantId: UUID, userId: UUID, role: String) async throws -> [Course]
    func fetchAssignments(tenantId: UUID, role: String, userId: UUID, range: Range<Int>?) async throws -> [Assignment]
    func fetchGrades(tenantId: UUID, userId: UUID) async throws -> [GradeEntry]
    func fetchConversations(tenantId: UUID, userId: UUID) async throws -> [Conversation]
    func fetchAnnouncements(tenantId: UUID) async throws -> [Announcement]
}

// MARK: - Grade Calculation Protocol

/// Abstracts grade computation so it can be unit-tested and swapped
/// for different grading policies (e.g. curve-based, standards-based).
protocol GradeCalculationProtocol: Sendable {
    func calculateCourseGrade(
        grades: [GradeEntry],
        weights: GradeWeights,
        courseId: UUID,
        courseName: String
    ) -> CourseGradeResult
    func calculateGPA(courseResults: [CourseGradeResult]) -> Double
    func letterGrade(from percentage: Double) -> String
}

// MARK: - Offline Storage Protocol

/// Abstracts offline data persistence so alternative backends
/// (e.g. Core Data, SQLite, file-system) can be used.
protocol OfflineStorageProtocol: Sendable {
    func save<T: Encodable>(_ data: T, forKey key: String, userId: UUID) async throws
    func load<T: Decodable>(forKey key: String, userId: UUID, as type: T.Type) async throws -> T?
    func clearAll(userId: UUID) async throws
}

// MARK: - Cache Service Protocol

/// Abstracts in-memory/key-value caching for data-layer deduplication
/// and frequently-accessed reads.
protocol CacheServiceProtocol: Sendable {
    func get<T>(_ key: String) async -> T?
    func set(_ key: String, value: Any, ttl: TimeInterval) async
    func invalidate(_ key: String) async
    func invalidateAll() async
}

// MARK: - Image Cache Protocol

/// Abstracts image caching (memory + disk) so Views can load cached
/// images without knowing the storage backend.
protocol ImageCacheProtocol: Sendable {
    func getImage(for url: URL) -> Image?
    func setImage(_ image: Image, data: Data, for url: URL)
    func clearMemoryCache()
}

// MARK: - Network Monitor Protocol

/// Abstracts network reachability so it can be mocked in previews
/// and tests (e.g. simulating offline mode).
@MainActor
protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var isExpensive: Bool { get }
    var isConstrained: Bool { get }
}
