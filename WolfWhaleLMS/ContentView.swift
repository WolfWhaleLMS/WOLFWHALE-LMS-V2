import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if viewModel.isCheckingSession {
                splashView
            } else if viewModel.isAuthenticated {
                authenticatedView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: hasCompletedOnboarding)
        .animation(.smooth(duration: 0.4), value: viewModel.isAuthenticated)
        .animation(.smooth(duration: 0.4), value: viewModel.isCheckingSession)
        .task {
            if hasCompletedOnboarding {
                viewModel.checkSession()
            }
        }
        .onChange(of: hasCompletedOnboarding) {
            if hasCompletedOnboarding {
                viewModel.checkSession()
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
        case .none:
            LoginView(viewModel: viewModel)
        }
    }
}
