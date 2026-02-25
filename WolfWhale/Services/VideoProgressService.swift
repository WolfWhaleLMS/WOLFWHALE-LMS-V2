import Foundation

// MARK: - Persisted Progress

private struct VideoProgressData: Codable {
    var currentTime: Double
    var duration: Double
}

// MARK: - VideoProgressService

@MainActor
@Observable
final class VideoProgressService {

    // MARK: - State

    var error: String?
    var isLoading = false

    // MARK: - Keys

    private static func key(for lessonId: UUID) -> String {
        "video_progress_\(lessonId.uuidString)"
    }

    private static let watchedKey = "video_watched_lessons"

    // MARK: - Save / Restore Progress

    /// Saves the current playback position and total duration for a lesson.
    func saveProgress(lessonId: UUID, currentTime: Double, duration: Double) {
        let data = VideoProgressData(currentTime: currentTime, duration: duration)
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: Self.key(for: lessonId))

            // Auto-mark as watched when the user has seen more than 90 %
            if duration > 0, currentTime / duration >= 0.9 {
                markAsWatched(lessonId: lessonId)
            }
        } catch {
            self.error = "Failed to save video progress."
            #if DEBUG
            print("[VideoProgress] Encode error: \(error)")
            #endif
        }
    }

    /// Returns the saved playback position for a lesson, or `nil` if nothing was stored.
    func getProgress(lessonId: UUID) -> (currentTime: Double, duration: Double)? {
        guard let data = UserDefaults.standard.data(forKey: Self.key(for: lessonId)) else {
            return nil
        }
        do {
            let decoded = try JSONDecoder().decode(VideoProgressData.self, from: data)
            return (decoded.currentTime, decoded.duration)
        } catch {
            self.error = "Failed to read video progress."
            #if DEBUG
            print("[VideoProgress] Decode error: \(error)")
            #endif
            return nil
        }
    }

    /// Returns a value between 0.0 and 1.0 representing how much of the video has been watched.
    func getCompletionPercentage(lessonId: UUID) -> Double {
        guard let progress = getProgress(lessonId: lessonId),
              progress.duration > 0 else {
            return 0
        }
        return min(progress.currentTime / progress.duration, 1.0)
    }

    /// Explicitly marks a lesson as fully watched (persisted in a separate set of UUIDs).
    func markAsWatched(lessonId: UUID) {
        var watched = watchedSet()
        watched.insert(lessonId.uuidString)
        UserDefaults.standard.set(Array(watched), forKey: Self.watchedKey)
    }

    /// Whether the lesson has been marked as watched (>= 90 % or explicitly).
    func isWatched(lessonId: UUID) -> Bool {
        watchedSet().contains(lessonId.uuidString)
    }

    /// Returns a dictionary mapping each tracked lesson id to its completion percentage.
    func getAllProgress() -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys

        for key in allKeys where key.hasPrefix("video_progress_") {
            let uuidString = String(key.dropFirst("video_progress_".count))
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            result[uuid] = getCompletionPercentage(lessonId: uuid)
        }
        return result
    }

    // MARK: - Helpers

    private func watchedSet() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: Self.watchedKey) ?? []
        return Set(array)
    }
}
