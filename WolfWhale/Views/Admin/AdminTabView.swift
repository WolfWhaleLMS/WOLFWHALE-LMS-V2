import SwiftUI

struct AdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.dashboard, systemImage: "chart.bar.fill")
                }
                .tag(0)
                .accessibilityLabel(L10n.dashboard)

            UserManagementView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabUsers, systemImage: "person.3.fill")
                }
                .tag(1)
                .accessibilityLabel(L10n.tabUsers)

            AnnouncementsView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabAnnounce, systemImage: "megaphone.fill")
                }
                .tag(2)
                .accessibilityLabel(L10n.tabAnnounce)

            MessagesListView(viewModel: viewModel)
                .task { viewModel.loadConversationsIfNeeded() }
                .tabItem {
                    Label(L10n.messages, systemImage: "message.fill")
                }
                .tag(3)
                .badge(viewModel.totalUnreadMessages)
                .accessibilityLabel(L10n.messages)

            NavigationStack {
                AppSettingsView(viewModel: viewModel)
            }
            .tabItem {
                Label(L10n.settings, systemImage: "gearshape.fill")
            }
            .tag(4)
            .accessibilityLabel(L10n.settings)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 3 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkAssignmentId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Dashboard tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkAssignmentId = nil
                }
            }
        }
    }
}
