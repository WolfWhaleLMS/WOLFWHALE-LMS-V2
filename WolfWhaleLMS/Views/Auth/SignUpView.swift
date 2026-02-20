import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .student
    @State private var schoolCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var hasAttemptedSubmit = false
    @FocusState private var focusedField: Field?

    private enum Field { case fullName, email, password, confirmPassword, schoolCode }

    // MARK: - Inline Validation

    private var emailError: String? {
        guard hasAttemptedSubmit || !email.isEmpty else { return nil }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if email.range(of: pattern, options: .regularExpression) == nil {
            return "Enter a valid email (e.g. name@school.edu)"
        }
        return nil
    }

    private var passwordError: String? {
        guard hasAttemptedSubmit || !password.isEmpty else { return nil }
        if password.count < 8 {
            return "At least 8 characters"
        }
        if password.range(of: #"[A-Z]"#, options: .regularExpression) == nil {
            return "Include at least 1 uppercase letter"
        }
        if password.range(of: #"[a-z]"#, options: .regularExpression) == nil {
            return "Include at least 1 lowercase letter"
        }
        if password.range(of: #"[0-9]"#, options: .regularExpression) == nil {
            return "Include at least 1 number"
        }
        return nil
    }

    private var confirmPasswordError: String? {
        guard hasAttemptedSubmit || !confirmPassword.isEmpty else { return nil }
        if confirmPassword != password {
            return "Passwords do not match"
        }
        return nil
    }

    /// Roles available for self-registration (admin requires separate onboarding)
    private let selectableRoles: [UserRole] = [.student, .teacher, .parent]

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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Create Account")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("Join your school's learning platform")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Full Name
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
                TextField("Full Name", text: $fullName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
            }
            .padding(14)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focusedField == .fullName ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
            )

            // Email
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    TextField("School Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            emailError != nil ? Color.red.opacity(0.5)
                            : focusedField == .email ? Color.purple.opacity(0.5)
                            : Color(.separator).opacity(0.3),
                            lineWidth: 1
                        )
                )

                if let emailError {
                    Text(emailError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Password
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    SecureField("Password (min 8 characters)", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            passwordError != nil ? Color.red.opacity(0.5)
                            : focusedField == .password ? Color.purple.opacity(0.5)
                            : Color(.separator).opacity(0.3),
                            lineWidth: 1
                        )
                )

                if let passwordError {
                    Text(passwordError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Confirm Password
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.badge.checkmark")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .schoolCode }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            confirmPasswordError != nil ? Color.red.opacity(0.5)
                            : focusedField == .confirmPassword ? Color.purple.opacity(0.5)
                            : Color(.separator).opacity(0.3),
                            lineWidth: 1
                        )
                )

                if let confirmPasswordError {
                    Text(confirmPasswordError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Role Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("I am a...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(selectableRoles) { role in
                        Button {
                            withAnimation(.smooth) { selectedRole = role }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: role.iconName)
                                    .font(.caption)
                                Text(role.rawValue)
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedRole == role
                                    ? Color.purple.opacity(0.12)
                                    : Color(.systemBackground),
                                in: .rect(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selectedRole == role
                                            ? Color.purple.opacity(0.5)
                                            : Color(.separator).opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(selectedRole == role ? .purple : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // School Code (for students/teachers)
            if selectedRole == .student || selectedRole == .teacher {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    TextField("School Code", text: $schoolCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .schoolCode)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .schoolCode ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )

                Text("Enter the code provided by your school to join the correct organization.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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

            // Sign Up button
            Button {
                focusedField = nil
                signUp()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Create Account")
                                .font(.headline)
                            Image(systemName: "arrow.right")
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
            .disabled(isLoading || !isFormValid)

            // Back to Login button
            Button {
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
            .padding(.top, 4)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        && emailError == nil && !email.isEmpty
        && passwordError == nil && !password.isEmpty
        && confirmPasswordError == nil && !confirmPassword.isEmpty
        && (selectedRole == .parent || !schoolCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func validate() -> String? {
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            return "Please enter your full name"
        }
        if let emailError {
            return emailError
        }
        if let passwordError {
            return passwordError
        }
        if let confirmPasswordError {
            return confirmPasswordError
        }
        if (selectedRole == .student || selectedRole == .teacher) && schoolCode.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter your school code"
        }
        return nil
    }

    // MARK: - Sign Up

    private func signUp() {
        withAnimation(.smooth) {
            hasAttemptedSubmit = true
            errorMessage = nil
            successMessage = nil
        }

        if let validationError = validate() {
            withAnimation(.smooth) {
                errorMessage = validationError
            }
            return
        }

        isLoading = true

        Task {
            do {
                let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
                let nameComponents = trimmedName.split(separator: " ", maxSplits: 1)
                let firstName = String(nameComponents.first ?? "")
                let lastName = nameComponents.count > 1 ? String(nameComponents.last ?? "") : ""
                let code: String? = (selectedRole == .student || selectedRole == .teacher)
                    ? schoolCode.trimmingCharacters(in: .whitespaces)
                    : nil

                // Sign up with Supabase Auth
                let result = try await supabaseClient.auth.signUp(
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    password: password,
                    data: [
                        "first_name": .string(firstName),
                        "last_name": .string(lastName),
                        "role": .string(selectedRole.rawValue)
                    ]
                )

                // Create profile in profiles table
                let newProfile = InsertProfileDTO(
                    id: result.user.id,
                    firstName: firstName,
                    lastName: lastName,
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    role: selectedRole.rawValue,
                    schoolId: code
                )
                try await supabaseClient
                    .from("profiles")
                    .insert(newProfile)
                    .execute()

                withAnimation(.smooth) {
                    successMessage = "Account created! Please check your email to verify."
                    errorMessage = nil
                }
            } catch {
                withAnimation(.smooth) {
                    errorMessage = mapSignUpError(error)
                    successMessage = nil
                }
            }
            isLoading = false
        }
    }

    private func mapSignUpError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("already registered") || message.contains("already been registered") || message.contains("user_already_exists") {
            return "An account with this email already exists"
        } else if message.contains("invalid email") || message.contains("valid email") {
            return "Please enter a valid email address"
        } else if message.contains("password") && message.contains("weak") {
            return "Password is too weak. Use at least 8 characters with mixed case and numbers."
        } else if message.contains("rate") || message.contains("limit") {
            return "Too many attempts. Please wait a moment and try again."
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection."
        }
        return "Unable to create account. Please try again."
    }
}
