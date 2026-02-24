import SwiftUI

struct AddUserView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .student
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var hapticTrigger = false
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName, email, password }

    // MARK: - Field-Level Validation (InputValidator)

    private var firstNameValidation: (valid: Bool, message: String) {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (false, "") }
        return InputValidator.validateName(trimmed, fieldName: "First name")
    }

    private var lastNameValidation: (valid: Bool, message: String) {
        let trimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (false, "") }
        return InputValidator.validateName(trimmed, fieldName: "Last name")
    }

    private var emailValidation: (valid: Bool, message: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (false, "") }
        let isValid = InputValidator.validateEmail(trimmed)
        return isValid ? (true, "") : (false, "Please enter a valid email address.")
    }

    private var passwordValidation: (valid: Bool, message: String) {
        if password.isEmpty { return (false, "") }
        return InputValidator.validatePassword(password)
    }

    private var isFormValid: Bool {
        firstNameValidation.valid &&
        lastNameValidation.valid &&
        emailValidation.valid &&
        passwordValidation.valid
    }

    var body: some View {
        NavigationStack {
            Form {
                slotsSection
                roleSection
                nameSection
                credentialsSection
                infoSection
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        hapticTrigger.toggle()
                        createUser()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isLoading)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating account...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .alert("Account Created", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Account for \(firstName) \(lastName) has been created. Share their email and password with them so they can sign in.")
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    private var slotsSection: some View {
        Section {
            HStack {
                Label("Seats remaining", systemImage: "person.2.fill")
                Spacer()
                Text("\(viewModel.remainingUserSlots)")
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.remainingUserSlots <= 5 ? .orange : .primary)
            }
        }
    }

    /// Roles the current user is allowed to assign when creating a new account.
    /// - Admins can create: student, teacher, parent
    /// - SuperAdmins can create: student, teacher, parent, admin
    /// - No one can create superAdmin through this UI.
    private var creatableRoles: [UserRole] {
        switch viewModel.currentUser?.role {
        case .superAdmin:
            return [.student, .teacher, .parent, .admin]
        case .admin:
            return [.student, .teacher, .parent]
        default:
            return [.student, .teacher, .parent]
        }
    }

    private var roleSection: some View {
        Section("Role") {
            Picker("Role", selection: $selectedRole) {
                ForEach(creatableRoles) { role in
                    Label(role.rawValue, systemImage: role.iconName)
                        .tag(role)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var nameSection: some View {
        Section("Full Name") {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(Theme.roleColor(selectedRole))
                    .frame(width: 20)
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .lastName }
            }
            if !firstNameValidation.valid && !firstNameValidation.message.isEmpty {
                Text(firstNameValidation.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(.clear)
                    .frame(width: 20)
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .lastName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
            }
            if !lastNameValidation.valid && !lastNameValidation.message.isEmpty {
                Text(lastNameValidation.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private var credentialsSection: some View {
        Section("Login Credentials") {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.roleColor(selectedRole))
                    .frame(width: 20)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }
            if !emailValidation.valid && !emailValidation.message.isEmpty {
                Text(emailValidation.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.roleColor(selectedRole))
                    .frame(width: 20)
                SecureField("Temporary Password (min 8 chars)", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            if !passwordValidation.valid && !passwordValidation.message.isEmpty {
                Text(passwordValidation.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var infoSection: some View {
        Section {
            Label("The user will sign in with their email and temporary password. They should change their password after first login.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }

    private func createUser() {
        guard isFormValid else { return }
        focusedField = nil
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.createUser(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password,
                    role: selectedRole
                )
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
