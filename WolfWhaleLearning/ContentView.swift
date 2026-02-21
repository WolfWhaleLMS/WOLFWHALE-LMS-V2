import SwiftUI
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
                } else {
                    LoginView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.4), value: viewModel.isAuthenticated)
            .animation(.smooth(duration: 0.4), value: viewModel.isCheckingSession)

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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background, viewModel.biometricEnabled {
                viewModel.lockApp()
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
