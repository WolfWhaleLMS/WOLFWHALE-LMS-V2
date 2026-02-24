import SwiftUI

struct InCallView: View {
    let participantName: String
    @Environment(\.dismiss) private var dismiss
    private var callService: CallService { CallService.shared }
    @State private var pulseAnimation = false

    private var formattedDuration: String {
        let minutes = Int(callService.callDuration) / 60
        let seconds = Int(callService.callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var participantInitial: String {
        String(participantName.prefix(1)).uppercased()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.8),
                    Color.indigo.opacity(0.9),
                    Color.purple.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top section: participant info
                topSection
                    .padding(.top, 60)

                Spacer()

                // Center: avatar with pulse ring
                avatarSection

                Spacer()

                // Bottom: call controls
                controlBar
                    .padding(.bottom, 50)
            }
        }
        .onChange(of: callService.isCallActive) { _, isActive in
            if !isActive {
                dismiss()
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseAnimation = true
            }
        }
        .statusBarHidden()
    }

    // MARK: - Top Section

    private var topSection: some View {
        VStack(spacing: 8) {
            Text(participantName)
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(callService.isCallActive ? formattedDuration : "Connecting...")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                .opacity(pulseAnimation ? 0.0 : 0.6)

            // Middle pulse ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 160, height: 160)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .opacity(pulseAnimation ? 0.2 : 0.8)

            // Avatar circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 140, height: 140)
                .overlay {
                    Text(participantInitial)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .glassEffect(.regular.tint(.indigo.opacity(0.3)), in: .circle)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 40) {
            // Mute button
            callControlButton(
                icon: callService.isMuted ? "mic.slash.fill" : "mic.fill",
                label: callService.isMuted ? "Unmute" : "Mute",
                isActive: callService.isMuted
            ) {
                callService.toggleMute()
            }

            // End call button
            Button {
                callService.endCall()
            } label: {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 72, height: 72)

                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel("End call")
            .hapticFeedback(.impact(weight: .heavy), trigger: callService.isCallActive)

            // Speaker button
            callControlButton(
                icon: callService.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                label: callService.isSpeakerOn ? "Speaker Off" : "Speaker",
                isActive: callService.isSpeakerOn
            ) {
                callService.toggleSpeaker()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: Capsule())
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Call Control Button

    private func callControlButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? .white : .white.opacity(0.2))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isActive ? .indigo : .white)
                }

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    InCallView(participantName: "Jane Smith")
}
