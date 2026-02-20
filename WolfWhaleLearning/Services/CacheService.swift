import Foundation

actor CacheService {
    static let shared = CacheService()

    private var cache: [String: (data: Any, expiry: Date)] = [:]

    func get<T>(_ key: String) -> T? {
        guard let entry = cache[key], entry.expiry > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data as? T
    }

    func set(_ key: String, value: Any, ttl: TimeInterval = 60) {
        cache[key] = (data: value, expiry: Date().addingTimeInterval(ttl))
    }

    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
