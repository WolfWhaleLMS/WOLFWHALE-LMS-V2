import SwiftUI

struct SuperAdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SuperAdminDashboardView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabConsole, systemImage: "shield.lefthalf.filled")
                }
                .tag(0)
                .accessibilityLabel(L10n.tabConsole)

            NavigationStack {
                UserManagementView(viewModel: viewModel)
            }
            .tabItem {
                Label(L10n.tabTenants, systemImage: "building.2.fill")
            }
            .tag(1)
            .accessibilityLabel(L10n.tabTenants)

            MessagesListView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.messages, systemImage: "message.fill")
                }
                .tag(2)
                .badge(viewModel.totalUnreadMessages)
                .accessibilityLabel(L10n.messages)

            NavigationStack {
                AppSettingsView(viewModel: viewModel)
            }
            .tabItem {
                Label(L10n.settings, systemImage: "gearshape.fill")
            }
            .tag(3)
            .accessibilityLabel(L10n.settings)
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
