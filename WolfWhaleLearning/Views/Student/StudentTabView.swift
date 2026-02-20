import SwiftUI

struct StudentTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                StudentDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your dashboard")
            Tab("Courses", systemImage: "book.fill") {
                CoursesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Courses")
            .accessibilityHint("Double tap to view your courses")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Profile", systemImage: "person.fill") {
                StudentProfileView(viewModel: viewModel)
            }
            .accessibilityLabel("Profile")
            .accessibilityHint("Double tap to view your profile")
        }
        .tint(.purple)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
