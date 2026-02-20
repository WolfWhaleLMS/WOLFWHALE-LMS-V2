import SwiftUI

struct AdminTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                AdminDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Dashboard")
            .accessibilityHint("Double tap to view school overview")
            Tab("Users", systemImage: "person.3.fill") {
                UserManagementView(viewModel: viewModel)
            }
            .accessibilityLabel("Users")
            .accessibilityHint("Double tap to manage users")
            Tab("Announce", systemImage: "megaphone.fill") {
                AnnouncementsView(viewModel: viewModel)
            }
            .accessibilityLabel("Announcements")
            .accessibilityHint("Double tap to view announcements")
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
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
