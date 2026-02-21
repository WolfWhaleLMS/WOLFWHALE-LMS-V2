import SwiftUI
import UIKit
import UserNotifications

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if viewModel.isCheckingSession {
                    splashView
                } else if viewModel.isAuthenticated {
                    authenticatedView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .transaction { $0.animation = .smooth(duration: 0.4) }
                } else {
                    LoginView(viewModel: viewModel)
                        .transition(.opacity)
                        .transaction { $0.animation = .smooth(duration: 0.4) }
                }
            }

            // Biometric lock overlay
            if viewModel.isAppLocked {
                BiometricLockView(viewModel: viewModel)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.isAppLocked)
        .task {
            // Set up local notification delegate and categories.
            let center = UNUserNotificationCenter.current()
            center.delegate = viewModel.notificationService
            // Safe without a developer account: UNUserNotificationCenter
            // works for local notifications. Both methods handle errors internally.
            viewModel.notificationService.registerCategories()
            await viewModel.notificationService.requestAuthorization()

            viewModel.checkSession()
        }
        .onAppear {
            // Wire the AppDelegate's push service to the AppViewModel so both
            // share the same instance. This ensures device tokens received by
            // the AppDelegate are visible to the view model, and deep-link
            // destinations set by remote push payloads are observed by the UI.
            if let delegate = UIApplication.shared.delegate as? AppDelegate,
               let delegatePushService = delegate.pushService {
                viewModel._pushService = delegatePushService
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                if viewModel.biometricEnabled {
                    viewModel.lockApp()
                }
                viewModel.stopAutoRefresh()
            case .active:
                viewModel.handleForegroundResume()
            default:
                break
            }
        }
        // Bridge remote push deep-links (PushNotificationService) to the local
        // NotificationService that all TabViews observe for navigation.
        .onChange(of: viewModel.pushService.deepLinkConversationId) { _, newValue in
            if let id = newValue {
                viewModel.notificationService.deepLinkConversationId = id
                viewModel.pushService.deepLinkConversationId = nil
            }
        }
        .onChange(of: viewModel.pushService.deepLinkAssignmentId) { _, newValue in
            if let id = newValue {
                viewModel.notificationService.deepLinkAssignmentId = id
                viewModel.pushService.deepLinkAssignmentId = nil
            }
        }
        .onChange(of: viewModel.pushService.deepLinkGradeId) { _, newValue in
            if let id = newValue {
                viewModel.notificationService.deepLinkGradeId = id
                viewModel.pushService.deepLinkGradeId = nil
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                ProgressView()
                    .controlSize(.regular)
            }
        }
    }

    @ViewBuilder
    private var authenticatedView: some View {
        switch viewModel.currentUser?.role {
        case .student:
            StudentTabView(viewModel: viewModel)
        case .teacher:
            TeacherTabView(viewModel: viewModel)
        case .parent:
            ParentTabView(viewModel: viewModel)
        case .admin:
            AdminTabView(viewModel: viewModel)
        case .superAdmin:
            SuperAdminTabView(viewModel: viewModel)
        case .none:
            LoginView(viewModel: viewModel)
        }
    }
}
