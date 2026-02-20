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

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        password.count >= 8
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
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        hapticTrigger.toggle()
                        createUser()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isLoading)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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

    private var roleSection: some View {
        Section("Role") {
            Picker("Role", selection: $selectedRole) {
                ForEach(UserRole.allCases) { role in
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
