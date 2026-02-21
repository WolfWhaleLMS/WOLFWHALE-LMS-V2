import AVFoundation
import MediaPlayer

@MainActor
@Observable
class RadioService {
    var isPlaying = false
    var currentStation: RadioStation?
    var volume: Float = 0.7
    var isLoading = false
    var error: String?

    private var player: AVPlayer?
    private var playerItemObserver: NSKeyValueObservation?
    private var commandCenterConfigured = false

    struct RadioStation: Identifiable, Hashable {
        let id: UUID
        let name: String
        let description: String
        let streamURL: URL?
        let iconName: String
        let color: String

        static let classicalFocus = RadioStation(
            id: UUID(),
            name: "Classical Focus",
            description: "Royalty-free classical for concentration",
            streamURL: URL(string: "https://live.musopen.org:8085/streamvbr0"),
            iconName: "pianokeys",
            color: "orange"
        )
        static let lofiStudy = RadioStation(
            id: UUID(),
            name: "Lo-Fi Study",
            description: "Chill beats for studying",
            streamURL: URL(string: "https://streams.fluxfm.de/Chillhop/mp3-128/streams.fluxfm.de/"),
            iconName: "headphones",
            color: "purple"
        )
        static let ambientNature = RadioStation(
            id: UUID(),
            name: "Ambient Study",
            description: "Ambient sounds for calm focus",
            streamURL: URL(string: "https://stream.0nlineradio.com/classical"),
            iconName: "leaf.fill",
            color: "green"
        )
        static let schoolNews = RadioStation(
            id: UUID(),
            name: "School News",
            description: "Latest school announcements",
            streamURL: nil,
            iconName: "megaphone.fill",
            color: "blue"
        )

        static let allStations: [RadioStation] = [classicalFocus, lofiStudy, ambientNature, schoolNews]
    }

    func play(station: RadioStation) {
        stopPlayer()

        currentStation = station
        isLoading = true
        error = nil

        setupRemoteCommandCenter()
        setupNowPlayingInfo()

        guard let url = station.streamURL else {
            isPlaying = true
            isLoading = false
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                await MainActor.run {
                    self.error = "Could not configure audio: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            let playerItem = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: playerItem)

            await MainActor.run {
                self.player = newPlayer
                self.player?.volume = self.volume

                self.playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak playerItem] item, _ in
                    guard playerItem != nil else { return }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        switch item.status {
                        case .readyToPlay:
                            self.isLoading = false
                        case .failed:
                            self.isLoading = false
                            self.error = "Failed to load stream. Check your connection."
                            self.isPlaying = false
                        default:
                            break
                        }
                    }
                }

                self.player?.play()
                self.isPlaying = true
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func resume() {
        if let currentStation, currentStation.streamURL != nil {
            player?.play()
        }
        isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else if currentStation != nil {
            resume()
        }
    }

    func stop() {
        stopPlayer()
        currentStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }

    private func stopPlayer() {
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        isLoading = false
    }

    private func setupNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentStation?.name ?? "WolfWhale Radio"
        info[MPMediaItemPropertyArtist] = currentStation?.description ?? ""
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = currentStation?.name ?? "WolfWhale Radio"
        info[MPMediaItemPropertyArtist] = currentStation?.description ?? ""
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommandCenter() {
        guard !commandCenterConfigured else { return }
        commandCenterConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
    }
}
