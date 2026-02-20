import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                TeacherDashboardView(viewModel: viewModel)
            }
            Tab("Courses", systemImage: "book.fill") {
                TeacherCoursesView(viewModel: viewModel)
            }
            Tab("Messages", systemImage: "message.fill") {
                MessagesListView(viewModel: viewModel)
            }
            Tab("Profile", systemImage: "person.fill") {
                TeacherProfileView(viewModel: viewModel)
            }
        }
        .tint(.pink)
    }
}
