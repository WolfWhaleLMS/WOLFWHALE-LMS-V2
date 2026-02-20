import SwiftUI
import Supabase

struct EditProfileView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedAvatar: String = "person.crop.circle.fill"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName
    }

    // MARK: - Avatar Options

    private let avatarOptions: [String] = [
        "person.crop.circle.fill",
        "person.fill",
        "person.crop.square.fill",
        "person.crop.rectangle.fill",
        "graduationcap.fill",
        "brain.head.profile.fill",
        "figure.wave",
        "figure.stand",
        "star.circle.fill",
        "heart.circle.fill",
        "leaf.circle.fill",
        "flame.circle.fill",
        "bolt.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "sparkles"
    ]

    private var hasChanges: Bool {
        guard let user = viewModel.currentUser else { return false }
        return firstName != user.firstName ||
               lastName != user.lastName ||
               selectedAvatar != user.avatarSystemName
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        hasChanges &&
        !isLoading
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    nameSection
                    displayInfoSection
                    statsSection
                    saveButton
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadCurrentValues() }

            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 16) {
            Text("Choose Avatar")
                .font(.headline)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: selectedAvatar)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 12), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(avatarOptions, id: \.self) { avatar in
                    Button {
                        withAnimation(.smooth) {
                            selectedAvatar = avatar
                        }
                    } label: {
                        Image(systemName: avatar)
                            .font(.title2)
                            .foregroundStyle(selectedAvatar == avatar ? .white : .primary)
                            .frame(width: 52, height: 52)
                            .background(
                                selectedAvatar == avatar
                                    ? AnyShapeStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(.ultraThinMaterial),
                                in: .rect(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedAvatar == avatar ? Color.pink : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Name Fields

    private var nameSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundStyle(.pink)
                    .frame(width: 24)
                Text("Name")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
                }
                .padding(12)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 10))

                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .lastName)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }
                .padding(12)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Display-Only Info

    private var displayInfoSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text("Account Details")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                infoRow(label: "Email", value: viewModel.currentUser?.email ?? "---", icon: "envelope.fill")
                Divider().padding(.leading, 44)
                infoRow(label: "Role", value: viewModel.currentUser?.role.rawValue ?? "---", icon: "person.badge.shield.checkmark.fill")
                if let schoolId = viewModel.currentUser?.schoolId, !schoolId.isEmpty {
                    Divider().padding(.leading, 44)
                    infoRow(label: "School ID", value: schoolId, icon: "building.2.fill")
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                    .frame(width: 24)
                Text("Stats")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                statCard(icon: "bolt.fill", label: "XP", value: "\(viewModel.currentUser?.xp ?? 0)", color: .purple)
                statCard(icon: "star.fill", label: "Level", value: "\(viewModel.currentUser?.level ?? 1)", color: .yellow)
                statCard(icon: "bitcoinsign.circle.fill", label: "Coins", value: "\(viewModel.currentUser?.coins ?? 0)", color: .orange)
                statCard(icon: "flame.fill", label: "Streak", value: "\(viewModel.currentUser?.streak ?? 0) days", color: .red)
            }

            if let joinDate = viewModel.currentUser?.joinDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Joined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(joinDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    // MARK: - Error

    private var errorBanner: some View {
        Group {
            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        VStack(spacing: 12) {
            if errorMessage != nil {
                errorBanner
            }

            Button {
                focusedField = nil
                saveProfile()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text("Save Changes")
                                .font(.headline)
                            Image(systemName: "checkmark.circle.fill")
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
            .disabled(!canSave)
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

                Text("Profile Updated")
                    .font(.title3.bold())

                Text("Your profile changes have been saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .padding(.top, 8)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(duration: 0.4), value: showSuccess)
    }

    // MARK: - Actions

    private func loadCurrentValues() {
        guard let user = viewModel.currentUser else { return }
        firstName = user.firstName
        lastName = user.lastName
        selectedAvatar = user.avatarSystemName
    }

    private func saveProfile() {
        guard canSave else { return }

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)

        isLoading = true
        errorMessage = nil

        if viewModel.isDemoMode {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                viewModel.currentUser?.firstName = trimmedFirst
                viewModel.currentUser?.lastName = trimmedLast
                viewModel.currentUser?.avatarSystemName = selectedAvatar
                isLoading = false
                withAnimation(.spring(duration: 0.4)) {
                    showSuccess = true
                }
            }
            return
        }

        Task {
            do {
                guard let userId = viewModel.currentUser?.id else { return }

                let dto = UpdateProfileDetailsDTO(
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    avatarUrl: selectedAvatar
                )

                try await supabaseClient
                    .from("profiles")
                    .update(dto)
                    .eq("id", value: userId.uuidString)
                    .execute()

                await MainActor.run {
                    viewModel.currentUser?.firstName = trimmedFirst
                    viewModel.currentUser?.lastName = trimmedLast
                    viewModel.currentUser?.avatarSystemName = selectedAvatar
                    isLoading = false
                    withAnimation(.spring(duration: 0.4)) {
                        showSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    withAnimation(.smooth) {
                        errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
