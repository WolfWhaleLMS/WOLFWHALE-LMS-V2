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
                } else if viewModel.showBiometricPrompt {
                    biometricLoginView
                } else {
                    LoginView(viewModel: viewModel)
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
            // TODO: Re-enable when ready to prompt for notifications.
            // await viewModel.notificationService.requestAuthorization()

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

                // Deauthenticate the UI so the user sees the login/Face ID
                // screen on next launch, but do NOT call logout() — the
                // Supabase session stays cached for Face ID re-login.
                if viewModel.isAuthenticated {
                    viewModel.isAuthenticated = false
                }
            case .active:
                if !viewModel.isAuthenticated && viewModel.hasSavedSession && viewModel.biometricService.isBiometricAvailable {
                    // Returning from background with a saved session — show Face ID prompt
                    viewModel.showBiometricPrompt = true
                } else if !viewModel.isAppLocked {
                    viewModel.handleForegroundResume()
                }
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
        .onOpenURL { url in
            // Only process deep links when authenticated and not locked
            guard viewModel.isAuthenticated, !viewModel.isAppLocked else {
                // DeepLinkHandler stores as pending; will process after auth
                DeepLinkHandler.handle(url: url, in: viewModel)
                return
            }
            DeepLinkHandler.handle(url: url, in: viewModel)
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                DeepLinkHandler.processPendingDeepLink(in: viewModel)
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .controlSize(.regular)
        }
    }

    /// Shows a Face ID / Touch ID prompt screen with a fallback button to the normal login form.
    private var biometricLoginView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: viewModel.biometricService.biometricSystemImage)
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Welcome Back")
                .font(.title.bold())

            Text("Unlock with \(viewModel.biometricService.biometricName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.authenticateWithBiometric()
            } label: {
                Label("Unlock with \(viewModel.biometricService.biometricName)", systemImage: viewModel.biometricService.biometricSystemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Button("Use Password Instead") {
                viewModel.showBiometricPrompt = false
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .onAppear {
            // Automatically trigger Face ID when the view appears
            viewModel.authenticateWithBiometric()
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
