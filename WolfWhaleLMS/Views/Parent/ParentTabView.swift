import SwiftUI

struct ParentTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                ParentDashboardView(viewModel: viewModel)
            }
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                ParentSettingsView(viewModel: viewModel)
            }
        }
        .tint(.green)
    }
}
