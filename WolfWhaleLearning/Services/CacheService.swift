import Foundation

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
        // If still at capacity after eviction, remove the oldest entry.
        if cache.count >= maxEntries {
            if let oldestKey = cache.min(by: { $0.value.expiry < $1.value.expiry })?.key {
                cache.removeValue(forKey: oldestKey)
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
