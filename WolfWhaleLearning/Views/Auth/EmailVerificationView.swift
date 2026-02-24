import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let onVerified: () -> Void
    let onChangeEmail: () -> Void

    @State private var authService = AuthService()
    @State private var resendCooldown: Int = 0
    @State private var isCheckingStatus = false
    @State private var isVerified = false
    @State private var envelopeBounce = false
    @State private var hapticTrigger = false
    @State private var successHapticTrigger = false
    @State private var errorHapticTrigger = false
    @State private var autoCheckTask: Task<Void, Never>?

    private var canResend: Bool {
        resendCooldown <= 0 && !authService.isLoading
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    headerSection

                    Spacer().frame(height: 40)

                    actionsSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())

            if isVerified {
                verifiedOverlay
            }
        }
        .hapticFeedback(.success, trigger: successHapticTrigger)
        .hapticFeedback(.error, trigger: errorHapticTrigger)
        .onAppear {
            startAutoCheck()
        }
        .onDisappear {
            autoCheckTask?.cancel()
            autoCheckTask = nil
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.15), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: envelopeBounce)
            }
            .onAppear {
                // Animate the envelope on appear
                withAnimation(.spring(duration: 0.6).delay(0.3)) {
                    envelopeBounce.toggle()
                }
            }

            Text("Verify Your Email")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("We sent a verification link to")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(email)
                .font(.subheadline.bold())
                .foregroundStyle(.indigo)
                .multilineTextAlignment(.center)

            Text("Check your inbox and click the link to verify your email address.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Error message
            if let error = authService.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Check Verification Status button
            Button {
                hapticTrigger.toggle()
                checkVerification()
            } label: {
                Group {
                    if isCheckingStatus {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Check Verification Status")
                                .font(.headline)
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.bold())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(isCheckingStatus)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel(isCheckingStatus ? "Checking verification" : "Check Verification Status")

            // Resend Email button
            Button {
                hapticTrigger.toggle()
                resendEmail()
            } label: {
                Group {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.indigo)
                    } else {
                        HStack(spacing: 8) {
                            Text(canResend ? "Resend Email" : "Resend in \(resendCooldown)s")
                                .font(.headline)
                            if canResend {
                                Image(systemName: "envelope.arrow.triangle.branch.fill")
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(!canResend)
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel(canResend ? "Resend verification email" : "Resend in \(resendCooldown) seconds")

            // Auto-check info
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text("Automatically checking every 5 seconds")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)

            // Use a different email link
            Button {
                hapticTrigger.toggle()
                autoCheckTask?.cancel()
                autoCheckTask = nil
                onChangeEmail()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.subheadline)
                    Text("Use a different email")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.indigo)
            }
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .padding(.top, 8)
            .accessibilityHint("Double tap to go back to signup and use a different email")
        }
    }

    // MARK: - Verified Overlay

    private var verifiedOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isVerified)

                Text("Email Verified!")
                    .font(.title3.bold())

                Text("Your email has been verified successfully. You can now sign in to your account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    hapticTrigger.toggle()
                    onVerified()
                } label: {
                    Text("Continue to Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .clipShape(.rect(cornerRadius: 12))
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .padding(.top, 8)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(duration: 0.4), value: isVerified)
    }

    // MARK: - Actions

    private func checkVerification() {
        isCheckingStatus = true
        Task {
            let verified = await authService.checkEmailVerification()
            isCheckingStatus = false
            if verified {
                successHapticTrigger.toggle()
                withAnimation(.spring(duration: 0.4)) {
                    isVerified = true
                }
            }
        }
    }

    private func resendEmail() {
        Task {
            let success = await authService.resendVerificationEmail(email: email)
            if success {
                successHapticTrigger.toggle()
                startCooldown()
            } else {
                errorHapticTrigger.toggle()
            }
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                resendCooldown -= 1
            }
        }
    }

    private func startAutoCheck() {
        autoCheckTask?.cancel()
        autoCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }

                let verified = await authService.checkEmailVerification()
                if verified {
                    await MainActor.run {
                        successHapticTrigger.toggle()
                        withAnimation(.spring(duration: 0.4)) {
                            isVerified = true
                        }
                    }
                    break
                }
            }
        }
    }
}
