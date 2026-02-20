import SwiftUI

struct StudentTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                StudentDashboardView(viewModel: viewModel)
            }
            Tab("Courses", systemImage: "book.fill") {
                CoursesListView(viewModel: viewModel)
            }
            Tab("Calendar", systemImage: "calendar") {
                CalendarView(viewModel: viewModel)
            }
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            Tab("Profile", systemImage: "person.fill") {
                StudentProfileView(viewModel: viewModel)
            }
        }
        .tint(.purple)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
    }
}
