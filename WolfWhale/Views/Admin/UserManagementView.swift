import SwiftUI

struct UserManagementView: View {
    let viewModel: AppViewModel
    @State private var searchText = ""
    @State private var selectedRole: UserRole? = nil
    @State private var showAddUser = false
    @State private var userToDelete: ProfileDTO?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var hapticTrigger = false

    private var filteredUsers: [ProfileDTO] {
        viewModel.allUsers.filter { user in
            let role = UserRole.from(user.role)
            let matchesRole = selectedRole == nil || role == selectedRole
            let fullName = "\(user.firstName ?? "") \(user.lastName ?? "")"
            let matchesSearch = searchText.isEmpty || fullName.localizedStandardContains(searchText) || user.email.localizedStandardContains(searchText)
            return matchesRole && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                slotBannerSection
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Section {
                    filterChips
                }
                .listRowInsets(EdgeInsets())

                Section {
                    if filteredUsers.isEmpty && !viewModel.allUsers.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if viewModel.allUsers.isEmpty {
                        HStack {
                            Image(systemName: "person.3")
                                .foregroundStyle(.secondary)
                            Text("No users yet. Add your first user.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(filteredUsers, id: \.id) { user in
                            userRow(user)
                                .onAppear {
                                    if user.id == filteredUsers.last?.id {
                                        Task { await viewModel.loadMoreUsers() }
                                    }
                                }
                        }
                        if viewModel.userPagination.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    }
                } header: {
                    Text("\(filteredUsers.count) user\(filteredUsers.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .navigationTitle("Users")
            .searchable(text: $searchText, prompt: "Search users")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        showAddUser = true
                    } label: {
                        Label("Add User", systemImage: "person.badge.plus")
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .disabled(viewModel.remainingUserSlots <= 0)
                }
            }
            .sheet(isPresented: $showAddUser) {
                AddUserView(viewModel: viewModel)
            }
            .alert("Remove User", isPresented: $showDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    if let user = userToDelete {
                        Task {
                            do {
                                try await viewModel.deleteUser(userId: user.id)
                            } catch {
                                deleteError = "Failed to remove user. Please try again."
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let user = userToDelete {
                    Text("Are you sure you want to remove \(user.firstName ?? "") \(user.lastName ?? "")? This action cannot be undone.")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteError ?? "")
            }
            .refreshable {
                viewModel.refreshData()
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    private var slotBannerSection: some View {
        let total = viewModel.currentUser?.userSlotsTotal ?? 0
        let used = viewModel.currentUser?.userSlotsUsed ?? 0
        let remaining = viewModel.remainingUserSlots
        let progress = total > 0 ? Double(used) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("User Seats")
                        .font(.subheadline.bold())
                    Text("\(remaining) of \(total) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(used)")
                        .font(.title2.bold())
                        .foregroundStyle(remaining <= 0 ? .red : .primary)
                    Text("used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            remaining <= 0
                            ? Color.red
                            : remaining <= 5
                            ? Color.orange
                            : Color.blue
                        )
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)

            if remaining <= 0 {
                Label("All seats used. Contact WolfWhale to upgrade your plan.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if remaining <= 5 {
                Label("\(remaining) seat\(remaining == 1 ? "" : "s") left", systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func userRow(_ user: ProfileDTO) -> some View {
        let role = UserRole.from(user.role) ?? .student
        return HStack(spacing: 12) {
            Circle()
                .fill(Theme.roleColor(role).opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: role.iconName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.roleColor(role))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                    .font(.subheadline.bold())
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(user.role)
                .font(.caption.bold())
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.roleColor(role).opacity(0.12), in: Capsule())
                .foregroundStyle(Theme.roleColor(role))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                userToDelete = user
                showDeleteConfirmation = true
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.firstName ?? "") \(user.lastName ?? ""), \(user.role), \(user.email)")
        .accessibilityHint("Swipe left to remove user")
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(label: "All", role: nil)
                ForEach(UserRole.allCases) { role in
                    filterChip(label: role.rawValue, role: role)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    private func filterChip(label: String, role: UserRole?) -> some View {
        Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) { selectedRole = role }
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    selectedRole == role
                    ? (role.map { Theme.roleColor($0) } ?? Color.blue).opacity(0.18)
                    : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(
                    selectedRole == role
                    ? (role.map { Theme.roleColor($0) } ?? Color.blue)
                    : .secondary
                )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(selectedRole == role ? .isSelected : [])
        .accessibilityHint("Double tap to filter users by \(label.lowercased())")
    }
}
