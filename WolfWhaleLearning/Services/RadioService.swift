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

    struct RadioStation: Identifiable, Hashable {
        let id: UUID
        let name: String
        let description: String
        let streamURL: URL?
        let iconName: String
        let color: String

        // Built-in stations
        static let lofiStudy = RadioStation(
            id: UUID(),
            name: "Lo-Fi Study",
            description: "Relaxing beats for studying",
            streamURL: nil,
            iconName: "headphones",
            color: "purple"
        )
        static let schoolNews = RadioStation(
            id: UUID(),
            name: "School News",
            description: "Latest school announcements",
            streamURL: nil,
            iconName: "megaphone.fill",
            color: "blue"
        )
        static let classicalFocus = RadioStation(
            id: UUID(),
            name: "Classical Focus",
            description: "Classical music for concentration",
            streamURL: nil,
            iconName: "music.note",
            color: "orange"
        )
        static let natureSounds = RadioStation(
            id: UUID(),
            name: "Nature Sounds",
            description: "Ambient nature for calm focus",
            streamURL: nil,
            iconName: "leaf.fill",
            color: "green"
        )

        static let allStations: [RadioStation] = [lofiStudy, schoolNews, classicalFocus, natureSounds]
    }

    func play(station: RadioStation) {
        currentStation = station
        isLoading = true
        error = nil

        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            self.error = "Could not configure audio: \(error.localizedDescription)"
        }

        if let url = station.streamURL {
            player = AVPlayer(url: url)
            player?.volume = volume
            player?.play()
        }

        isPlaying = true
        isLoading = false

        setupNowPlayingInfo()
        setupRemoteCommandCenter()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func resume() {
        player?.play()
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
        player?.pause()
        player = nil
        isPlaying = false
        currentStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
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
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayback()
            }
            return .success
        }
    }
}
