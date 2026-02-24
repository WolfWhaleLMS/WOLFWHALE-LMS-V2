import SwiftUI
import LocalAuthentication
#if canImport(UserNotifications)
import UserNotifications
#endif

struct EnhancedOnboardingView: View {
    @AppStorage("wolfwhale_onboarding_complete") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var hapticTrigger = false

    // Permissions state
    @State private var notificationsGranted = false
    @State private var notificationsRequested = false
    @State private var biometricEnabled = false
    @State private var biometricName = "Face ID"
    @State private var biometricIcon = "faceid"
    @State private var biometricAvailable = false

    // Celebration animation
    @State private var showCheckmark = false
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var confettiVisible = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Dynamic gradient background
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button {
                            hapticTrigger.toggle()
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background {
                                    Capsule()
                                        .fill(.white.opacity(0.12))
                                }
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                        .accessibilityLabel("Skip onboarding")
                        .accessibilityHint("Double tap to skip to login")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(height: 44)

                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    notificationsPage.tag(2)
                    biometricPage.tag(3)
                    getStartedPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(duration: 0.4), value: currentPage)

                // Custom page indicators
                pageIndicators
                    .padding(.bottom, 40)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            detectBiometricType()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let gradients: [[Color]] = [
            [Color(red: 0.25, green: 0.10, blue: 0.45), Color(red: 0.10, green: 0.05, blue: 0.30)],
            [Color(red: 0.15, green: 0.10, blue: 0.40), Color(red: 0.05, green: 0.15, blue: 0.35)],
            [Color(red: 0.10, green: 0.15, blue: 0.40), Color(red: 0.05, green: 0.25, blue: 0.35)],
            [Color(red: 0.30, green: 0.10, blue: 0.35), Color(red: 0.15, green: 0.05, blue: 0.30)],
            [Color(red: 0.20, green: 0.08, blue: 0.40), Color(red: 0.08, green: 0.20, blue: 0.35)],
        ]

