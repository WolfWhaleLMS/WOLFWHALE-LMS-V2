import SwiftUI

struct SuperAdminTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Console", systemImage: "shield.lefthalf.filled") {
                SuperAdminDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Console")
            .accessibilityHint("Double tap to view the super admin console")
            Tab("Tenants", systemImage: "building.2.fill") {
                NavigationStack {
                    UserManagementView(viewModel: viewModel)
                }
            }
            .accessibilityLabel("Tenants")
            .accessibilityHint("Double tap to manage tenants and users")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Double tap to view settings and sign out")
        }
        .tint(.indigo)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
