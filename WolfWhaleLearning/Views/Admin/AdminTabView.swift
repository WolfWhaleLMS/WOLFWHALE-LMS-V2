import SwiftUI

struct AdminTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                AdminDashboardView(viewModel: viewModel)
            }
            Tab("Users", systemImage: "person.3.fill") {
                UserManagementView(viewModel: viewModel)
            }
            Tab("Announce", systemImage: "megaphone.fill") {
                AnnouncementsView(viewModel: viewModel)
            }
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
        }
        .tint(.blue)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
