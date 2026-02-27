import SwiftUI

struct TeacherTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TeacherDashboardView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabHome, systemImage: "house.fill")
                }
                .tag(0)
                .accessibilityLabel(L10n.tabHome)

            TeacherCoursesView(viewModel: viewModel)
                .task { viewModel.loadAssignmentsIfNeeded() }
                .tabItem {
                    Label(L10n.courses, systemImage: "text.book.closed.fill")
                }
                .tag(1)
                .accessibilityLabel(L10n.courses)

            ResourceLibraryView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabResources, systemImage: "books.vertical.fill")
                }
                .tag(2)
                .accessibilityLabel(L10n.tabResources)

            MessagesListView(viewModel: viewModel)
                .task { viewModel.loadConversationsIfNeeded() }
                .tabItem {
                    Label(L10n.messages, systemImage: "message.fill")
                }
                .tag(3)
                .badge(viewModel.totalUnreadMessages)
                .accessibilityLabel(L10n.messages)

            TeacherProfileView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.tabProfile, systemImage: "person.crop.circle.fill")
                }
                .tag(4)
                .accessibilityLabel(L10n.tabProfile)
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
