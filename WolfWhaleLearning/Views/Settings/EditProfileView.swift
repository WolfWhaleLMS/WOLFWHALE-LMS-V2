import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedAvatar: String = "person.crop.circle.fill"
    @State private var avatarUrl: String? = nil
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var hapticTrigger = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName
    }

    private let photoService = PhotoService()

    // MARK: - Avatar Options (fallback SF Symbols)

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

    /// Returns true when the avatar URL looks like a real uploaded image URL
    /// rather than an SF Symbol name.
    private var hasUploadedAvatar: Bool {
        guard let url = avatarUrl, !url.isEmpty else { return false }
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }

    private var hasChanges: Bool {
        guard let user = viewModel.currentUser else { return false }
        let nameChanged = firstName != user.firstName || lastName != user.lastName
        let sfSymbolChanged = selectedAvatar != user.avatarSystemName
        // Check if avatarUrl changed from what was loaded
        let avatarChanged = hasUploadedAvatar || sfSymbolChanged
        return nameChanged || avatarChanged
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        hasChanges &&
        !isLoading &&
        !isUploading
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
            Text("Profile Photo")
                .font(.headline)

            // Reusable ProfilePhotoPicker component
            ProfilePhotoPicker(
                avatarUrl: $avatarUrl,
                selectedSystemImage: $selectedAvatar,
                onImageSelected: { image in
                    Task {
                        await uploadAvatarImage(image)
                    }
                },
                onRemovePhoto: {
                    avatarUrl = nil
                },
                size: 80,
                isUploading: isUploading
            )

            // SF Symbol fallback picker
            DisclosureGroup {
                let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 12), count: 4)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(avatarOptions, id: \.self) { avatar in
                        Button {
                            withAnimation(.smooth) {
                                selectedAvatar = avatar
                                // Clear uploaded avatar when choosing an SF Symbol
                                avatarUrl = nil
                            }
                        } label: {
                            Image(systemName: avatar)
                                .font(.title2)
                                .foregroundStyle(selectedAvatar == avatar && !hasUploadedAvatar ? .white : .primary)
                                .frame(width: 52, height: 52)
                                .background(
                                    selectedAvatar == avatar && !hasUploadedAvatar
                                        ? AnyShapeStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(.ultraThinMaterial),
                                    in: .rect(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            selectedAvatar == avatar && !hasUploadedAvatar ? Color.pink : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(.secondary)
                    Text("Or choose an icon instead")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                hapticTrigger.toggle()
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
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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

    // MARK: - Actions

    private func loadCurrentValues() {
        guard let user = viewModel.currentUser else { return }
        firstName = user.firstName
        lastName = user.lastName
        selectedAvatar = user.avatarSystemName

        // If the current avatarSystemName looks like a URL, treat it as an uploaded avatar
        let stored = user.avatarSystemName
        if stored.hasPrefix("http://") || stored.hasPrefix("https://") {
            avatarUrl = stored
        }
    }

    /// Handles avatar image upload using PhotoService.
    /// Compresses the image and uploads to Supabase Storage,
    /// falling back to local FileManager storage on failure.
    private func uploadAvatarImage(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }

        let userId = viewModel.currentUser?.id ?? UUID()

        // Try Supabase upload first
        if !viewModel.isDemoMode {
            do {
                let url = try await photoService.uploadAvatar(image, userId: userId)
                avatarUrl = url
                errorMessage = nil
                return
            } catch {
                // Fall through to local save
                #if DEBUG
                print("[EditProfileView] Supabase avatar upload failed: \(error)")
                #endif
            }
        }

        // Fallback: save locally with FileManager
        let fileName = "\(userId.uuidString)_avatar.jpg"
        if let localURL = photoService.saveImageLocally(image, fileName: fileName) {
            avatarUrl = localURL.absoluteString
            errorMessage = nil
        } else {
            withAnimation(.smooth) {
                errorMessage = "Could not save the selected photo."
            }
        }
    }

    private func saveProfile() {
        guard canSave else { return }

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)

        // Determine what to store as the avatar value:
        // - If the user uploaded a photo, store the public URL
        // - Otherwise, store the selected SF Symbol name
        let avatarValue: String = hasUploadedAvatar ? (avatarUrl ?? selectedAvatar) : selectedAvatar

        isLoading = true
        errorMessage = nil

        if viewModel.isDemoMode {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                viewModel.currentUser?.firstName = trimmedFirst
                viewModel.currentUser?.lastName = trimmedLast
                viewModel.currentUser?.avatarSystemName = avatarValue
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
                    avatarUrl: avatarValue
                )

                try await supabaseClient
                    .from("profiles")
                    .update(dto)
                    .eq("id", value: userId.uuidString)
                    .execute()

                await MainActor.run {
                    viewModel.currentUser?.firstName = trimmedFirst
                    viewModel.currentUser?.lastName = trimmedLast
                    viewModel.currentUser?.avatarSystemName = avatarValue
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
