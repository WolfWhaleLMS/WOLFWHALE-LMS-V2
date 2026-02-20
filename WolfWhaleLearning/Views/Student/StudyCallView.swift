import SwiftUI

struct StudyCallView: View {
    @State private var callService = CallService()
    @State private var peerService = PeerService()
    @State private var hapticTrigger = false
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        Group {
            if callService.isInCall {
                activeCallScreen
            } else {
                contactListScreen
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(callService.isInCall ? "Study Call" : "Study Calls")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            peerService.startAdvertising(displayName: UIDevice.current.name)
            peerService.startBrowsing()
        }
        .onDisappear {
            if callService.isInCall {
                callService.endCall()
            }
            peerService.disconnect()
        }
    }

    // MARK: - Active Call Screen

    private var activeCallScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Caller avatar
            callerAvatar
                .padding(.bottom, 16)

            // Caller name
            Text(callService.callerName)
                .font(.title2.bold())
                .padding(.bottom, 4)

            // Call duration
            Text(callService.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: callService.callDuration)

            // Audio wave visualization
            audioWaveView
                .frame(height: 60)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

            Spacer()

            // Call controls
            callControls
                .padding(.bottom, 50)
        }
        .padding(.horizontal)
    }

    private var callerAvatar: some View {
        let initials = callService.callerName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()

        return ZStack {
            Circle()
                .fill(.green.gradient)
                .frame(width: 100, height: 100)
                .shadow(color: .green.opacity(0.3), radius: 20, y: 4)

            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var audioWaveView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let width = size.width
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Draw multiple sine waves with different phases and amplitudes
                for waveIndex in 0..<3 {
                    let waveOffset = Double(waveIndex) * 0.8
                    let baseAmplitude: CGFloat = callService.isMuted ? 2 : CGFloat(12 - waveIndex * 3)
                    let alpha: CGFloat = CGFloat(1.0 - Double(waveIndex) * 0.3)

                    var path = Path()
                    let steps = Int(width)

                    for x in 0...steps {
                        let xPos = CGFloat(x)
                        let normalizedX = Double(xPos) / Double(width)
                        let frequency = 3.0 + Double(waveIndex) * 0.5
                        let phase = time * (2.0 + Double(waveIndex) * 0.4) + waveOffset

                        // Combine multiple frequencies for organic feel
                        let wave1 = sin(normalizedX * .pi * 2 * frequency + phase)
                        let wave2 = sin(normalizedX * .pi * 2 * (frequency * 1.5) + phase * 0.7) * 0.3
                        let combined = wave1 + wave2

                        // Taper at edges
                        let envelope = sin(normalizedX * .pi)
                        let amplitude = baseAmplitude * envelope

                        let yPos = midY + CGFloat(combined) * amplitude

                        if x == 0 {
                            path.move(to: CGPoint(x: xPos, y: yPos))
                        } else {
                            path.addLine(to: CGPoint(x: xPos, y: yPos))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(.green.opacity(alpha)),
                        lineWidth: CGFloat(2.5 - Double(waveIndex) * 0.5)
                    )
                }
            }
        }
    }

    private var callControls: some View {
        HStack(spacing: 40) {
            // Mute button
            Button {
                hapticTrigger.toggle()
                callService.toggleMute()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: callService.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(
                            callService.isMuted ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle()
                        )
                        .foregroundStyle(callService.isMuted ? .red : .primary)

                    Text(callService.isMuted ? "Unmute" : "Mute")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel(callService.isMuted ? "Unmute microphone" : "Mute microphone")

            // End call button
            Button {
                hapticTrigger.toggle()
                callService.endCall()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                        .background(.red.gradient, in: Circle())
                        .foregroundStyle(.white)

                    Text("End")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            .accessibilityLabel("End call")

            // Speaker button
            Button {
                hapticTrigger.toggle()
                callService.toggleSpeaker()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: callService.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(
                            callService.isSpeakerOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle()
                        )
                        .foregroundStyle(callService.isSpeakerOn ? .green : .primary)

                    Text("Speaker")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel(callService.isSpeakerOn ? "Disable speaker" : "Enable speaker")
        }
    }

    // MARK: - Contact List Screen (Pre-Call)

    private var contactListScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                callHeroCard
                connectedPeersCallList
                nearbyPeersCallList
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private var callHeroCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .symbolEffect(.pulse, isActive: peerService.isBrowsing)

            Text("Study Calls")
                .font(.headline)

            Text("Voice chat with nearby classmates using peer-to-peer. Tap a connected peer to start a call.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !peerService.isAdvertising && !peerService.isBrowsing {
                Button {
                    hapticTrigger.toggle()
                    peerService.startAdvertising(displayName: UIDevice.current.name)
                    peerService.startBrowsing()
                } label: {
                    Label("Start Discovering", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.green.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private var connectedPeersCallList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Peers")
                .font(.headline)

            if peerService.connectedPeers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("No connected peers yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                ForEach(peerService.connectedPeers, id: \.displayName) { peer in
                    Button {
                        hapticTrigger.toggle()
                        callService.startCall(to: peer.displayName, displayName: peer.displayName)
                    } label: {
                        peerCallRow(
                            name: peer.displayName,
                            status: "Connected",
                            statusColor: .green,
                            canCall: true
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                    .accessibilityLabel("Call \(peer.displayName)")
                    .accessibilityHint("Double tap to start a voice call")
                }
            }
        }
    }

    private var nearbyPeersCallList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Students")
                    .font(.headline)
                Spacer()
                if peerService.isBrowsing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if peerService.nearbyPeers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("Scanning for nearby students...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                ForEach(peerService.nearbyPeers, id: \.displayName) { peer in
                    Button {
                        hapticTrigger.toggle()
                        peerService.invitePeer(peer)
                    } label: {
                        peerCallRow(
                            name: peer.displayName,
                            status: "Tap to connect first",
                            statusColor: .orange,
                            canCall: false
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Connect to \(peer.displayName)")
                    .accessibilityHint("Double tap to invite this student to connect")
                }
            }
        }
    }

    private func peerCallRow(name: String, status: String, statusColor: Color, canCall: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar with initials
            Circle()
                .fill(canCall ? Color.green.gradient : Color.gray.gradient)
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if canCall {
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .padding(8)
                    .background(.green.opacity(0.12), in: Circle())
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
