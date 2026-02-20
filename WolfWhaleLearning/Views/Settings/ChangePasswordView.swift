import SwiftUI
import Supabase

struct ChangePasswordView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var hapticTrigger = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case current, new, confirm
    }

    // MARK: - Password Strength

    private enum PasswordStrength: String {
        case weak = "Weak"
        case medium = "Medium"
        case strong = "Strong"

        var color: Color {
            switch self {
            case .weak: .red
            case .medium: .orange
            case .strong: .green
            }
        }

        var progress: Double {
            switch self {
            case .weak: 0.33
            case .medium: 0.66
            case .strong: 1.0
            }
        }
    }

    private var passwordStrength: PasswordStrength {
        let password = newPassword
        guard !password.isEmpty else { return .weak }

        var score = 0

        // Length checks
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }

        // Character variety checks
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default: return .strong
        }
    }

    private var validationError: String? {
        if newPassword.isEmpty { return nil }
        if newPassword.count < 8 { return "Password must be at least 8 characters" }
        if !confirmPassword.isEmpty && newPassword != confirmPassword { return "Passwords do not match" }
        if !currentPassword.isEmpty && newPassword == currentPassword { return "New password must differ from current password" }
        return nil
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        newPassword != currentPassword &&
        !isLoading
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    formSection
                    strengthIndicator
                    if let validationError {
                        validationBanner(message: validationError)
                    }
                    if let errorMessage {
                        errorBanner(message: errorMessage)
                    }
                    submitButton
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)

            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.15), .purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "lock.rotation")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Update Your Password")
                .font(.title3.bold())

            Text("Choose a strong password to keep your account secure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 14) {
            passwordField(
                icon: "lock.fill",
                placeholder: "Current Password",
                text: $currentPassword,
                field: .current
            )

            Divider().padding(.leading, 44)

            passwordField(
                icon: "lock.badge.plus.fill",
                placeholder: "New Password",
                text: $newPassword,
                field: .new
            )

            passwordField(
                icon: "lock.badge.checkmark.fill",
                placeholder: "Confirm New Password",
                text: $confirmPassword,
                field: .confirm
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func passwordField(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.pink)
                .frame(width: 24)
            SecureField(placeholder, text: text)
                .textContentType(field == .current ? .password : .newPassword)
                .focused($focusedField, equals: field)
                .submitLabel(field == .confirm ? .done : .next)
                .onSubmit {
                    switch field {
                    case .current: focusedField = .new
                    case .new: focusedField = .confirm
                    case .confirm: if canSubmit { changePassword() }
                    }
                }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Strength Indicator

    private var strengthIndicator: some View {
        Group {
            if !newPassword.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Password Strength")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(passwordStrength.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(passwordStrength.color)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                            Capsule()
                                .fill(passwordStrength.color)
                                .frame(width: geo.size.width * passwordStrength.progress)
                                .animation(.smooth, value: passwordStrength)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth, value: newPassword.isEmpty)
    }

    // MARK: - Validation & Error

    private func validationBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            hapticTrigger.toggle()
            focusedField = nil
            changePassword()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text("Update Password")
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
        .tint(.pink)
        .clipShape(.rect(cornerRadius: 12))
        .disabled(!canSubmit)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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

                Text("Password Updated")
                    .font(.title3.bold())

                Text("Your password has been changed successfully.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .padding(.top, 8)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(duration: 0.4), value: showSuccess)
    }

    // MARK: - Action

    private func changePassword() {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil

        if viewModel.isDemoMode {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                isLoading = false
                withAnimation(.spring(duration: 0.4)) {
                    showSuccess = true
                }
            }
            return
        }

        Task {
            do {
                try await supabaseClient.auth.update(user: .init(password: newPassword))
                await MainActor.run {
                    isLoading = false
                    withAnimation(.spring(duration: 0.4)) {
                        showSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    withAnimation(.smooth) {
                        errorMessage = mapPasswordError(error)
                    }
                }
            }
        }
    }

    private func mapPasswordError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("weak") || message.contains("short") {
            return "Password is too weak. Please choose a stronger password."
        } else if message.contains("same") || message.contains("reuse") {
            return "New password cannot be the same as your current password."
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection."
        } else if message.contains("session") || message.contains("auth") {
            return "Session expired. Please sign in again."
        }
        return "Failed to update password. Please try again."
    }
}
