import SwiftUI
import Supabase

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var hapticTrigger = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                headerSection

                Spacer().frame(height: 40)

                formSection

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Color.clear.ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.cyan.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Reset Password")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("Enter the email address associated with your account and we'll send you a link to reset your password.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email field
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
                TextField("School Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isEmailFocused)
                    .submitLabel(.go)
                    .onSubmit { resetPassword() }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isEmailFocused ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
            )

            // Error message
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Success message
            if let successMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(successMessage)
                        .font(.caption)
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Reset Password button
            Button {
                hapticTrigger.toggle()
                isEmailFocused = false
                resetPassword()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Reset Password")
                                .font(.headline)
                            Image(systemName: "envelope.badge.fill")
                                .font(.subheadline.bold())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.purple)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(isLoading || email.isEmpty)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            // Back to Login button
            Button {
                hapticTrigger.toggle()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.subheadline)
                    Text("Back to Login")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.purple)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .padding(.top, 4)
        }
    }

    // MARK: - Reset Password

    private func resetPassword() {
        guard !email.isEmpty else {
            withAnimation(.smooth) {
                errorMessage = "Please enter your email address"
                successMessage = nil
            }
            return
        }

        guard email.contains("@") && email.contains(".") else {
            withAnimation(.smooth) {
                errorMessage = "Please enter a valid email address"
                successMessage = nil
            }
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await supabaseClient.auth.resetPasswordForEmail(email)
                withAnimation(.smooth) {
                    successMessage = "Check your email for a password reset link"
                    errorMessage = nil
                }
            } catch {
                withAnimation(.smooth) {
                    errorMessage = mapResetError(error)
                    successMessage = nil
                }
            }
            isLoading = false
        }
    }

    private func mapResetError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid") || message.contains("email") {
            return "Please check your email address and try again"
        } else if message.contains("rate") || message.contains("limit") {
            return "Too many requests. Please wait a moment and try again"
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection"
        }
        return "Unable to send reset email. Please try again."
    }
}
