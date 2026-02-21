import SwiftUI

struct StudentTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                StudentDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel("Home")
            .accessibilityHint("Double tap to view your dashboard")
            Tab("Courses", systemImage: "book.fill", value: 1) {
                CoursesListView(viewModel: viewModel)
                    .task { await viewModel.loadAssignmentsIfNeeded() }
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
                    .task { await viewModel.loadConversationsIfNeeded() }
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel("Messages")
            .accessibilityHint("Double tap to view your messages")
            Tab("Profile", systemImage: "person.fill", value: 4) {
                StudentProfileView(viewModel: viewModel)
                    .task { await viewModel.loadGradesIfNeeded() }
            }
            .accessibilityLabel("Profile")
            .accessibilityHint("Double tap to view your profile")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkAssignmentId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab shows upcoming assignments
                // Clear after a brief delay to allow navigation to settle
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkAssignmentId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 3 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkGradeId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab (grades accessible from profile/dashboard)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkGradeId = nil
                }
            }
        }
    }
}
