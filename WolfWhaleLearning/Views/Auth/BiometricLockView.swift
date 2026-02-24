import SwiftUI
import Supabase

struct BiometricLockView: View {
    let viewModel: AppViewModel
    var onPasswordFallback: () -> Void = {}

    @State private var isAnimating = false
    @State private var authError: String?
    @State private var showError = false
    @State private var hapticTrigger = false
    @State private var showPasswordField = false
    @State private var passwordText = ""
    @State private var isVerifying = false
    @State private var passwordError: String?
    @State private var passwordAttempts = 0
    private let maxPasswordAttempts = 5

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
                            Theme.brandGradientHorizontal
                        )
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                    .opacity(isAnimating ? 1.0 : 0.0)

                    // Fallback button
                    if showPasswordField {
                        VStack(spacing: 12) {
                            SecureField("Enter your password", text: $passwordText)
                                .textContentType(.password)
                                .padding(14)
                                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))

                            if let passwordError {
                                Text(passwordError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                hapticTrigger.toggle()
                                Task { await verifyPasswordAndUnlock() }
                            } label: {
                                Group {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Submit")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .clipShape(.rect(cornerRadius: 12))
                            .disabled(passwordText.isEmpty || isVerifying)
                        }
                        .opacity(isAnimating ? 1.0 : 0.0)
                    } else {
                        Button {
                            hapticTrigger.toggle()
                            withAnimation(.smooth) {
                                showPasswordField = true
                            }
                        } label: {
                            Text("Enter Password")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.clear)
                        .glassEffect(.regular.tint(.purple), in: RoundedRectangle(cornerRadius: 20))
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

    // MARK: - Password Verification

    private func verifyPasswordAndUnlock() async {
        guard !passwordText.isEmpty else { return }
        guard let email = viewModel.currentUser?.email else {
            passwordError = "Unable to determine your account email."
            return
        }

        // Rate limit password attempts
        guard passwordAttempts < maxPasswordAttempts else {
            passwordError = "Too many attempts. Use biometrics or restart the app."
            return
        }

        isVerifying = true
        passwordError = nil

        do {
            _ = try await supabaseClient.auth.signIn(email: email, password: passwordText)
            passwordAttempts = 0
            onPasswordFallback()
            viewModel.unlockApp()
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .timedOut {
            passwordError = "No internet connection. Use biometrics to unlock."
        } catch {
            passwordAttempts += 1
            let remaining = maxPasswordAttempts - passwordAttempts
            if remaining > 0 {
                passwordError = "Incorrect password. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining."
            } else {
                passwordError = "Too many attempts. Use biometrics or restart the app."
            }
        }

        passwordText = ""
        isVerifying = false
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
