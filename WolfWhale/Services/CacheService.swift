import Foundation

// NOTE: This cache service is available but not yet integrated into the data layer.
// Consider using it for frequently-accessed, rarely-changing data like course metadata.

actor CacheService {
    static let shared = CacheService()

    /// Maximum number of entries allowed in the cache.
    private let maxEntries = 200

    private var cache: [String: (data: Any, expiry: Date)] = [:]

    func get<T>(_ key: String) -> T? {
        guard let entry = cache[key], entry.expiry > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data as? T
    }

    func set(_ key: String, value: Any, ttl: TimeInterval = 60) {
        // Evict expired entries when the cache exceeds its maximum size.
        if cache.count >= maxEntries {
            evictExpired()
        }
        // If still at capacity after eviction, batch-remove the oldest 10% of entries.
        if cache.count >= maxEntries {
            let evictCount = max(1, maxEntries / 10)
            let sortedKeys = cache.sorted { $0.value.expiry < $1.value.expiry }
                .prefix(evictCount)
                .map(\.key)
            for key in sortedKeys {
                cache.removeValue(forKey: key)
            }
        }
        cache[key] = (data: value, expiry: Date().addingTimeInterval(ttl))
    }

    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }

    func invalidateAll() {
        cache.removeAll()
    }

    /// Remove all entries whose expiry date has passed.
    func evictExpired() {
        let now = Date()
        cache = cache.filter { $0.value.expiry > now }
    }
}
