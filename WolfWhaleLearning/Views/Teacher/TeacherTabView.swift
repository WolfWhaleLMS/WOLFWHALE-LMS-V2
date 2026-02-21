import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                TeacherDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your dashboard")
            Tab("Courses", systemImage: "book.fill", value: 1) {
                TeacherCoursesView(viewModel: viewModel)
            }
            .accessibilityLabel("Courses")
            .accessibilityHint("Double tap to view your courses")
            Tab("Resources", systemImage: "square.grid.2x2.fill", value: 2) {
                ResourceLibraryView(viewModel: viewModel)
            }
            .accessibilityLabel("Resources")
            .accessibilityHint("Double tap to explore learning resources")
            Tab("Messages", systemImage: "message.fill", value: 3) {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Profile", systemImage: "person.fill", value: 4) {
                TeacherProfileView(viewModel: viewModel)
            }
            .accessibilityLabel("Profile")
            .accessibilityHint("Double tap to view your profile")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
