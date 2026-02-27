import SwiftUI
import AVKit
import Combine

struct VideoPlayerView: View {
    let url: URL
    let title: String
    let lessonId: UUID?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackSpeed: Float = 1.0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls = true
    @State private var showSpeedPicker = false
    @State private var hasError = false
    @State private var timeObserver: Any?
    @State private var failureObserver: NSObjectProtocol?
    @State private var completionObserver: NSObjectProtocol?
    @State private var progressService = VideoProgressService()
    @State private var controlsTimer: Timer?

    var body: some View {
        ZStack {
            // Video layer
            if hasError {
                errorPlaceholder
            } else if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .horizontal)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showControls.toggle()
                        }
                        scheduleControlsHide()
                    }
            } else {
                ProgressView("Loading video...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }

            // Controls overlay
            if showControls && !hasError {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .background(Color.black)
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: tearDown)
    }

    // MARK: - Error Placeholder

    private var errorPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("Video Unavailable")
                .font(.headline)
                .foregroundStyle(.white)
            Text("This video could not be loaded. Please check your connection and try again.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top bar: title + speed toggle
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showSpeedPicker.toggle()
                    }
                } label: {
                    Text(speedLabel)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Speed picker row
            if showSpeedPicker {
                PlaybackSpeedPicker(selectedSpeed: $playbackSpeed)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onChange(of: playbackSpeed) { _, newSpeed in
                        player?.rate = newSpeed
                        if !(player?.timeControlStatus == .playing) {
                            // If we were paused, keep paused but store the rate for next play
                        }
                    }
            }

            Spacer()

            // Center play/pause
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
            }
            .buttonStyle(.plain)

            Spacer()

            // Bottom bar: progress + time
            VStack(spacing: 6) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.indigo)
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(value.location.x / geometry.size.width, 1.0))
                                let seekTime = fraction * duration
                                player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                                currentTime = seekTime
                            }
                    )
                }
                .frame(height: 4)

                // Time labels
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("-\(formatTime(max(0, duration - currentTime)))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Setup

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: url)
        avPlayer.allowsExternalPlayback = true // AirPlay

        // Restore saved position
        if let lessonId, let saved = progressService.getProgress(lessonId: lessonId) {
            let seekTime = CMTime(seconds: saved.currentTime, preferredTimescale: 600)
            avPlayer.seek(to: seekTime)
            duration = saved.duration
            currentTime = saved.currentTime
        }

        // Observe duration once the asset is ready
        Task {
            if let item = avPlayer.currentItem {
                let assetDuration = try? await item.asset.load(.duration)
                if let assetDuration, assetDuration.isNumeric {
                    duration = assetDuration.seconds
                }
            }
        }

        // Periodic time observer (every 0.5 seconds for UI, saves every ~5 seconds)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let observer = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard time.isNumeric else { return }
            let seconds = time.seconds
            Task { @MainActor in
                currentTime = seconds

                // Update duration if it was unknown
                if duration <= 0, let item = avPlayer.currentItem {
                    let itemDuration = item.duration
                    if itemDuration.isNumeric {
                        duration = itemDuration.seconds
                    }
                }

                // Save progress every ~5 seconds (every 10th callback)
                if let lessonId, Int(seconds * 2) % 10 == 0, duration > 0 {
                    progressService.saveProgress(
                        lessonId: lessonId,
                        currentTime: seconds,
                        duration: duration
                    )
                }
            }
        }
        timeObserver = observer

        // Observe errors via notification
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                hasError = true
            }
        }

        // Observe playback status
        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                isPlaying = false
                if let lessonId {
                    progressService.markAsWatched(lessonId: lessonId)
                }
            }
        }

        player = avPlayer
        scheduleControlsHide()
    }

    private func tearDown() {
        // Save final position
        if let lessonId, duration > 0 {
            progressService.saveProgress(
                lessonId: lessonId,
                currentTime: currentTime,
                duration: duration
            )
        }

        // Remove time observer
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil

        // Remove NotificationCenter observers
        if let observer = failureObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = completionObserver { NotificationCenter.default.removeObserver(observer) }
        failureObserver = nil
        completionObserver = nil

        player?.pause()
        player = nil

        controlsTimer?.invalidate()
        controlsTimer = nil
    }

    // MARK: - Playback

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.playImmediately(atRate: playbackSpeed)
        }
        isPlaying.toggle()
        scheduleControlsHide()
    }

    // MARK: - Auto-hide controls

    private func scheduleControlsHide() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                if isPlaying {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls = false
                        showSpeedPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return totalWidth * CGFloat(min(currentTime / duration, 1.0))
    }

    private var speedLabel: String {
        if playbackSpeed == Float(Int(playbackSpeed)) {
            return "\(Int(playbackSpeed))x"
        }
        return String(format: "%.2gx", playbackSpeed)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
