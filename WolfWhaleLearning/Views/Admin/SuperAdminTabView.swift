import SwiftUI

struct SuperAdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Console", systemImage: "shield.lefthalf.filled") {
                SuperAdminDashboardView(viewModel: viewModel)
            }
            .tag(0)
            .accessibilityLabel("Console")
            .accessibilityHint("Double tap to view the super admin console")
            Tab("Tenants", systemImage: "building.2.fill") {
                NavigationStack {
                    UserManagementView(viewModel: viewModel)
                }
            }
            .tag(1)
            .accessibilityLabel("Tenants")
            .accessibilityHint("Double tap to manage tenants and users")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .tag(2)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
            .tag(3)
            .accessibilityLabel("Settings")
            .accessibilityHint("Double tap to view settings and sign out")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.indigo)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
