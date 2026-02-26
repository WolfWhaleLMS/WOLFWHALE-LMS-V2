import SwiftUI

struct ParentTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.tabHome, systemImage: "house.fill", value: 0) {
                ParentDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabHome)
            .accessibilityHint("Double tap to view your children's overview")
            Tab(L10n.messages, systemImage: "message.fill", value: 1) {
                MessagesListView(viewModel: viewModel)
                    .task { viewModel.loadConversationsIfNeeded() }
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel(L10n.messages)
            .accessibilityHint("Double tap to view your messages")
            Tab(L10n.settings, systemImage: "gearshape.fill", value: 2) {
                ParentSettingsView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.settings)
            .accessibilityHint("Double tap to view settings")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 1 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
    }
}
