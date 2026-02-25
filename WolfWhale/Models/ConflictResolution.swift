import Foundation

// MARK: - Sync Conflict

/// Represents a conflict detected between locally cached data and the server version
/// during an offline-to-online synchronization cycle.
nonisolated struct SyncConflict: Identifiable, Sendable, Codable {
    let id: UUID
    /// The kind of entity that conflicted (e.g. "course", "assignment", "grade", "conversation").
    let entityType: String
    /// The UUID string of the specific entity.
    let entityId: String
    /// A human-readable label for the entity (e.g. course title, assignment name).
    let entityName: String
    /// When the local cache version was last modified.
    let localModifiedAt: Date
    /// When the server version was last modified.
    let serverModifiedAt: Date
    /// How the conflict was resolved.
    let resolution: ConflictResolution
    /// When the conflict was resolved.
    let resolvedAt: Date

    init(
        id: UUID = UUID(),
        entityType: String,
        entityId: String,
        entityName: String,
        localModifiedAt: Date,
        serverModifiedAt: Date,
        resolution: ConflictResolution,
        resolvedAt: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.entityName = entityName
        self.localModifiedAt = localModifiedAt
        self.serverModifiedAt = serverModifiedAt
        self.resolution = resolution
        self.resolvedAt = resolvedAt
    }
}

// MARK: - Conflict Resolution Strategy

nonisolated enum ConflictResolution: String, Sendable, Codable {
    /// The server version replaced the local version.
    case serverWins
    /// The local version was pushed to the server.
    case localWins
    /// Both versions had identical timestamps; no action needed.
    case noConflict
}

// MARK: - Sync Result

/// Summary of a single synchronization cycle.
nonisolated struct SyncResult: Sendable, Codable {
    let syncedAt: Date
    let itemsSynced: Int
    let conflictsFound: Int
    let conflictsResolved: Int
    let errors: [String]

    /// True when the sync completed without errors.
    var isSuccess: Bool { errors.isEmpty }

    init(
        syncedAt: Date = Date(),
        itemsSynced: Int,
        conflictsFound: Int = 0,
        conflictsResolved: Int = 0,
        errors: [String] = []
    ) {
        self.syncedAt = syncedAt
        self.itemsSynced = itemsSynced
        self.conflictsFound = conflictsFound
        self.conflictsResolved = conflictsResolved
        self.errors = errors
    }
}

// MARK: - Cached Item Metadata

/// Lightweight metadata stored alongside each cached entity so the sync service can
/// detect conflicts by comparing `modifiedAt` timestamps with the server.
nonisolated struct CachedItemMetadata: Identifiable, Sendable, Codable {
    /// Matches the entity's own UUID.
    let id: UUID
    /// Entity type string (e.g. "course", "assignment").
    let entityType: String
    /// Human-readable name for conflict notifications.
    let entityName: String
    /// Timestamp when this item was last written to the local cache.
    let cachedAt: Date
    /// Timestamp of the entity's last modification (mirrors the server's `updated_at`
    /// at the time the item was cached). Used for conflict detection.
    let modifiedAt: Date
    /// `true` if the user modified this item while offline. Only locally-modified
    /// items need conflict checks during sync.
    let isLocallyModified: Bool

    init(
        id: UUID,
        entityType: String,
        entityName: String,
        cachedAt: Date = Date(),
        modifiedAt: Date,
        isLocallyModified: Bool = false
    ) {
        self.id = id
        self.entityType = entityType
        self.entityName = entityName
        self.cachedAt = cachedAt
        self.modifiedAt = modifiedAt
        self.isLocallyModified = isLocallyModified
    }
}
