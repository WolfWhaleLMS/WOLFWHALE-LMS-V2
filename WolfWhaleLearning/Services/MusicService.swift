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

    private let player = ApplicationMusicPlayer.shared

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

    func resume() {
        Task {
            do {
                try await player.play()
                isPlaying = true
            } catch {
                self.error = "Resume failed: \(error.localizedDescription)"
            }
        }
    }

    func skip() {
        Task {
            do {
                try await player.skipToNextEntry()
            } catch {
                self.error = "Skip failed: \(error.localizedDescription)"
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
