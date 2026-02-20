import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                TeacherDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your dashboard")
            Tab("Courses", systemImage: "book.fill") {
                TeacherCoursesView(viewModel: viewModel)
            }
            .accessibilityLabel("Courses")
            .accessibilityHint("Double tap to view your courses")
            Tab("AR Library", systemImage: "arkit") {
                ARLibraryView(viewModel: viewModel)
            }
            .accessibilityLabel("AR Library")
            .accessibilityHint("Double tap to explore AR experiences")
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Profile", systemImage: "person.fill") {
                TeacherProfileView(viewModel: viewModel)
            }
            .accessibilityLabel("Profile")
            .accessibilityHint("Double tap to view your profile")
        }
        .tint(.pink)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
