import SwiftUI
import Supabase

struct DeleteAccountView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var authService = AuthService()
    @State private var confirmationText = ""
    @State private var reAuthPassword = ""
    @State private var reAuthError: String?
    @State private var hapticTrigger = false
    @State private var errorHapticTrigger = false
    @State private var successHapticTrigger = false
    @FocusState private var isConfirmFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    private var canDelete: Bool {
        confirmationText == "DELETE" && !reAuthPassword.isEmpty && !authService.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                headerSection

                Spacer().frame(height: 32)

                deletionInfoSection

                Spacer().frame(height: 24)

                warningSection

                Spacer().frame(height: 32)

                confirmationSection

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.error, trigger: errorHapticTrigger)
        .hapticFeedback(.success, trigger: successHapticTrigger)
        .overlay {
            if authService.isLoading {
                deletingOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.15), Color.orange.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Delete Your Account")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("Please review the information below before proceeding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Deletion Info

    private var deletionInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What will be deleted:")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            deletionItem(icon: "person.crop.circle.fill", color: .pink, text: "Your profile and personal information")
            deletionItem(icon: "book.closed.fill", color: .indigo, text: "All course enrollments")
            deletionItem(icon: "chart.bar.fill", color: .orange, text: "Grades and academic records")
            deletionItem(icon: "bubble.left.and.bubble.right.fill", color: .blue, text: "Messages and conversations")
            deletionItem(icon: "doc.fill", color: .teal, text: "Uploaded files and submissions")
            deletionItem(icon: "star.fill", color: .yellow, text: "Achievements and progress data")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func deletionItem(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Warning

    private var warningSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(.red)

            Text("This action cannot be undone. All your data will be permanently removed from our servers.")
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding(14)
        .background(.red.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Confirmation

    private var confirmationSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Type DELETE to confirm")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: "keyboard.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    TextField("Type DELETE here", text: $confirmationText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isConfirmFocused)
                        .submitLabel(.done)
                        .onSubmit { isConfirmFocused = false }
                        .accessibilityLabel("Confirmation text field")
                        .accessibilityHint("Type the word DELETE in all caps to enable the delete button")
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isConfirmFocused
                                ? (confirmationText == "DELETE" ? Color.red.opacity(0.5) : Color.orange.opacity(0.5))
                                : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your password to confirm")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    SecureField("Current password", text: $reAuthPassword)
                        .textContentType(.password)
                        .focused($isPasswordFocused)
                        .submitLabel(.done)
                        .onSubmit { isPasswordFocused = false }
                        .accessibilityLabel("Current password")
                        .accessibilityHint("Enter your current password to verify your identity")
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isPasswordFocused ? Color.red.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }

            if let reAuthError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                    Text(reAuthError)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Error message
            if let error = authService.error {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Delete My Account button
            Button(role: .destructive) {
                hapticTrigger.toggle()
                isConfirmFocused = false
                deleteAccount()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.bold())
                    Text("Delete My Account")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(!canDelete)
            .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            .accessibilityLabel("Delete my account")
            .accessibilityHint(canDelete ? "Double tap to permanently delete your account" : "Type DELETE above to enable this button")

            // Cancel button
            Button {
                hapticTrigger.toggle()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.indigo)
            }
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .padding(.top, 4)
        }
    }

    // MARK: - Deleting Overlay

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("Deleting account...")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Please wait while we remove your data.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .animation(.smooth, value: authService.isLoading)
    }

    // MARK: - Actions

    private func deleteAccount() {
        guard canDelete else { return }
        guard let userId = viewModel.currentUser?.id else {
            authService.error = "Unable to determine your account. Please try again."
            return
        }
        guard let email = viewModel.currentUser?.email else {
            authService.error = "Unable to determine your email. Please try again."
            return
        }

        Task {
            // Re-authenticate before deletion
            reAuthError = nil
            do {
                _ = try await supabaseClient.auth.signIn(email: email, password: reAuthPassword)
            } catch {
                reAuthError = "Incorrect password. Please try again."
                errorHapticTrigger.toggle()
                return
            }

            let success = await authService.deleteAccount(userId: userId)
            if success {
                successHapticTrigger.toggle()
                viewModel.logout()
            } else {
                errorHapticTrigger.toggle()
            }
        }
    }
}
