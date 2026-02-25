import AVFoundation
import Foundation
import MusicKit
import Observation

@MainActor
@Observable
class MusicService {
    var isAuthorized = false
    var isPlaying = false
    var currentTrack: Track?
    var studyPlaylists: [Playlist] = []
    var searchResults: MusicItemCollection<Song>?
    var hasSubscription = false
    var isLoading = false
    var error: String?

    // Lazily access ApplicationMusicPlayer.shared to avoid crash at init
    // when MusicKit entitlement is missing (no Apple Developer account).
    private var player: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

    /// In-flight search task; cancelled on each new search to debounce requests.
    private var searchTask: Task<Void, Never>?

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        isAuthorized = status == .authorized
        if isAuthorized {
            hasSubscription = await checkSubscriptionStatus()
        }
    }

    func checkAuthorizationStatus() {
        isAuthorized = MusicAuthorization.currentStatus == .authorized
    }

    func checkSubscriptionStatus() async -> Bool {
        do {
            let subscription = try await MusicSubscription.current
            return subscription.canPlayCatalogContent
        } catch {
            self.error = "Could not check subscription: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Search

    func searchStudyMusic(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = nil
            return
        }

        isLoading = true
        error = nil

        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            searchResults = response.songs
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
            searchResults = nil
        }

        isLoading = false
    }

    /// Debounced search: cancels any in-flight search and waits 300ms before executing.
    func searchDebounced(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await searchStudyMusic(query: query)
        }
    }

    func fetchStudyPlaylists() async {
        isLoading = true
        error = nil

        let queries = ["study music", "focus music", "classical study", "lo-fi beats"]
        var allPlaylists: [Playlist] = []
        var seenIDs: Set<MusicItemID> = []

        for query in queries {
            do {
                var request = MusicCatalogSearchRequest(term: query, types: [Playlist.self])
                request.limit = 5
                let response = try await request.response()
                for playlist in response.playlists {
                    if !seenIDs.contains(playlist.id) {
                        seenIDs.insert(playlist.id)
                        allPlaylists.append(playlist)
                    }
                }
            } catch {
                continue
            }
        }

        studyPlaylists = allPlaylists
        isLoading = false
    }

    // MARK: - Playback

    func play(song: Song) async {
        guard hasSubscription else {
            error = "An Apple Music subscription is required for playback."
            return
        }

        do {
            player.queue = [song]
            try await player.play()
            isPlaying = true
            currentTrack = Track(
                title: song.title,
                artistName: song.artistName,
                artworkURL: song.artwork?.url(width: 300, height: 300)
            )
            error = nil
        } catch {
            self.error = "Playback failed: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func playPlaylist(_ playlist: Playlist) async {
        guard hasSubscription else {
            error = "An Apple Music subscription is required for playback."
            return
        }

        do {
            player.queue = [playlist]
            try await player.play()
            isPlaying = true
            currentTrack = Track(
                title: playlist.name,
                artistName: playlist.curatorName ?? "Apple Music",
                artworkURL: playlist.artwork?.url(width: 300, height: 300)
            )
            error = nil
        } catch {
            self.error = "Playback failed: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    /// Stops playback and clears the current track.
    func stop() {
        player.stop()
        isPlaying = false
        currentTrack = nil
    }

    /// Stops all playback, clears state, cancels pending searches,
    /// and deactivates the audio session. Call on logout or app teardown.
    func stopAll() {
        searchTask?.cancel()
        searchTask = nil

        player.stop()
        isPlaying = false
        currentTrack = nil
        searchResults = nil
        error = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[MusicService] Failed to deactivate audio session: \(error)")
            #endif
        }
    }

    func resume() {
        Task {
            do {
                try await player.play()
                isPlaying = true
                error = nil
            } catch {
                self.error = "Resume failed: \(error.localizedDescription)"
                isPlaying = false
            }
        }
    }

    func skip() {
        Task {
            do {
                try await player.skipToNextEntry()
                error = nil
            } catch {
                self.error = "Skip failed: \(error.localizedDescription)"
                isPlaying = false
            }
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    // MARK: - Now Playing

    var nowPlaying: Track? {
        currentTrack
    }

    struct Track {
        let title: String
        let artistName: String
        let artworkURL: URL?
    }
}
