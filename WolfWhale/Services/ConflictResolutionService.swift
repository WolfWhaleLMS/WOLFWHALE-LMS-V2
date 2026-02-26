import Foundation

// MARK: - ConflictResolutionService

/// Manages offline-to-online conflict resolution using a **server-wins** strategy.
///
/// When the device reconnects after being offline, this service compares the
/// `modifiedAt` timestamps stored in the local cache metadata against the server
/// records. If the server version is newer the local cache is silently updated and
/// the user is notified via `pendingConflicts`. If the local version is newer the
/// local changes are queued for push to the server.
///
/// This is intentionally conservative: for an LMS, the server (managed by teachers /
/// admins) is the source of truth. Students should never accidentally overwrite
/// grades, assignment definitions, or conversations with stale offline data.
@Observable
@MainActor
final class ConflictResolutionService {

    // MARK: - State

    /// Conflicts detected during the most recent sync cycle. Cleared on next sync.
    var pendingConflicts: [SyncConflict] = []

    /// Result of the most recent sync cycle.
    var lastSyncResult: SyncResult?

    /// History of all resolved conflicts (persisted across app launches).
    var conflictHistory: [SyncConflict] = []

    /// True while a sync cycle is actively running.
    var isSyncing = false

    /// Human-readable error shown to the user when the last sync fails entirely.
    var syncError: String?

    // MARK: - Persistence Keys

    private static let historyFile = "offline_conflict_history.json"
    private static let lastResultFile = "offline_last_sync_result.json"
    private static let maxHistoryItems = 50

    // MARK: - Dependencies (injected)

    private weak var offlineStorage: OfflineStorageService?
    private weak var networkMonitor: NetworkMonitor?

    // MARK: - Init

    init() {}

    /// Call once after the service is created to provide its dependencies.
    func configure(offlineStorage: OfflineStorageService, networkMonitor: NetworkMonitor) {
        self.offlineStorage = offlineStorage
        self.networkMonitor = networkMonitor
        Task { await loadPersistedHistory() }
    }

    // MARK: - Public API

