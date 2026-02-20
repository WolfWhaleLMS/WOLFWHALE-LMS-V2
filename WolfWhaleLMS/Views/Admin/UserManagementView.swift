import SwiftUI

struct UserManagementView: View {
    let viewModel: AppViewModel
    @State private var searchText = ""
    @State private var selectedRole: UserRole? = nil
    @State private var showAddUser = false

    private let sampleUsers: [(String, UserRole, String)] = [
        ("Alex Rivera", .student, "10th Grade"),
        ("Jordan Kim", .student, "10th Grade"),
        ("Sam Patel", .student, "11th Grade"),
        ("Taylor Brooks", .student, "10th Grade"),
        ("Dr. Sarah Chen", .teacher, "Mathematics"),
        ("Mr. David Park", .teacher, "Biology"),
        ("Ms. Emily Torres", .teacher, "History"),
        ("Maria Rivera", .parent, "Parent of Alex"),
        ("James Wilson", .admin, "Administrator"),
    ]

    private var filtered: [(String, UserRole, String)] {
        sampleUsers.filter { user in
            let matchesRole = selectedRole == nil || user.1 == selectedRole
            let matchesSearch = searchText.isEmpty || user.0.localizedStandardContains(searchText)
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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    ForEach(Array(filtered.enumerated()), id: \.offset) { _, user in
                        userRow(user)
                    }
                } header: {
                    Text("\(filtered.count) user\(filtered.count == 1 ? "" : "s")")
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
                        showAddUser = true
                    } label: {
                        Label("Add User", systemImage: "person.badge.plus")
                    }
                    .disabled(viewModel.remainingUserSlots <= 0)
                }
            }
            .sheet(isPresented: $showAddUser) {
                AddUserView(viewModel: viewModel)
            }
        }
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
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func userRow(_ user: (String, UserRole, String)) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.roleColor(user.1).opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: user.1.iconName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.roleColor(user.1))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.0)
                    .font(.subheadline.bold())
                Text(user.2)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(user.1.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.roleColor(user.1).opacity(0.12), in: Capsule())
                .foregroundStyle(Theme.roleColor(user.1))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
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
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    private func filterChip(label: String, role: UserRole?) -> some View {
        Button {
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
    }
}
