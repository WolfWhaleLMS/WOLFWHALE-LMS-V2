import SwiftUI

struct SuperAdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.tabConsole, systemImage: "shield.lefthalf.filled", value: 0) {
                SuperAdminDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabConsole)
            .accessibilityHint("Double tap to view the super admin console")
            Tab(L10n.tabTenants, systemImage: "building.2.fill", value: 1) {
                NavigationStack {
                    UserManagementView(viewModel: viewModel)
                }
            }
            .accessibilityLabel(L10n.tabTenants)
            .accessibilityHint("Double tap to manage tenants and users")
            Tab(L10n.messages, systemImage: "message.fill", value: 2) {
                MessagesListView(viewModel: viewModel)
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel(L10n.messages)
            .accessibilityHint("Double tap to view your messages")
            Tab(L10n.settings, systemImage: "gearshape.fill", value: 3) {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
            .accessibilityLabel(L10n.settings)
            .accessibilityHint("Double tap to view settings and sign out")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.indigo)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 2 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
    }
}
