import SwiftUI

struct SignUpView: View {
    let viewModel: AppViewModel
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
    @State private var hasAcknowledgedAge = false
    @State private var hapticTrigger = false
    @State private var roleHapticTrigger = false
    @State private var dateOfBirth = Date()
    @State private var parentGuardianEmail = ""
    @State private var parentConsentPending = false
    @FocusState private var focusedField: Field?

    private enum Field { case fullName, email, password, confirmPassword, schoolCode, parentEmail }

    /// Whether the entered DOB indicates the user is under 13.
    private var isUnder13: Bool {
        AppStoreCompliance.isUnder13(dateOfBirth: dateOfBirth)
    }

    private var parentEmailError: String? {
        guard isUnder13 && selectedRole == .student else { return nil }
        guard hasAttemptedSubmit || !parentGuardianEmail.isEmpty else { return nil }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if parentGuardianEmail.range(of: pattern, options: .regularExpression) == nil {
            return "Enter a valid parent/guardian email"
        }
        return nil
    }

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

    private var schoolCodeError: String? {
        guard hasAttemptedSubmit || !schoolCode.isEmpty else { return nil }
        let trimmed = schoolCode.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "School code is required"
        }
        if trimmed.count != 6 {
            return "School code must be exactly 6 characters"
        }
        return nil
    }

    /// Roles available for self-registration (admin requires separate onboarding)
    private let selectableRoles: [UserRole] = [.student, .teacher, .parent]

    var body: some View {
        Group {
            if parentConsentPending {
                parentConsentPendingView
            } else {
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
            }
        }
        .background { HolographicBackground() }
        .onDisappear {
            password = ""
            confirmPassword = ""
        }
    }

    // MARK: - Parental Consent Pending

    private var parentConsentPendingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 40))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.orange)
            }

            Text("Waiting for Parental Consent")
                .font(.title3.weight(.black))
                .tracking(1)
                .multilineTextAlignment(.center)

            Text("A verification email has been sent to your parent/guardian at \(parentGuardianEmail). Your account will be activated after they provide consent.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Please ask your parent or guardian to check their email and approve your account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color.blue.opacity(0.06), in: .rect(cornerRadius: 12))
            .padding(.horizontal, 32)

            Spacer()

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
            .padding(.bottom, 40)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.brandGradientSubtle)
                    .frame(width: 80, height: 80)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.brandGradient)
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
                    .accessibilityHidden(true)
                TextField("Full Name", text: $fullName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .accessibilityLabel("Full name")
                    .accessibilityHint("Enter your first and last name")
            }
            .padding(14)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focusedField == .fullName ? Color.purple.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )

            // Email
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    TextField("School Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityLabel("Email address")
                        .accessibilityHint("Enter your school email address")
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            emailError != nil ? Color.red.opacity(0.5)
                            : focusedField == .email ? Color.purple.opacity(0.5)
                            : Color.gray.opacity(0.3),
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
                        .accessibilityHidden(true)
                    SecureField("Password (min 8 characters)", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        .accessibilityLabel("Password")
                        .accessibilityHint("Create a password with at least 8 characters")
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            passwordError != nil ? Color.red.opacity(0.5)
                            : focusedField == .password ? Color.purple.opacity(0.5)
                            : Color.gray.opacity(0.3),
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
                        .accessibilityHidden(true)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .schoolCode }
                        .accessibilityLabel("Confirm password")
                        .accessibilityHint("Re-enter your password to confirm")
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            confirmPasswordError != nil ? Color.red.opacity(0.5)
                            : focusedField == .confirmPassword ? Color.purple.opacity(0.5)
                            : Color.gray.opacity(0.3),
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
                            roleHapticTrigger.toggle()
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
                                            : Color.gray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(selectedRole == role ? .purple : .primary)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: roleHapticTrigger)
                        .accessibilityLabel("\(role.rawValue) role")
                        .accessibilityHint("Double tap to select \(role.rawValue.lowercased()) role")
                        .accessibilityAddTraits(selectedRole == role ? .isSelected : [])
                    }
                }
            }

            // School Code (required for all roles)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    TextField("Enter 6-character school code", text: $schoolCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .schoolCode)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .onChange(of: schoolCode) { _, newValue in
                            schoolCode = newValue.uppercased()
                        }
                        .accessibilityLabel("School code")
                        .accessibilityHint("Enter the 6-character code from your school administrator")
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            schoolCodeError != nil ? Color.red.opacity(0.5)
                            : focusedField == .schoolCode ? Color.purple.opacity(0.5)
                            : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )

                if let schoolCodeError {
                    Text(schoolCodeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text("Ask your school administrator for the code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
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

            // COPPA Age / Consent Acknowledgment
            consentSection
                .padding(.top, 4)

            // Sign Up button
            Button {
                hapticTrigger.toggle()
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
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel(isLoading ? "Creating account" : "Create Account")
            .accessibilityHint("Double tap to create your account")

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
        .onChange(of: selectedRole) { _, _ in
            hasAcknowledgedAge = false
        }
    }

    // MARK: - Consent

    @ViewBuilder
    private var consentSection: some View {
        switch selectedRole {
        case .student:
            VStack(alignment: .leading, spacing: 12) {
                Text("Date of Birth")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Date of Birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel("Select your date of birth")

                if isUnder13 {
                    // Parent/guardian email required for under-13
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.and.child.holdinghands")
                                .foregroundStyle(.orange)
                            Text("Parental consent required (COPPA)")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.tertiary)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            TextField("Parent/Guardian Email", text: $parentGuardianEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .parentEmail)
                                .accessibilityLabel("Parent or guardian email address")
                                .accessibilityHint("Required for users under 13")
                        }
                        .padding(14)
                        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    parentEmailError != nil ? Color.red.opacity(0.5)
                                    : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )

                        if let parentEmailError {
                            Text(parentEmailError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Text("A verification email will be sent to your parent/guardian. Your account will be activated after they consent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }

                Toggle(isOn: $hasAcknowledgedAge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Age Confirmation")
                            .font(.subheadline.bold())
                        Text(isUnder13
                             ? "I confirm my parent/guardian has approved this account for educational use."
                             : "I confirm I am 13 or older.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)
                .sensoryFeedback(.selection, trigger: hasAcknowledgedAge)
            }

        case .parent:
            Toggle(isOn: $hasAcknowledgedAge) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parental Consent")
                        .font(.subheadline.bold())
                    Text("I consent to my child's use of this educational platform and acknowledge the Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
            .sensoryFeedback(.selection, trigger: hasAcknowledgedAge)

        case .teacher, .admin, .superAdmin:
            Toggle(isOn: $hasAcknowledgedAge) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Terms Acknowledgment")
                        .font(.subheadline.bold())
                    Text("I agree to the Terms of Service and Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
            .sensoryFeedback(.selection, trigger: hasAcknowledgedAge)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let baseValid = !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && emailError == nil && !email.isEmpty
            && passwordError == nil && !password.isEmpty
            && confirmPasswordError == nil && !confirmPassword.isEmpty
            && schoolCodeError == nil && !schoolCode.trimmingCharacters(in: .whitespaces).isEmpty
            && hasAcknowledgedAge

        if selectedRole == .student && isUnder13 {
            return baseValid && parentEmailError == nil && !parentGuardianEmail.isEmpty
        }
        return baseValid
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
        if let schoolCodeError {
            return schoolCodeError
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
                let tenantCode = schoolCode.uppercased().trimmingCharacters(in: .whitespaces)
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

                let newUserId = try await viewModel.signUpNewUser(
                    email: trimmedEmail,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    role: selectedRole,
                    tenantCode: tenantCode
                )

                // If under 13, send parental consent email and show pending screen
                if selectedRole == .student && isUnder13 {
                    await viewModel.sendParentConsentEmail(
                        childUserId: newUserId,
                        parentEmail: parentGuardianEmail.trimmingCharacters(in: .whitespaces).lowercased()
                    )

                    withAnimation(.smooth) {
                        parentConsentPending = true
                        errorMessage = nil
                    }
                } else {
                    withAnimation(.smooth) {
                        successMessage = "Account created! Please check your email to verify."
                        errorMessage = nil
                    }
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
        let message = String(describing: error).lowercased()
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
