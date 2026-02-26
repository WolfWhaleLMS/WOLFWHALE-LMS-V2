import Foundation

// MARK: - CacheService

/// Thread-safe, in-memory cache backed by a Swift actor.
///
/// Features:
/// - Per-entry TTL (time-to-live) with a configurable default.
/// - Prefix-based invalidation (e.g., invalidate all "courses_*" keys).
/// - Automatic LRU-style eviction when the cache exceeds its maximum size.
/// - Already thread-safe by virtue of being an `actor`.
actor CacheService {
    static let shared = CacheService()

    // MARK: - Configuration

    /// Maximum number of entries allowed in the cache.
    private let maxEntries: Int

    /// Default TTL applied when callers omit the `ttl` parameter.
    private let defaultTTL: TimeInterval

    // MARK: - Storage

    /// Each entry stores the cached value, its expiry date, and when it was last accessed
    /// (used for eviction priority).
    private var cache: [String: CacheEntry] = [:]

    private struct CacheEntry {
        let data: Any
        let expiry: Date
        var lastAccessed: Date
    }

    // MARK: - Init

    init(maxEntries: Int = 200, defaultTTL: TimeInterval = 300) {
        self.maxEntries = maxEntries
        self.defaultTTL = defaultTTL
    }

    // MARK: - Read

    /// Retrieve a cached value by key. Returns `nil` when the key is missing,
    /// the entry has expired, or the stored type does not match `T`.
    func get<T>(_ key: String) -> T? {
        guard var entry = cache[key] else { return nil }

        // Expired -- remove lazily and return nil
        if entry.expiry <= Date() {
            cache.removeValue(forKey: key)
            return nil
        }

        // Update last-accessed timestamp for eviction ordering
        entry.lastAccessed = Date()
        cache[key] = entry

        return entry.data as? T
    }

    // MARK: - Write

    /// Store a value in the cache with an optional per-entry TTL.
    /// When `ttl` is `nil` the service-wide `defaultTTL` is used.
    func set(_ key: String, value: Any, ttl: TimeInterval? = nil) {
        enforceCapacity()
        let effectiveTTL = ttl ?? defaultTTL
        cache[key] = CacheEntry(
            data: value,
            expiry: Date().addingTimeInterval(effectiveTTL),
            lastAccessed: Date()
        )
    }

    // MARK: - Invalidation

    /// Remove a single entry by exact key.
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }

    /// Remove all entries whose key starts with the given prefix.
    ///
    /// Example:
    /// ```swift
    /// await CacheService.shared.invalidateByPrefix("courses_")
    /// ```
    func invalidateByPrefix(_ prefix: String) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    /// Remove every entry from the cache.
    func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Eviction

    /// Remove all entries whose expiry date has passed.
    func evictExpired() {
        let now = Date()
        cache = cache.filter { $0.value.expiry > now }
    }

    /// The current number of entries in the cache (useful for diagnostics).
    var count: Int {
        cache.count
    }

    // MARK: - Private

    /// Ensures the cache stays within `maxEntries` by first evicting expired
    /// entries, then removing the least-recently-accessed 10% if still over capacity.
    private func enforceCapacity() {
        guard cache.count >= maxEntries else { return }

        // First pass: remove expired entries (cheap)
        evictExpired()

        // Second pass: if still at capacity, evict the oldest-accessed 10%
        guard cache.count >= maxEntries else { return }
        let evictCount = max(1, maxEntries / 10)
        let keysToEvict = cache
            .sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            .prefix(evictCount)
            .map(\.key)
        for key in keysToEvict {
            cache.removeValue(forKey: key)
        }
    }
}
