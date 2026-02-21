import SwiftUI

struct SuperAdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Console", systemImage: "shield.lefthalf.filled", value: 0) {
                SuperAdminDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Console")
            .accessibilityHint("Double tap to view the super admin console")
            Tab("Tenants", systemImage: "building.2.fill", value: 1) {
                NavigationStack {
                    UserManagementView(viewModel: viewModel)
                }
            }
            .accessibilityLabel("Tenants")
            .accessibilityHint("Double tap to manage tenants and users")
            Tab("Messages", systemImage: "message.fill", value: 2) {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
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
