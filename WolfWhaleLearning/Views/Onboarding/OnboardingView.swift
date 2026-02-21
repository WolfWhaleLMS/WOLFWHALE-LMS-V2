import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var hapticTrigger = false

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
                                        .fill(.clear)
                                        .glassEffect(.regular, in: .capsule)
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
                    rolesPage.tag(1)
                    featuresPage.tag(2)
                    gamificationPage.tag(3)
                    getStartedPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

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
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let gradients: [[Color]] = [
            [Color(red: 0.25, green: 0.10, blue: 0.45), Color(red: 0.10, green: 0.05, blue: 0.30)],   // Deep purple
            [Color(red: 0.15, green: 0.10, blue: 0.40), Color(red: 0.05, green: 0.15, blue: 0.35)],   // Indigo-blue
            [Color(red: 0.10, green: 0.15, blue: 0.40), Color(red: 0.05, green: 0.25, blue: 0.35)],   // Blue-teal
            [Color(red: 0.30, green: 0.10, blue: 0.35), Color(red: 0.15, green: 0.05, blue: 0.30)],   // Purple-magenta
            [Color(red: 0.20, green: 0.08, blue: 0.40), Color(red: 0.08, green: 0.20, blue: 0.35)],   // Purple-cyan
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

            // Large whale/book icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 140, height: 140)

                Image(systemName: "book.and.wrench.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
            }

            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                Text("WolfWhale LMS")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("A modern learning management system\ndesigned for the next generation of education.")
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

    // MARK: - Page 2: Roles

    private var rolesPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Four Experiences")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("One platform, tailored for everyone.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                roleCard(icon: "graduationcap.fill", title: "Student", description: "Learn, grow, and level up", colors: [.indigo, .purple])
                roleCard(icon: "person.fill.checkmark", title: "Teacher", description: "Create and manage courses", colors: [.pink, .orange])
                roleCard(icon: "figure.and.child.holdinghands", title: "Parent", description: "Track your child's progress", colors: [.green, .teal])
                roleCard(icon: "shield.lefthalf.filled", title: "Admin", description: "Oversee the entire school", colors: [.blue, .cyan])
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: Features

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
                featureRow(icon: "book.fill", title: "Interactive Courses", description: "Rich lessons with modules, quizzes, and progress tracking", color: .blue)
                featureRow(icon: "chart.bar.fill", title: "Grades & Analytics", description: "Real-time grade tracking and detailed performance insights", color: .green)
                featureRow(icon: "bubble.left.and.bubble.right.fill", title: "Messaging", description: "Built-in communication between students, teachers, and parents", color: .purple)
                featureRow(icon: "megaphone.fill", title: "Announcements", description: "School-wide and class-specific announcements", color: .orange)
                featureRow(icon: "person.crop.rectangle.stack.fill", title: "Attendance", description: "Digital attendance tracking and history", color: .pink)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 4: Gamification

    private var gamificationPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Learn & Level Up")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Education meets engagement.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    gamificationCard(icon: "flame.fill", title: "Streaks", description: "Build daily learning habits", color: .orange)
                    gamificationCard(icon: "trophy.fill", title: "Leaderboards", description: "Compete with classmates", color: .yellow)
                }

                HStack(spacing: 12) {
                    gamificationCard(icon: "medal.fill", title: "Achievements", description: "Unlock badges and rewards", color: .cyan)
                    gamificationCard(icon: "chart.line.uptrend.xyaxis", title: "Progress", description: "Track your learning journey", color: .green)
                }

            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 5: Get Started

    private var getStartedPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .pink.opacity(0.4), radius: 20)
            }

            VStack(spacing: 16) {
                Text("Ready to Begin?")
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
            .tint(.pink)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 32)
            .shadow(color: .pink.opacity(0.4), radius: 16, y: 8)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Component Builders

    private func roleCard(icon: String, title: String, description: String, colors: [Color]) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.3) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.2), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func gamificationCard(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 8)

            VStack(spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
}
