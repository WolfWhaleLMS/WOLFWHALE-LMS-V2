import SwiftUI

struct AdminTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                AdminDashboardView(viewModel: viewModel)
            }
            .tag(0)
            .accessibilityLabel("Dashboard")
            .accessibilityHint("Double tap to view school overview")
            Tab("Users", systemImage: "person.3.fill") {
                UserManagementView(viewModel: viewModel)
            }
            .tag(1)
            .accessibilityLabel("Users")
            .accessibilityHint("Double tap to manage users")
            Tab("Announce", systemImage: "megaphone.fill") {
                AnnouncementsView(viewModel: viewModel)
            }
            .tag(2)
            .accessibilityLabel("Announcements")
            .accessibilityHint("Double tap to view announcements")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .tag(3)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    AppSettingsView(viewModel: viewModel)
                }
            }
            .tag(4)
            .accessibilityLabel("Settings")
            .accessibilityHint("Double tap to view settings and sign out")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
