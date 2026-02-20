import SwiftUI
import MusicKit

struct MusicDiscoveryView: View {
    @State private var musicService = MusicService()
    @State private var searchText = ""
    @State private var hapticTrigger = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    if !musicService.isAuthorized {
                        authorizationSection
                    } else if !musicService.hasSubscription {
                        noSubscriptionSection
                    } else {
                        studyPlaylistsSection
                        searchSection
                        searchResultsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, musicService.isPlaying ? 100 : 24)
            }
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.12), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
            )

            if musicService.isPlaying, let track = musicService.nowPlaying {
                nowPlayingBar(track: track)
            }
        }
        .navigationTitle("Discover Music")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            musicService.checkAuthorizationStatus()
            if musicService.isAuthorized {
                musicService.hasSubscription = await musicService.checkSubscriptionStatus()
                if musicService.hasSubscription {
                    await musicService.fetchStudyPlaylists()
                }
            }
        }
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple.gradient)

            Text("Apple Music")
                .font(.title2.bold())

            Text("Connect your Apple Music account to discover study playlists and play music while you learn.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                hapticTrigger.toggle()
                Task {
                    await musicService.requestAuthorization()
                    if musicService.isAuthorized && musicService.hasSubscription {
                        await musicService.fetchStudyPlaylists()
                    }
                }
            } label: {
                Label("Connect Apple Music", systemImage: "apple.logo")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.purple.gradient, in: .rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - No Subscription Section

    private var noSubscriptionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.tv.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Apple Music Subscription Required")
                .font(.title3.bold())

            Text("An active Apple Music subscription is needed to play songs and playlists. You can subscribe in the Music app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Study Playlists

    private var studyPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Study Playlists")
                    .font(.headline)
                Spacer()
                if musicService.isLoading && musicService.studyPlaylists.isEmpty {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if musicService.studyPlaylists.isEmpty && !musicService.isLoading {
                Text("No playlists found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(musicService.studyPlaylists) { playlist in
                            playlistCard(playlist)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func playlistCard(_ playlist: Playlist) -> some View {
        Button {
            hapticTrigger.toggle()
            Task {
                await musicService.playPlaylist(playlist)
            }
        } label: {
            VStack(spacing: 10) {
                if let artwork = playlist.artwork {
                    ArtworkImage(artwork, width: 120, height: 120)
                        .clipShape(.rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.purple.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.title)
                                .foregroundStyle(.purple)
                        }
                }

                VStack(spacing: 3) {
                    Text(playlist.name)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(playlist.curatorName ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 130)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Apple Music")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search songs, artists...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task {
                            await musicService.searchStudyMusic(query: searchText)
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        musicService.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if musicService.isLoading && !musicService.searchResults.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let errorMessage = musicService.error {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if !musicService.searchResults.isEmpty {
                Text("Results")
                    .font(.headline)

                LazyVStack(spacing: 8) {
                    ForEach(musicService.searchResults) { song in
                        songRow(song)
                    }
                }
            }
        }
    }

    private func songRow(_ song: Song) -> some View {
        Button {
            hapticTrigger.toggle()
            Task {
                await musicService.play(song: song)
            }
        } label: {
            HStack(spacing: 12) {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.purple.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.purple)
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Now Playing Bar

    private func nowPlayingBar(track: MusicService.Track) -> some View {
        HStack(spacing: 12) {
            if let url = track.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.purple.opacity(0.2))
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Playback controls
            Button {
                hapticTrigger.toggle()
                musicService.togglePlayback()
            } label: {
                Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Button {
                hapticTrigger.toggle()
                musicService.skip()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.bottom, 4)
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
    }
}
