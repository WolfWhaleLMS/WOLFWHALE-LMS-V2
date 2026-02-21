import SwiftUI

struct ParentTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                ParentDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your children's overview")
            Tab("Messages", systemImage: "message.fill", value: 1) {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                ParentSettingsView(viewModel: viewModel)
            }
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
