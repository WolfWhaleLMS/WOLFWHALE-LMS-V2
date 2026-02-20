import SwiftUI

struct RadioView: View {
    @State private var radioService = RadioService()
    @State private var selectedStation: RadioService.RadioStation?
    @State private var showingStationPicker = false
    @State private var barAnimations: [CGFloat] = Array(repeating: 0.3, count: 12)
    @State private var animateVisualizer = false
    @State private var hapticTrigger = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    stationCarousel
                    nowPlayingSection
                    controlsSection
                    volumeSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(
                LinearGradient(
                    colors: [
                        stationBackgroundColor.opacity(0.15),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .navigationTitle("WolfWhale Radio")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if radioService.currentStation != nil {
                    miniPlayerBar
                }
            }
            .onAppear {
                startVisualizerAnimation()
            }
        }
    }

    // MARK: - Station Carousel

    private var stationCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stations")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(RadioService.RadioStation.allStations) { station in
                        stationCard(station)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func stationCard(_ station: RadioService.RadioStation) -> some View {
        let isActive = radioService.currentStation == station
        let color = Theme.courseColor(station.color)

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                if isActive {
                    radioService.togglePlayback()
                } else {
                    radioService.play(station: station)
                    selectedStation = station
                }
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 8, y: 2)

                    Image(systemName: station.iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: isActive && radioService.isPlaying)
                }

                VStack(spacing: 3) {
                    Text(station.name)
                        .font(.caption.bold())
                        .lineLimit(1)

                    Text(station.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 110)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(
                isActive
                    ? AnyShapeStyle(color.opacity(0.12))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: .rect(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? color.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(station.name), \(station.description)")
        .accessibilityHint(isActive ? "Currently playing. Double tap to pause." : "Double tap to play.")
    }

    // MARK: - Now Playing Section

    private var nowPlayingSection: some View {
        VStack(spacing: 20) {
            if let station = radioService.currentStation {
                // Visualizer
                audioVisualizer
                    .frame(height: 120)

                VStack(spacing: 6) {
                    Text(station.name)
                        .font(.title2.bold())

                    Text(station.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Live / buffering indicator
                if radioService.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("BUFFERING")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.secondary.opacity(0.1), in: Capsule())
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .opacity(radioService.isPlaying ? 1.0 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: radioService.isPlaying
                            )

                        Text(station.streamURL != nil ? "LIVE STREAM" : "LIVE")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(radioService.isPlaying ? .red : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.1), in: Capsule())
                }

                // Error message
                if let error = radioService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "radio")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Select a Station")
                        .font(.title3.bold())

                    Text("Choose a station above to start listening")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Audio Visualizer

    private var audioVisualizer: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [
                                stationColor.opacity(0.8),
                                stationColor
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8)
                    .frame(height: radioService.isPlaying ? barAnimations[index] * 100 : 10)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.6))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05),
                        value: animateVisualizer
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: 24) {
            // Previous station
            Button {
                hapticTrigger.toggle()
                skipStation(forward: false)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(radioService.currentStation == nil)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("Previous station")

            // Play/Pause button
            Button {
                hapticTrigger.toggle()
                if radioService.currentStation != nil {
                    radioService.togglePlayback()
                } else if let first = RadioService.RadioStation.allStations.first {
                    radioService.play(station: first)
                    selectedStation = first
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [stationColor, stationColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: stationColor.opacity(0.4), radius: 12, y: 4)

                    Image(systemName: radioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel(radioService.isPlaying ? "Pause" : "Play")

            // Next station
            Button {
                hapticTrigger.toggle()
                skipStation(forward: true)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(radioService.currentStation == nil)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("Next station")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Volume Section

    private var volumeSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Volume")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(radioService.volume * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { radioService.volume },
                        set: { radioService.setVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(stationColor)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Volume: \(Int(radioService.volume * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                radioService.setVolume(min(1.0, radioService.volume + 0.1))
            case .decrement:
                radioService.setVolume(max(0.0, radioService.volume - 0.1))
            @unknown default:
                break
            }
        }
    }

    // MARK: - Mini Player Bar

    private var miniPlayerBar: some View {
        Group {
            if let station = radioService.currentStation {
                HStack(spacing: 12) {
                    // Station icon
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.courseColor(station.color), Theme.courseColor(station.color).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: station.iconName)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(station.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play/Pause
                    Button {
                        hapticTrigger.toggle()
                        radioService.togglePlayback()
                    } label: {
                        Image(systemName: radioService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel(radioService.isPlaying ? "Pause" : "Play")

                    // Stop
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) {
                            radioService.stop()
                            selectedStation = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Stop")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
                .padding(.horizontal)
                .padding(.bottom, 4)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
            }
        }
    }

    // MARK: - Helpers

    private var stationColor: Color {
        if let station = radioService.currentStation {
            return Theme.courseColor(station.color)
        }
        return .purple
    }

    private var stationBackgroundColor: Color {
        if let station = radioService.currentStation {
            return Theme.courseColor(station.color)
        }
        return .purple
    }

    private func skipStation(forward: Bool) {
        guard let current = radioService.currentStation else { return }
        let stations = RadioService.RadioStation.allStations
        guard let currentIndex = stations.firstIndex(of: current) else { return }

        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % stations.count
        } else {
            nextIndex = currentIndex == 0 ? stations.count - 1 : currentIndex - 1
        }

        withAnimation(.snappy) {
            let newStation = stations[nextIndex]
            radioService.play(station: newStation)
            selectedStation = newStation
        }
    }

    private func startVisualizerAnimation() {
        // Generate random bar heights for the visualizer
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                if radioService.isPlaying {
                    for i in 0..<barAnimations.count {
                        barAnimations[i] = CGFloat.random(in: 0.2...1.0)
                    }
                    animateVisualizer.toggle()
                }
            }
        }
    }
}

// MARK: - Radio Mini Player (for embedding in tab views)

struct RadioMiniPlayer: View {
    @State private var radioService = RadioService()
    @State private var hapticTrigger = false

    var body: some View {
        if let station = radioService.currentStation {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.courseColor(station.color).gradient)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: station.iconName)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(station.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    radioService.togglePlayback()
                } label: {
                    Image(systemName: radioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    radioService.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .padding(.horizontal)
        }
    }
}
