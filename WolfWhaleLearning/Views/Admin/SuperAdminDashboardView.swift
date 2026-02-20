import SwiftUI

struct SuperAdminDashboardView: View {
    let viewModel: AppViewModel
    @State private var tenants: [TenantInfo] = []
    @State private var isLoading = false
    @State private var showAddTenant = false
    @State private var editingTenant: TenantInfo?
    @State private var newUserLimit: String = ""
    @State private var hapticTrigger = false

    struct TenantInfo: Identifiable {
        let id: UUID
        let name: String
        let inviteCode: String
        var userCount: Int
        var userLimit: Int
        let createdAt: Date
    }

    private var totalUsersAcrossTenants: Int {
        tenants.reduce(0) { $0 + $1.userCount }
    }

    private var totalCapacity: Int {
        tenants.reduce(0) { $0 + $1.userLimit }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    systemHealthCard
                    userStatisticsSection
                    tenantManagementSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Super Admin Console")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        showAddTenant = true
                    } label: {
                        Label("Add Tenant", systemImage: "plus.circle.fill")
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .refreshable {
                await loadTenants()
            }
            .task {
                await loadTenants()
            }
            .sheet(isPresented: $showAddTenant) {
                addTenantSheet
            }
            .sheet(item: $editingTenant) { tenant in
                editUserLimitSheet(for: tenant)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Super Admin Console")
                    .font(.title3.bold())
                Text("Manage all tenants and user limits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Super Admin Console. Manage all tenants and user limits.")
    }

    // MARK: - System Health Card

    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Health", systemImage: "heart.text.clipboard")
                .font(.headline)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                healthMetric(
                    icon: "building.2.fill",
                    value: "\(tenants.count)",
                    label: "Tenants",
                    color: .purple
                )
                healthMetric(
                    icon: "person.3.fill",
                    value: "\(totalUsersAcrossTenants)",
                    label: "Total Users",
                    color: .cyan
                )
                healthMetric(
                    icon: "chart.bar.fill",
                    value: totalCapacity > 0 ? "\(Int(Double(totalUsersAcrossTenants) / Double(totalCapacity) * 100))%" : "0%",
                    label: "Capacity",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System Health: \(tenants.count) tenants, \(totalUsersAcrossTenants) total users")
    }

    private func healthMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
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
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    // MARK: - User Statistics

    private var userStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("User Statistics", systemImage: "chart.pie.fill")
                .font(.headline)

            if tenants.isEmpty {
                HStack {
                    Image(systemName: "person.3")
                        .foregroundStyle(.secondary)
                    Text("No tenant data available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(tenants) { tenant in
                    tenantStatRow(tenant)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func tenantStatRow(_ tenant: TenantInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tenant.name)
                        .font(.subheadline.bold())
                    Text("Code: \(tenant.inviteCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tenant.userCount) / \(tenant.userLimit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(tenant.userCount >= tenant.userLimit ? .red : .primary)
            }

            tenantProgressBar(used: tenant.userCount, total: tenant.userLimit)
        }
        .padding(12)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tenant.name), \(tenant.userCount) of \(tenant.userLimit) users")
    }

    private func tenantProgressBar(used: Int, total: Int) -> some View {
        let progress = total > 0 ? Double(used) / Double(total) : 0
        let remaining = total - used

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(height: 6)
                Capsule()
                    .fill(
                        remaining <= 0
                        ? AnyShapeStyle(Color.red)
                        : remaining <= 5
                        ? AnyShapeStyle(Color.orange)
                        : AnyShapeStyle(LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    )
                    .frame(width: geo.size.width * min(progress, 1.0), height: 6)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Tenant Management

    private var tenantManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tenant Management", systemImage: "building.2.fill")
                .font(.headline)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if tenants.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No tenants yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        hapticTrigger.toggle()
                        showAddTenant = true
                    } label: {
                        Label("Add First Tenant", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(tenants) { tenant in
                    tenantManagementRow(tenant)
                }
            }

            HStack(spacing: 12) {
                actionButton(
                    title: "Add Tenant",
                    icon: "plus.circle.fill",
                    color: .indigo
                ) {
                    showAddTenant = true
                }

                actionButton(
                    title: "View All Users",
                    icon: "person.3.fill",
                    color: .purple
                ) {
                    // Placeholder for future navigation
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func tenantManagementRow(_ tenant: TenantInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "building.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(tenant.name)
                    .font(.subheadline.bold())
                Text("Created \(tenant.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                hapticTrigger.toggle()
                newUserLimit = "\(tenant.userLimit)"
                editingTenant = tenant
            } label: {
                Label("Edit Limit", systemImage: "slider.horizontal.3")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
                    .foregroundStyle(.indigo)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(12)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tenant.name), created \(tenant.createdAt, format: .dateTime.month().day().year())")
        .accessibilityHint("Double tap Edit Limit to change user limit")
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12), in: .rect(cornerRadius: 12))
            .foregroundStyle(color)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel(title)
    }

    // MARK: - Sheets

    private var addTenantSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 20)

                Text("Add New Tenant")
                    .font(.title2.bold())

                Text("Tenant creation will be available once the backend integration is complete.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("New Tenant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        hapticTrigger.toggle()
                        showAddTenant = false
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func editUserLimitSheet(for tenant: TenantInfo) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(tenant.name)
                        .font(.title3.bold())
                    Text("Current limit: \(tenant.userLimit) users")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("New User Limit")
                        .font(.subheadline.bold())
                    TextField("Enter limit", text: $newUserLimit)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }
                .padding(.horizontal, 24)

                Button {
                    hapticTrigger.toggle()
                    if let limit = Int(newUserLimit), limit > 0 {
                        if let index = tenants.firstIndex(where: { $0.id == tenant.id }) {
                            tenants[index] = TenantInfo(
                                id: tenant.id,
                                name: tenant.name,
                                inviteCode: tenant.inviteCode,
                                userCount: tenant.userCount,
                                userLimit: limit,
                                createdAt: tenant.createdAt
                            )
                        }
                        editingTenant = nil
                    }
                } label: {
                    Text("Update Limit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                Spacer()
            }
            .navigationTitle("Edit User Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        editingTenant = nil
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Data Loading

    private func loadTenants() async {
        isLoading = true
        // Placeholder data until backend integration is complete
        try? await Task.sleep(for: .milliseconds(500))
        tenants = [
            TenantInfo(
                id: UUID(),
                name: "Westfield Academy",
                inviteCode: "WEST2024",
                userCount: 47,
                userLimit: 75,
                createdAt: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            ),
            TenantInfo(
                id: UUID(),
                name: "Riverside Elementary",
                inviteCode: "RIVER24",
                userCount: 30,
                userLimit: 30,
                createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            ),
            TenantInfo(
                id: UUID(),
                name: "Summit High School",
                inviteCode: "SUMMIT1",
                userCount: 12,
                userLimit: 50,
                createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            ),
        ]
        isLoading = false
    }
}