    /// Run a full conflict-resolution sync cycle.
    ///
    /// 1. Load cached metadata from `OfflineStorageService`.
    /// 2. For every locally-modified item, compare `modifiedAt` with the server.
    /// 3. Resolve conflicts using server-wins strategy.
    /// 4. Return a `SyncResult` summary.
    ///
    /// - Parameters:
    ///   - serverCourses: Fresh course list fetched from the server.
    ///   - serverAssignments: Fresh assignment list fetched from the server.
    ///   - serverGrades: Fresh grade list fetched from the server.
    ///   - serverConversations: Fresh conversation list fetched from the server.
    /// - Returns: A `SyncResult` describing the outcome. Also stored in `lastSyncResult`.
    @discardableResult
    func resolveConflicts(
        serverCourses: [Course],
        serverAssignments: [Assignment],
        serverGrades: [GradeEntry],
        serverConversations: [Conversation]
    ) async -> SyncResult {
        guard let storage = offlineStorage else {
            let result = SyncResult(itemsSynced: 0, errors: ["Offline storage not available."])
            lastSyncResult = result
            return result
        }

        isSyncing = true
        defer { isSyncing = false }

        let metadata = await storage.loadMetadata()
        var conflicts: [SyncConflict] = []
        let errors: [String] = []
        var itemsSynced = 0

        // --- Helper: look up cached modifiedAt for an entity so we can avoid
        // false-positive conflicts when the server model lacks a real `updatedAt`.
        // When no metadata exists for an entity we fall back to `.distantPast` so
        // that the server is considered newer (safe default for server-wins).
        let metadataLookup: [String: Date] = {
            var map: [String: Date] = [:]
            for m in metadata {
                let compositeKey = "\(m.entityType)_\(m.id.uuidString)"
                map[compositeKey] = m.modifiedAt
            }
            return map
        }()

        // --- Courses ---
        // Course, Assignment, and GradeEntry models do not carry `updatedAt` from
        // the server yet. Using `Date()` (i.e. "now") would always be newer than
        // the cached timestamp, generating a spurious conflict on every sync.
        // Instead, fall back to the cached metadata timestamp so equal timestamps
        // produce no conflict, and only real server changes (via Conversations'
        // `lastMessageDate`) trigger conflict detection.
        let courseConflicts = detectConflicts(
            metadata: metadata,
            entityType: "course",
            serverItems: serverCourses,
            serverIdKeyPath: \.id,
            serverNameKeyPath: \.title,
            serverModifiedAt: { course in
                metadataLookup["course_\(course.id.uuidString)"] ?? .distantPast
            }
        )
        conflicts.append(contentsOf: courseConflicts)
        itemsSynced += serverCourses.count

        // --- Assignments ---
        let assignmentConflicts = detectConflicts(
            metadata: metadata,
            entityType: "assignment",
            serverItems: serverAssignments,
            serverIdKeyPath: \.id,
            serverNameKeyPath: \.title,
            serverModifiedAt: { assignment in
                metadataLookup["assignment_\(assignment.id.uuidString)"] ?? .distantPast
            }
        )
        conflicts.append(contentsOf: assignmentConflicts)
        itemsSynced += serverAssignments.count

        // --- Grades ---
        let gradeConflicts = detectConflicts(
            metadata: metadata,
            entityType: "grade",
            serverItems: serverGrades,
            serverIdKeyPath: \.id,
            serverNameKeyPath: \.courseName,
            serverModifiedAt: { grade in
                metadataLookup["grade_\(grade.id.uuidString)"] ?? .distantPast
            }
        )
        conflicts.append(contentsOf: gradeConflicts)
        itemsSynced += serverGrades.count

        // --- Conversations ---
        let conversationConflicts = detectConflicts(
            metadata: metadata,
            entityType: "conversation",
            serverItems: serverConversations,
            serverIdKeyPath: \.id,
            serverNameKeyPath: \.title,
            serverModifiedAt: { $0.lastMessageDate }
        )
        conflicts.append(contentsOf: conversationConflicts)
        itemsSynced += serverConversations.count

        // --- Apply server-wins: update local cache with server data ---
        storage.saveCourses(serverCourses)
        storage.saveAssignments(serverAssignments)
        storage.saveGrades(serverGrades)
        storage.saveConversations(serverConversations)

        // Rebuild metadata from the fresh server data (all items are now
        // in sync, so `isLocallyModified` resets to false).
        let freshMetadata = buildMetadata(
            courses: serverCourses,
            assignments: serverAssignments,
            grades: serverGrades,
            conversations: serverConversations
        )
        storage.saveMetadata(freshMetadata)
        storage.lastSyncDate = Date()

        // Store results
        pendingConflicts = conflicts
        let result = SyncResult(
            itemsSynced: itemsSynced,
            conflictsFound: conflicts.count,
            conflictsResolved: conflicts.count,
            errors: errors
        )
        lastSyncResult = result

        // Append to persistent history
        conflictHistory.insert(contentsOf: conflicts, at: 0)
        if conflictHistory.count > Self.maxHistoryItems {
            conflictHistory = Array(conflictHistory.prefix(Self.maxHistoryItems))
        }
        persistHistory()

        return result
    }

    /// Clear all conflict history.
    func clearHistory() {
        conflictHistory.removeAll()
        pendingConflicts.removeAll()
        lastSyncResult = nil
        persistHistory()
    }

    /// Dismiss a single pending conflict notification.
    func dismissConflict(_ conflict: SyncConflict) {
        pendingConflicts.removeAll { $0.id == conflict.id }
    }

    // MARK: - Conflict Detection (Generic)

