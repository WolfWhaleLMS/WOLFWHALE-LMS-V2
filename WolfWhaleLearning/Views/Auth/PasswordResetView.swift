import SwiftUI

struct PasswordResetView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var authService = AuthService()
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showSuccess = false
    @State private var hapticTrigger = false
    @State private var successHapticTrigger = false
    @State private var errorHapticTrigger = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case newPassword, confirmPassword
    }

    private var allRequirementsMet: Bool {
        let req = PasswordRequirementsView(password: newPassword, confirmPassword: confirmPassword)
        return req.allMet
    }

    private var canSubmit: Bool {
        allRequirementsMet && !authService.isLoading
    }

    var body: some View {
        ZStack {
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
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())

            if showSuccess {
                successOverlay
            }
        }
        .hapticFeedback(.success, trigger: successHapticTrigger)
        .hapticFeedback(.error, trigger: errorHapticTrigger)
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
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.rotation")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Set New Password")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("Create a strong password for your account. Make sure it meets all the requirements below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // New Password field with show/hide toggle
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Group {
                        if showPassword {
                            TextField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                        } else {
                            SecureField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                        }
                    }
                    .focused($focusedField, equals: .newPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }
                    .accessibilityLabel("New password")

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            focusedField == .newPassword ? Color.indigo.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            // Confirm Password field with show/hide toggle
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.badge.checkmark")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Group {
                        if showConfirmPassword {
                            TextField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        } else {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }
                    }
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        if canSubmit { resetPassword() }
                    }
                    .accessibilityLabel("Confirm new password")

                    Button {
                        showConfirmPassword.toggle()
                    } label: {
                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showConfirmPassword ? "Hide password" : "Show password")
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            focusedField == .confirmPassword ? Color.indigo.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            // Password requirements checklist
            if !newPassword.isEmpty {
                PasswordRequirementsView(password: newPassword, confirmPassword: confirmPassword)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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

            // Reset Password button
            Button {
                hapticTrigger.toggle()
                focusedField = nil
                resetPassword()
            } label: {
                Group {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Reset Password")
                                .font(.headline)
                            Image(systemName: "checkmark.shield.fill")
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
            .disabled(!canSubmit)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel(authService.isLoading ? "Resetting password" : "Reset Password")
            .accessibilityHint("Double tap to set your new password")
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccess)

                Text("Password Updated!")
                    .font(.title3.bold())

                Text("Your password has been reset successfully. Redirecting to login...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ProgressView()
                    .tint(.indigo)
                    .padding(.top, 4)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(duration: 0.4), value: showSuccess)
    }

    // MARK: - Actions

    private func resetPassword() {
        guard canSubmit else { return }

        Task {
            let success = await authService.updatePassword(newPassword: newPassword)
            if success {
                successHapticTrigger.toggle()
                withAnimation(.spring(duration: 0.4)) {
                    showSuccess = true
                }
                // Wait then dismiss/redirect to login
                try? await Task.sleep(for: .seconds(2.5))
                viewModel.logout()
            } else {
                errorHapticTrigger.toggle()
            }
        }
    }
}
