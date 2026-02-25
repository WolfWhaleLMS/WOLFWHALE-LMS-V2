import SwiftUI
import CryptoKit

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cache Entry

/// Wrapper class for NSCache storage (NSCache requires class-type values).
final class CacheEntry: @unchecked Sendable {
    let image: Image
    let cost: Int

    init(image: Image, cost: Int) {
        self.image = image
        self.cost = cost
    }
}

// MARK: - ImageCacheService

/// Thread-safe image cache with in-memory (NSCache) and disk caching.
///
/// - In-memory layer: `NSCache` with a 200-item / 50 MB limit.
/// - Disk layer: file-based cache in `<Caches>/ImageCache/` with a 200 MB budget.
/// - Cache keys are derived from the SHA-256 hash of the URL string.
///
/// Usage:
/// ```swift
/// if let cached = ImageCacheService.shared.getImage(for: url) { ... }
/// ImageCacheService.shared.setImage(image, data: data, for: url)
/// ```
final class ImageCacheService: @unchecked Sendable {
    static let shared = ImageCacheService()

    // MARK: - Properties

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCacheURL: URL
    private let maxDiskSize: Int = 200 * 1024 * 1024 // 200 MB

    /// Serial queue for thread-safe disk writes.
    private let ioQueue = DispatchQueue(label: "com.wolfwhale.imagecache.io", qos: .utility)

    // MARK: - Init

    private init() {
        // Memory cache limits
        memoryCache.countLimit = 200          // max 200 images
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Disk cache directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("[ImageCacheService] Failed to create disk cache directory: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Public API

    /// Retrieves a cached `Image` for the given URL.
    ///
    /// Checks in-memory first. If not found, checks disk and promotes the result
    /// back into memory for faster subsequent access.
    func getImage(for url: URL) -> Image? {
        let key = cacheKey(for: url)
        let nsKey = key as NSString

        // 1. Check memory cache
        if let entry = memoryCache.object(forKey: nsKey) {
            return entry.image
        }

        // 2. Check disk cache
        let path = diskPath(for: key)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }

        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: path),
              let uiImage = UIImage(data: data) else {
            return nil
        }
        let image = Image(uiImage: uiImage)
        let cost = data.count

        // Promote to memory cache
        let entry = CacheEntry(image: image, cost: cost)
        memoryCache.setObject(entry, forKey: nsKey, cost: cost)

        // Touch the file so LRU eviction works correctly
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: path.path
        )

        return image
        #else
        return nil
        #endif
    }

    /// Stores an image in both memory and disk caches.
    ///
    /// The memory write is synchronous; the disk write is dispatched asynchronously
    /// on a dedicated I/O queue to avoid blocking the caller.
    func setImage(_ image: Image, data: Data, for url: URL) {
        let key = cacheKey(for: url)
        let nsKey = key as NSString
        let cost = data.count

        // Memory cache (synchronous)
        let entry = CacheEntry(image: image, cost: cost)
        memoryCache.setObject(entry, forKey: nsKey, cost: cost)

        // Disk cache (asynchronous)
        let path = diskPath(for: key)
        ioQueue.async { [weak self] in
            do {
                try data.write(to: path, options: .atomic)
            } catch {
                #if DEBUG
                print("[ImageCacheService] Failed to write image to disk cache: \(error.localizedDescription)")
                #endif
            }
            self?.trimDiskCacheIfNeeded()
        }
    }

    /// Removes all entries from both memory and disk caches.
    func clearCache() {
        memoryCache.removeAllObjects()
        ioQueue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.diskCacheURL)
            try? FileManager.default.createDirectory(
                at: self.diskCacheURL,
                withIntermediateDirectories: true
            )
        }
    }

    /// Returns the total number of bytes used by the disk cache.
    func diskCacheSize() -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + size
        }
    }

    // MARK: - Private Helpers

    /// Generates a SHA-256 hex-string cache key from a URL.
    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the file URL on disk for a given cache key.
    private func diskPath(for key: String) -> URL {
        diskCacheURL.appendingPathComponent(key)
    }

    /// Evicts the oldest files when the disk cache exceeds `maxDiskSize`.
    ///
    /// Files are sorted by modification date (oldest first) and removed until
    /// the total size drops below the budget.
    private func trimDiskCacheIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        // Calculate current total size
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []

        for fileURL in files {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else {
                continue
            }
            let size = values.fileSize ?? 0
            let date = values.contentModificationDate ?? .distantPast
            totalSize += size
            fileInfos.append((url: fileURL, size: size, date: date))
        }

        guard totalSize > maxDiskSize else { return }

        // Sort oldest first for LRU eviction
        fileInfos.sort { $0.date < $1.date }

        for info in fileInfos {
            guard totalSize > maxDiskSize else { break }
            try? fm.removeItem(at: info.url)
            totalSize -= info.size
        }
    }
}