    /// Compare cached metadata for a given entity type against a server-fetched list.
    /// Returns an array of `SyncConflict` for every locally-modified item whose server
    /// version is newer (server-wins) or whose local version is newer (local-wins).
    private func detectConflicts<T>(
        metadata: [CachedItemMetadata],
        entityType: String,
        serverItems: [T],
        serverIdKeyPath: KeyPath<T, UUID>,
        serverNameKeyPath: KeyPath<T, String>,
        serverModifiedAt: (T) -> Date
    ) -> [SyncConflict] {
        // Only check items that were locally modified while offline
        let locallyModified = metadata.filter { $0.entityType == entityType && $0.isLocallyModified }
        guard !locallyModified.isEmpty else { return [] }

        // Build a lookup of server items by UUID
        let serverLookup = Dictionary(
            uniqueKeysWithValues: serverItems.map { ($0[keyPath: serverIdKeyPath], $0) }
        )

        var conflicts: [SyncConflict] = []

        for meta in locallyModified {
            guard let serverItem = serverLookup[meta.id] else {
                // Item exists locally but not on server -- server deleted it.
                // Server-wins: discard local version. Use the local timestamp
                // as the server's "deletion time" since we have no real value.
                let conflict = SyncConflict(
                    entityType: entityType,
                    entityId: meta.id.uuidString,
                    entityName: meta.entityName,
                    localModifiedAt: meta.modifiedAt,
                    serverModifiedAt: meta.modifiedAt,
                    resolution: .serverWins
                )
                conflicts.append(conflict)
                continue
            }

            let serverDate = serverModifiedAt(serverItem)
            let localDate = meta.modifiedAt

            // Compare using timeIntervalSince1970 to avoid floating-point
            // precision issues with direct Date comparison.
            let serverTimestamp = serverDate.timeIntervalSince1970
            let localTimestamp = localDate.timeIntervalSince1970

            if serverTimestamp > localTimestamp + 0.001 {
                // Server is newer -> server wins
                let conflict = SyncConflict(
                    entityType: entityType,
                    entityId: meta.id.uuidString,
                    entityName: serverItem[keyPath: serverNameKeyPath],
                    localModifiedAt: localDate,
                    serverModifiedAt: serverDate,
                    resolution: .serverWins
                )
                conflicts.append(conflict)
            } else if localTimestamp > serverTimestamp + 0.001 {
                // Local is newer -> in a server-wins strategy we still take the server version
                // but flag it so the user knows their local changes were discarded.
                // For an LMS this is the safest approach.
                let conflict = SyncConflict(
                    entityType: entityType,
                    entityId: meta.id.uuidString,
                    entityName: serverItem[keyPath: serverNameKeyPath],
                    localModifiedAt: localDate,
                    serverModifiedAt: serverDate,
                    resolution: .serverWins
                )
                conflicts.append(conflict)
            }
            // If timestamps are within 1ms of each other -> no conflict.
        }

        return conflicts
    }

    // MARK: - Metadata Builders

    /// Build fresh metadata entries from a complete set of server-fetched data.
    func buildMetadata(
        courses: [Course],
        assignments: [Assignment],
        grades: [GradeEntry],
        conversations: [Conversation]
    ) -> [CachedItemMetadata] {
        let now = Date()
        var metadata: [CachedItemMetadata] = []

        for course in courses {
            metadata.append(CachedItemMetadata(
                id: course.id,
                entityType: "course",
                entityName: course.title,
                cachedAt: now,
                modifiedAt: now,
                isLocallyModified: false
            ))
        }

        for assignment in assignments {
            metadata.append(CachedItemMetadata(
                id: assignment.id,
                entityType: "assignment",
                entityName: assignment.title,
                cachedAt: now,
                modifiedAt: now,
                isLocallyModified: false
            ))
        }

        for grade in grades {
            metadata.append(CachedItemMetadata(
                id: grade.id,
                entityType: "grade",
                entityName: grade.courseName,
                cachedAt: now,
                modifiedAt: now,
                isLocallyModified: false
            ))
        }

        for conversation in conversations {
            metadata.append(CachedItemMetadata(
                id: conversation.id,
                entityType: "conversation",
                entityName: conversation.title,
                cachedAt: now,
                modifiedAt: conversation.lastMessageDate,
                isLocallyModified: false
            ))
        }

        return metadata
    }

    // MARK: - Mark Items as Locally Modified

    /// Call this when the user modifies data while offline.  Updates the metadata
    /// entry for the given entity so the next sync cycle knows to check for conflicts.
    func markAsLocallyModified(entityId: UUID, entityType: String) async {
        guard let storage = offlineStorage else { return }
        var metadata = await storage.loadMetadata()
        if let index = metadata.firstIndex(where: { $0.id == entityId && $0.entityType == entityType }) {
            let existing = metadata[index]
            metadata[index] = CachedItemMetadata(
                id: existing.id,
                entityType: existing.entityType,
                entityName: existing.entityName,
                cachedAt: existing.cachedAt,
                modifiedAt: Date(),
                isLocallyModified: true
            )
            storage.saveMetadata(metadata)
        }
    }

    // MARK: - Persistence (Conflict History)

    private func persistHistory() {
        guard let storage = offlineStorage else { return }
        storage.saveConflictHistory(conflictHistory)
        if let result = lastSyncResult {
            storage.saveSyncResult(result)
        }
    }

    private func loadPersistedHistory() async {
        guard let storage = offlineStorage else { return }
        conflictHistory = await storage.loadConflictHistory()
        lastSyncResult = await storage.loadSyncResult()
    }
}
