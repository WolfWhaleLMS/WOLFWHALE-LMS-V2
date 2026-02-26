import SwiftUI

struct AdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
                AdminDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Dashboard")
            .accessibilityHint("Double tap to view school overview")
            Tab("Users", systemImage: "person.3.fill", value: 1) {
                UserManagementView(viewModel: viewModel)
            }
            .accessibilityLabel("Users")
            .accessibilityHint("Double tap to manage users")
            Tab("Announce", systemImage: "megaphone.fill", value: 2) {
                AnnouncementsView(viewModel: viewModel)
            }
            .accessibilityLabel("Announcements")
            .accessibilityHint("Double tap to view announcements")
            Tab("Messages", systemImage: "message.fill", value: 3) {
                MessagesListView(viewModel: viewModel)
                    .task { viewModel.loadConversationsIfNeeded() }
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Double tap to view settings and sign out")
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
