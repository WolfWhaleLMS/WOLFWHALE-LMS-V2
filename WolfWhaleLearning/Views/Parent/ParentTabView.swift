import SwiftUI

struct ParentTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill") {
                ParentDashboardView(viewModel: viewModel)
            }
            .tag(0)
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your children's overview")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .tag(1)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill") {
                ParentSettingsView(viewModel: viewModel)
            }
            .tag(2)
            .accessibilityLabel("Settings")
            .accessibilityHint("Double tap to view settings")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
