import SwiftUI
import Supabase

struct AdminSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var schoolName = ""
    @State private var adminName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case schoolName, adminName, email, password, confirmPassword }

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

                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Set Up Your School")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("Create your school account and become the first administrator. You'll be able to invite teachers, students, and parents after setup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Section: School Info
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHOOL INFORMATION")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    TextField("School Name", text: $schoolName)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .schoolName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .adminName }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .schoolName ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )
            }

            // Section: Admin Account
            VStack(alignment: .leading, spacing: 8) {
                Text("ADMINISTRATOR ACCOUNT")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                // Admin Name
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    TextField("Admin Full Name", text: $adminName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .adminName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .adminName ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )

                // Email
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    TextField("Admin Email", text: $email)
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
                        .strokeBorder(focusedField == .email ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )

                // Password
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
                        .strokeBorder(focusedField == .password ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )

                // Confirm Password
                HStack(spacing: 12) {
                    Image(systemName: "lock.badge.checkmark")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }
                .padding(14)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .confirmPassword ? Color.purple.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )
            }

            // Info callout
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.purple.opacity(0.7))
                    .font(.subheadline)
                Text("A unique school code will be generated for your organization. Share it with teachers and students so they can join.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.purple.opacity(0.06), in: .rect(cornerRadius: 10))

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

            // Create School button
            Button {
                focusedField = nil
                createSchool()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Create School")
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
        !schoolName.trimmingCharacters(in: .whitespaces).isEmpty
        && !adminName.trimmingCharacters(in: .whitespaces).isEmpty
        && !email.isEmpty
        && !password.isEmpty
        && !confirmPassword.isEmpty
    }

    private func validate() -> String? {
        if schoolName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter your school name"
        }
        if adminName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter the administrator's name"
        }
        if !email.contains("@") || !email.contains(".") {
            return "Please enter a valid email address"
        }
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        if password != confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }

    // MARK: - Create School

    private func createSchool() {
        withAnimation(.smooth) {
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
                let trimmedAdmin = adminName.trimmingCharacters(in: .whitespaces)
                let nameComponents = trimmedAdmin.split(separator: " ", maxSplits: 1)
                let firstName = String(nameComponents.first ?? "")
                let lastName = nameComponents.count > 1 ? String(nameComponents.last ?? "") : ""
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

                // Generate a unique school code from the school name
                let trimmedSchool = schoolName.trimmingCharacters(in: .whitespaces)
                let schoolCode = generateSchoolCode(from: trimmedSchool)

                // 1. Sign up admin with Supabase Auth
                let result = try await supabaseClient.auth.signUp(
                    email: trimmedEmail,
                    password: password,
                    data: [
                        "first_name": .string(firstName),
                        "last_name": .string(lastName),
                        "role": .string(UserRole.admin.rawValue)
                    ]
                )

                // 2. Create tenant record (the actual table is "tenants", not "schools")
                let tenantId = UUID()
                let tenantRecord = InsertTenantDTO(
                    id: tenantId,
                    name: trimmedSchool,
                    slug: schoolCode,
                    status: "active"
                )
                try await supabaseClient
                    .from("tenants")
                    .insert(tenantRecord)
                    .execute()

                // 3. Create admin profile (email/role/schoolId are NOT profile columns)
                let newProfile = InsertProfileDTO(
                    id: result.user.id,
                    firstName: firstName,
                    lastName: lastName,
                    avatarUrl: nil,
                    phone: nil,
                    dateOfBirth: nil,
                    bio: nil,
                    timezone: nil,
                    language: nil,
                    gradeLevel: nil,
                    fullName: "\(firstName) \(lastName)"
                )
                try await supabaseClient
                    .from("profiles")
                    .insert(newProfile)
                    .execute()

                // 4. Create tenant membership (role lives in tenant_memberships)
                let membership = InsertTenantMembershipDTO(
                    userId: result.user.id,
                    tenantId: tenantId,
                    role: UserRole.admin.rawValue,
                    status: "active",
                    joinedAt: ISO8601DateFormatter().string(from: Date()),
                    invitedAt: nil,
                    invitedBy: nil
                )
                try await supabaseClient
                    .from("tenant_memberships")
                    .insert(membership)
                    .execute()

                withAnimation(.smooth) {
                    successMessage = "School created! Your school code is \(schoolCode). Please check your email to verify your account."
                    errorMessage = nil
                }
            } catch {
                withAnimation(.smooth) {
                    errorMessage = mapSetupError(error)
                    successMessage = nil
                }
            }
            isLoading = false
        }
    }

    private func generateSchoolCode(from name: String) -> String {
        let prefix = name
            .uppercased()
            .filter { $0.isLetter }
            .prefix(4)
        let suffix = Int.random(in: 1000...9999)
        return "\(prefix)-\(suffix)"
    }

    private func mapSetupError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("already registered") || message.contains("already been registered") || message.contains("user_already_exists") {
            return "An account with this email already exists"
        } else if message.contains("duplicate") || message.contains("unique") || message.contains("already exists") {
            return "A school with this information already exists. Please try a different name or contact support."
        } else if message.contains("invalid email") || message.contains("valid email") {
            return "Please enter a valid email address"
        } else if message.contains("password") && message.contains("weak") {
            return "Password is too weak. Use at least 8 characters with mixed case and numbers."
        } else if message.contains("rate") || message.contains("limit") {
            return "Too many attempts. Please wait a moment and try again."
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection."
        }
        return "Unable to create school. Please try again."
    }
}

// MARK: - DTO for tenant record

nonisolated struct InsertTenantDTO: Encodable, Sendable {
    let id: UUID
    let name: String
    let slug: String
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, status
    }
}
