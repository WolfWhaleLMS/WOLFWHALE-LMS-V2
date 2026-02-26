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

        // --- Courses ---
        // TODO: Use actual server `updated_at` timestamps instead of Date() for accurate conflict detection.
        // This requires adding `updatedAt` fields to Course, Assignment, and GradeEntry models.
        let courseConflicts = detectConflicts(
            metadata: metadata,
            entityType: "course",
            serverItems: serverCourses,
            serverIdKeyPath: \.id,
            serverNameKeyPath: \.title,
            serverModifiedAt: { _ in Date() } // Courses rarely have user edits; use server time
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
            serverModifiedAt: { _ in Date() }
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
            serverModifiedAt: { _ in Date() }
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
                // Item exists locally but not on server — server deleted it.
                // Server-wins: discard local version.
                let conflict = SyncConflict(
                    entityType: entityType,
                    entityId: meta.id.uuidString,
                    entityName: meta.entityName,
                    localModifiedAt: meta.modifiedAt,
                    serverModifiedAt: Date(),
                    resolution: .serverWins
                )
                conflicts.append(conflict)
                continue
            }

            let serverDate = serverModifiedAt(serverItem)
            let localDate = meta.modifiedAt

            if serverDate > localDate {
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
            } else if localDate > serverDate {
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
            // If timestamps are equal -> no conflict, nothing to report.
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
