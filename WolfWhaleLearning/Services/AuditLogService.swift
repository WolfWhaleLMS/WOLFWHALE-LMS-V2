import Foundation
import Supabase

// MARK: - Audit Log Entry Model

/// Represents a single audit log entry for FERPA/GDPR compliance tracking.
nonisolated struct AuditLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: String?
    let action: String
    let entityType: String
    let entityId: String?
    let details: String?
    let ipAddress: String?
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case action
        case entityType = "entity_type"
        case entityId = "entity_id"
        case details
        case ipAddress = "ip_address"
        case timestamp
    }
}

/// DTO for inserting audit log entries into Supabase.
nonisolated struct InsertAuditLogDTO: Codable, Sendable {
    let userId: String?
    let action: String
    let entityType: String
    let entityId: String?
    let details: String?
    let ipAddress: String?
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case action
        case entityType = "entity_type"
        case entityId = "entity_id"
        case details
        case ipAddress = "ip_address"
        case timestamp
    }
}

/// DTO for reading audit log entries from Supabase (includes server-generated id).
nonisolated struct AuditLogDTO: Decodable, Identifiable, Sendable {
    let id: UUID
    let userId: String?
    let action: String
    let entityType: String
    let entityId: String?
    let details: String?
    let ipAddress: String?
    let timestamp: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case action
        case entityType = "entity_type"
        case entityId = "entity_id"
        case details
        case ipAddress = "ip_address"
        case timestamp
        case createdAt = "created_at"
    }
}

// MARK: - Audit Log Actions & Entity Types

/// Well-known audit actions for type safety.
nonisolated enum AuditAction {
    static let create = "create"
    static let read = "read"
    static let update = "update"
    static let delete = "delete"
    static let login = "login"
    static let logout = "logout"
    static let export = "export"
    static let gradeChange = "grade_change"
}

/// Well-known entity types for type safety.
nonisolated enum AuditEntityType {
    static let course = "course"
    static let assignment = "assignment"
    static let grade = "grade"
    static let user = "user"
    static let enrollment = "enrollment"
    static let quiz = "quiz"
    static let message = "message"
    static let announcement = "announcement"
}

// MARK: - Audit Log Service

@Observable
@MainActor
final class AuditLogService {

    // MARK: - Configuration

    /// Maximum entries to queue before forcing a flush.
    private let batchThreshold = 10
    /// Interval in seconds between automatic flushes.
    private let flushInterval: TimeInterval = 30

    // MARK: - State

    private var queue: [InsertAuditLogDTO] = []
    private var flushTask: Task<Void, Never>?
    private var currentUserId: String?

    // MARK: - Date Formatter

    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Lifecycle

    init() {
        loadOfflineQueue()
        startPeriodicFlush()
    }

    // MARK: - Public API

    /// Sets the current user ID for all subsequent log entries.
    func setUser(_ userId: UUID?) {
        currentUserId = userId?.uuidString
    }

    /// Logs an audit event. Entries are batched and flushed periodically or when the threshold is reached.
    /// - Parameters:
    ///   - action: The action performed (use `AuditAction` constants).
    ///   - entityType: The type of entity affected (use `AuditEntityType` constants).
    ///   - entityId: The unique ID of the affected entity, if applicable.
    ///   - details: Optional key-value pairs providing additional context.
    func log(
        _ action: String,
        entityType: String,
        entityId: String? = nil,
        details: [String: String]? = nil
    ) async {
        let detailsJSON: String? = {
            guard let details, !details.isEmpty else { return nil }
            guard let data = try? JSONEncoder().encode(details) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        let entry = InsertAuditLogDTO(
            userId: currentUserId,
            action: action,
            entityType: entityType,
            entityId: entityId,
            details: detailsJSON,
            ipAddress: nil,
            timestamp: Self.iso8601.string(from: Date())
        )

        queue.append(entry)

        if queue.count >= batchThreshold {
            await flush()
        }
    }

    /// Forces an immediate flush of all queued entries. Call on logout or app backgrounding.
    func flush() async {
        guard !queue.isEmpty else { return }

        let batch = queue
        queue.removeAll()

        do {
            try await supabaseClient
                .from("audit_logs")
                .insert(batch)
                .execute()

            #if DEBUG
            print("[AuditLogService] Flushed \(batch.count) entries to Supabase")
            #endif

            // Clear offline queue on successful flush
            clearOfflineQueue()
        } catch {
            #if DEBUG
            print("[AuditLogService] Flush failed, saving to offline queue: \(error)")
            #endif

            // Put entries back and save to offline storage
            queue.insert(contentsOf: batch, at: 0)
            saveOfflineQueue()
        }
    }

    /// Clears the current user and flushes remaining entries.
    func clearUser() async {
        await flush()
        currentUserId = nil
    }

    // MARK: - Fetch (Admin)

    /// Fetches audit log entries for admin viewing with optional filters.
    /// - Parameters:
    ///   - action: Filter by action type.
    ///   - userId: Filter by user ID.
    ///   - startDate: Filter entries on or after this date.
    ///   - endDate: Filter entries on or before this date.
    ///   - offset: Pagination offset.
    ///   - limit: Number of entries per page.
    /// - Returns: Array of audit log DTOs.
    func fetchLogs(
        action: String? = nil,
        userId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> [AuditLogDTO] {
        var query = supabaseClient
            .from("audit_logs")
            .select()

        if let action, !action.isEmpty {
            query = query.eq("action", value: action)
        }

        if let userId, !userId.isEmpty {
            query = query.eq("user_id", value: userId)
        }

        if let startDate {
            let startString = Self.iso8601.string(from: startDate)
            query = query.gte("timestamp", value: startString)
        }

        if let endDate {
            let endString = Self.iso8601.string(from: endDate)
            query = query.lte("timestamp", value: endString)
        }

        let results: [AuditLogDTO] = try await query
            .order("timestamp", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return results
    }

    // MARK: - Periodic Flush

    private func startPeriodicFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.flushInterval ?? 30))
                guard !Task.isCancelled else { break }
                await self?.flush()
            }
        }
    }

    // MARK: - Offline Queue (UserDefaults)

    private func saveOfflineQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.auditLogOfflineQueue)
    }

    private func loadOfflineQueue() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.auditLogOfflineQueue) else { return }
        guard let entries = try? JSONDecoder().decode([InsertAuditLogDTO].self, from: data) else { return }
        queue.append(contentsOf: entries)
        #if DEBUG
        if !entries.isEmpty {
            print("[AuditLogService] Loaded \(entries.count) entries from offline queue")
        }
        #endif
    }

    private func clearOfflineQueue() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.auditLogOfflineQueue)
    }
}