        let colors = gradients[min(currentPage, gradients.count - 1)]

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon area
            ZStack {
                // Outer glow rings
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.indigo.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 60,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 140, height: 140)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .indigo.opacity(0.6), radius: 24)
            }

            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Text("WolfWhale LMS")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("Your complete learning companion")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Features Overview

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Everything You Need")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Powerful tools for modern education.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 14) {
                featureHighlight(
                    icon: "chart.bar.fill",
                    title: "Track your courses & grades",
                    description: "Monitor academic progress with real-time grade tracking and detailed analytics across all your enrolled courses.",
                    color: .indigo
                )

                featureHighlight(
                    icon: "paperplane.fill",
                    title: "Submit assignments digitally",
                    description: "Upload and submit work directly from your device with support for text, documents, and media.",
                    color: .purple
                )

                featureHighlight(
                    icon: "person.3.fill",
                    title: "Collaborate with classmates",
                    description: "Built-in messaging, group discussions, and shared resources to learn together.",
                    color: .cyan
                )

                featureHighlight(
                    icon: "clock.fill",
                    title: "Learn on your schedule",
                    description: "Access course materials anytime with offline support and flexible deadlines.",
                    color: .orange
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: Notifications Permission

    private var notificationsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .indigo.opacity(0.5), radius: 20)
            }

            VStack(spacing: 16) {
                Text("Stay on Top of\nAssignments & Grades")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Get timely reminders for upcoming deadlines,\ngrade updates, and important announcements\nso you never miss a beat.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()

            VStack(spacing: 12) {
                if notificationsRequested {
                    HStack(spacing: 8) {
                        Image(systemName: notificationsGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(notificationsGranted ? .green : .orange)
                        Text(notificationsGranted ? "Notifications Enabled" : "Notifications Skipped")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.vertical, 12)

                    nextPageButton(label: "Continue")
                } else {
                    Button {
                        hapticTrigger.toggle()
                        requestNotificationPermission()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .font(.subheadline.bold())
                            Text("Enable Notifications")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 32)
                    .shadow(color: .indigo.opacity(0.4), radius: 16, y: 8)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        notificationsRequested = true
                        notificationsGranted = false
                        OnboardingManager.hasRequestedNotifications = true
                        advanceToNextPage()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Page 4: Biometric Auth

    private var biometricPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)

                Image(systemName: biometricIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 20)
            }

            VStack(spacing: 16) {
                Text("Secure Your Account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Protect your data with \(biometricName).\nQuickly unlock the app without\nentering your password every time.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()

            VStack(spacing: 12) {
                if biometricEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(biometricName) Enabled")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.vertical, 12)

                    nextPageButton(label: "Continue")
                } else if biometricAvailable {
                    Button {
                        hapticTrigger.toggle()
                        enableBiometricAuth()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.subheadline.bold())
                            Text("Enable \(biometricName)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 32)
                    .shadow(color: .purple.opacity(0.4), radius: 16, y: 8)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        advanceToNextPage()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                } else {
                    // Biometric not available on device
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Biometric authentication is not\navailable on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)

                    nextPageButton(label: "Continue")
                }
            }

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Page 5: Get Started

    private var getStartedPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Confetti-like decorative circles
                if confettiVisible {
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(confettiColor(for: index).opacity(0.6))
                            .frame(width: CGFloat.random(in: 8...16), height: CGFloat.random(in: 8...16))
                            .offset(confettiOffset(for: index))
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)

                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.5), radius: 20)
                        .scaleEffect(checkmarkScale)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.2)) {
                    showCheckmark = true
                    checkmarkScale = 1.0
                }
                withAnimation(.spring(duration: 0.5).delay(0.5)) {
                    confettiVisible = true
                }
            }

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Your learning journey starts now.\nSign in with your school credentials\nto get started.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button {
                hapticTrigger.toggle()
                completeOnboarding()
            } label: {
                HStack(spacing: 10) {
                    Text("Get Started")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 32)
            .shadow(color: .indigo.opacity(0.4), radius: 16, y: 8)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Reusable Components

    private func featureHighlight(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        }
    }

    private func nextPageButton(label: String) -> some View {
        Button {
            hapticTrigger.toggle()
            advanceToNextPage()
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 32)
        .shadow(color: .indigo.opacity(0.4), radius: 16, y: 8)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    // MARK: - Confetti Helpers

    private func confettiColor(for index: Int) -> Color {
        let colors: [Color] = [.indigo, .purple, .cyan, .orange, .green, .red, .yellow, .mint]
        return colors[index % colors.count]
    }

    private func confettiOffset(for index: Int) -> CGSize {
        let angle = Double(index) * (.pi / 4.0)
        let radius: Double = 90
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }

    // MARK: - Actions

    private func advanceToNextPage() {
        withAnimation(.spring(duration: 0.4)) {
            if currentPage < totalPages - 1 {
                currentPage += 1
            }
        }
    }

    private func requestNotificationPermission() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                notificationsRequested = true
                OnboardingManager.hasRequestedNotifications = true
                advanceToNextPage()
            }
        }
        #endif
    }

    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricAvailable = available

        switch context.biometryType {
        case .faceID:
            biometricName = "Face ID"
            biometricIcon = "faceid"
        case .touchID:
            biometricName = "Touch ID"
            biometricIcon = "touchid"
        case .opticID:
            biometricName = "Optic ID"
            biometricIcon = "opticid"
        default:
            biometricName = "Biometrics"
            biometricIcon = "lock.shield"
        }
    }

    private func enableBiometricAuth() {
        #if canImport(UIKit)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.biometricEnabled)
        #endif
        OnboardingManager.hasConfiguredBiometric = true
        biometricEnabled = true
        advanceToNextPage()
    }

    private func completeOnboarding() {
        OnboardingManager.markOnboardingComplete()
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    EnhancedOnboardingView()
}
