import AVFoundation

/// Plays Mozart's Adagio in B Minor, K. 540 on the login screen.
/// Uses ambient audio category so it does not interrupt other apps.
/// Fades in on appear and fades out when the user signs in.
@MainActor
@Observable
class LoginAudioService {
    var isPlaying = false

    private var player: AVPlayer?
    private var fadeTimer: Timer?
    private var loopObserver: Any?

    /// Public domain Mozart - Adagio in B Minor, K. 540 from Wikimedia Commons
    private let mozartURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/5/53/Wolfgang_Amadeus_Mozart_-_Adagio_in_B_minor%2C_K.540.ogg")!

    /// Maximum volume for the login music (kept soft)
    private let maxVolume: Float = 0.3

    /// Duration of the fade-in in seconds
    private let fadeInDuration: TimeInterval = 2.0

    /// Duration of the fade-out in seconds
    private let fadeOutDuration: TimeInterval = 1.0

    // MARK: - Public API

    func startPlaying() {
        guard !isPlaying else { return }

        configureAudioSession()

        let playerItem = AVPlayerItem(url: mozartURL)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 0 // Start silent for fade-in

        // Loop: when the track ends, seek back to the start
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }

        player?.play()
        isPlaying = true

        // Fade in from 0 to maxVolume
        fadeVolume(from: 0, to: maxVolume, duration: fadeInDuration)
    }

    func fadeOutAndStop() {
        guard isPlaying else { return }
        fadeVolume(from: player?.volume ?? maxVolume, to: 0, duration: fadeOutDuration) { [weak self] in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil

        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }

        player?.pause()
        player = nil
        isPlaying = false

        // Deactivate our ambient session so it doesn't linger
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func configureAudioSession() {
        // Use .ambient so we don't interrupt other audio (e.g., music, podcasts)
        // and so the radio's .playback session can take priority when needed.
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal: audio just won't play
            print("[LoginAudioService] Audio session error: \(error.localizedDescription)")
        }
    }

    /// Smoothly transitions the player volume between two values over a given duration.
    private func fadeVolume(from start: Float, to end: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()

        let steps = 30 // number of volume steps
        let interval = duration / Double(steps)
        let delta = (end - start) / Float(steps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                currentStep += 1
                let newVolume = start + delta * Float(currentStep)
                self.player?.volume = newVolume

                if currentStep >= steps {
                    timer.invalidate()
                    self.fadeTimer = nil
                    self.player?.volume = end
                    completion?()
                }
            }
        }
    }

    deinit {
        fadeTimer?.invalidate()
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
    }
}
