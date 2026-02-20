import SwiftUI

struct BiometricLockView: View {
    let viewModel: AppViewModel
    var onPasswordFallback: () -> Void = {}

    @State private var isAnimating = false
    @State private var authError: String?
    @State private var showError = false
    @State private var hapticTrigger = false

    private var biometricService: BiometricAuthService {
        viewModel.biometricService
    }

    var body: some View {
        ZStack {
            // Blurred background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(.rect(cornerRadius: 24))
                    .shadow(color: .purple.opacity(0.3), radius: 20, y: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)

                VStack(spacing: 8) {
                    Text("WolfWhale is Locked")
                        .font(.title2.bold())
                        .opacity(isAnimating ? 1.0 : 0.0)

                    Text("Authenticate to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }

                Spacer()

                // Biometric unlock button
                VStack(spacing: 16) {
                    Button {
                        hapticTrigger.toggle()
                        Task { await authenticateWithBiometric() }
                    } label: {
                        Label(
                            "Unlock with \(biometricService.biometricName)",
                            systemImage: biometricService.biometricSystemImage
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                    .opacity(isAnimating ? 1.0 : 0.0)

                    // Fallback button
                    Button {
                        hapticTrigger.toggle()
                        onPasswordFallback()
                        viewModel.unlockApp()
                    } label: {
                        Text("Enter Password")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .opacity(isAnimating ? 1.0 : 0.0)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authError ?? "An unknown error occurred.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
            // Auto-trigger biometric on appear
            Task {
                // Short delay so the animation plays first
                try? await Task.sleep(for: .milliseconds(400))
                await authenticateWithBiometric()
            }
        }
    }

    // MARK: - Biometric Authentication

    private func authenticateWithBiometric() async {
        do {
            let success = try await biometricService.authenticate()
            if success {
                viewModel.unlockApp()
            }
        } catch let error as BiometricError {
            switch error {
            case .cancelled, .userFallback:
                // User cancelled or chose password — do nothing
                break
            default:
                authError = error.localizedDescription
                showError = true
            }
        } catch {
            authError = error.localizedDescription
            showError = true
        }
    }
}
