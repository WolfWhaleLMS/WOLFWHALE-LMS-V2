import SwiftUI

struct XPProfileView: View {
    @Bindable var viewModel: AppViewModel
    @State private var animatedProgress: Double = 0
    @State private var appeared = false
    @State private var earnedBadgeTrigger = false

    private var earnedBadges: [Badge] {
        viewModel.badges.filter(\.isEarned)
    }

    private var lockedBadges: [Badge] {
        viewModel.badges.filter { !$0.isEarned }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                xpRingSection
                levelInfoSection
                streakSection
                badgesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("XP Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadXPIfNeeded()
            withAnimation(.spring(duration: 1.2, bounce: 0.2).delay(0.3)) {
                animatedProgress = viewModel.xpProgressInLevel
                appeared = true
            }
        }
        .sensoryFeedback(.success, trigger: earnedBadgeTrigger)
    }

    // MARK: - XP Ring Section

    private var xpRingSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.indigo.opacity(0.15), lineWidth: 16)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.indigo, .purple, .indigo],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 4) {
                    Text("\(viewModel.currentXP)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(.label))
                        .contentTransition(.numericText())
                    Text("Total XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.top, 8)

            // XP to next level
            Text("\(viewModel.xpToNextLevel) XP to Level \(viewModel.currentLevel + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.currentXP) total XP, \(viewModel.xpToNextLevel) XP to next level")
    }

    // MARK: - Level Info Section

    private var levelInfoSection: some View {
        HStack(spacing: 0) {
            levelStatItem(
                icon: "star.fill",
                value: "Lv. \(viewModel.currentLevel)",
                label: viewModel.levelTierName,
                color: .indigo
            )

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1, height: 40)

            levelStatItem(
                icon: "bolt.fill",
                value: "\(viewModel.currentXP)",
                label: "Total XP",
                color: .purple
            )

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1, height: 40)

            levelStatItem(
                icon: "rosette",
                value: "\(earnedBadges.count)/\(viewModel.badges.count)",
                label: "Badges",
                color: .orange
            )
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func levelStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: appeared)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.currentStreak)-Day Streak")
                    .font(.headline.bold())
                    .foregroundStyle(Color(.label))
                Text(streakMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Streak flame intensity visualization
            VStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < viewModel.currentStreak
                              ? .orange.opacity(0.4 + Double(index) * 0.1)
                              : Color(.quaternarySystemFill))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak: \(viewModel.currentStreak) days. \(streakMessage)")
    }

    private var streakMessage: String {
        switch viewModel.currentStreak {
        case 0: "Start learning today to begin a streak!"
        case 1: "Great start! Come back tomorrow."
        case 2...6: "Keep going! Almost a week."
        case 7...13: "One week strong!"
        case 14...29: "Two weeks and counting!"
        case 30...: "Incredible dedication!"
        default: "Keep it up!"
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundStyle(.indigo)
                Text("Badges")
                    .font(.headline)
                Spacer()
                Text("\(earnedBadges.count) earned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !earnedBadges.isEmpty {
                Text("Earned")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)

                badgeGrid(badges: earnedBadges)
            }

            if !lockedBadges.isEmpty {
                Text("In Progress")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                badgeGrid(badges: lockedBadges)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func badgeGrid(badges: [Badge]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(badges) { badge in
                badgeCell(badge)
            }
        }
    }

    private func badgeCell(_ badge: Badge) -> some View {
        let rarityColor = Theme.courseColor(badge.rarity.colorName)

        return VStack(spacing: 8) {
            // Badge icon
            ZStack {
                Circle()
                    .fill(badge.isEarned
                          ? rarityColor.opacity(0.15)
                          : Color(.tertiarySystemFill))
                    .frame(width: 52, height: 52)

                Image(systemName: badge.icon)
                    .font(.title3)
                    .foregroundStyle(badge.isEarned ? rarityColor : .secondary.opacity(0.4))
            }
            .overlay {
                if badge.isEarned {
                    Circle()
                        .strokeBorder(rarityColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 52, height: 52)
                }
            }

            // Badge name
            Text(badge.name)
                .font(.caption2.bold())
                .foregroundStyle(Color(.label))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

            // Progress bar (for locked badges)
            if !badge.isEarned {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.quaternarySystemFill))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.6), .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * badge.progress)
                    }
                }
                .frame(height: 4)
                .clipShape(Capsule())

                Text("\(Int(badge.progress * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else {
                // Earned date or rarity
                Text(badge.rarity.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(rarityColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .opacity(badge.isEarned ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.name) badge, \(badge.isEarned ? "earned" : "\(Int(badge.progress * 100)) percent progress"), \(badge.rarity.rawValue) rarity")
    }
}

// MARK: - Level Progress Thresholds (reference)
// L1: 0-100 XP, L2: 101-300, L3: 301-600, L4: 601-1000, etc.

// MARK: - Preview

#Preview {
    NavigationStack {
        XPProfileView(viewModel: {
            let vm = AppViewModel()
            vm.loginAsDemo(role: .student)
            return vm
        }())
    }
}
