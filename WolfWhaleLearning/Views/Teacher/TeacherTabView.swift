import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill") {
                TeacherDashboardView(viewModel: viewModel)
            }
            .tag(0)
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your dashboard")
            Tab("Courses", systemImage: "book.fill") {
                TeacherCoursesView(viewModel: viewModel)
            }
            .tag(1)
            .accessibilityLabel("Courses")
            .accessibilityHint("Double tap to view your courses")
            Tab("Resources", systemImage: "square.grid.2x2.fill") {
                ResourceLibraryView(viewModel: viewModel)
            }
            .tag(2)
            .accessibilityLabel("Resources")
            .accessibilityHint("Double tap to explore learning resources")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .tag(3)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Profile", systemImage: "person.fill") {
                TeacherProfileView(viewModel: viewModel)
            }
            .tag(4)
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
