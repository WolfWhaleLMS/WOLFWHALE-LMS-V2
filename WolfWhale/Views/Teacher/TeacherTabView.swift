import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.tabHome, systemImage: "house.fill", value: 0) {
                TeacherDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabHome)
            .accessibilityHint("Double tap to view your dashboard")
            Tab(L10n.courses, systemImage: "text.book.closed.fill", value: 1) {
                TeacherCoursesView(viewModel: viewModel)
                    .task { viewModel.loadAssignmentsIfNeeded() }
            }
            .accessibilityLabel(L10n.courses)
            .accessibilityHint("Double tap to view your courses")
            Tab(L10n.tabResources, systemImage: "books.vertical.fill", value: 2) {
                ResourceLibraryView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabResources)
            .accessibilityHint("Double tap to explore learning resources")
            Tab(L10n.messages, systemImage: "message.fill", value: 3) {
                MessagesListView(viewModel: viewModel)
                    .task { viewModel.loadConversationsIfNeeded() }
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel(L10n.messages)
            .accessibilityHint("Double tap to view your messages")
            Tab(L10n.tabProfile, systemImage: "person.crop.circle.fill", value: 4) {
                TeacherProfileView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabProfile)
            .accessibilityHint("Double tap to view your profile")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 3 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkAssignmentId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkAssignmentId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkGradeId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkGradeId = nil
                }
            }
        }
    }
}
