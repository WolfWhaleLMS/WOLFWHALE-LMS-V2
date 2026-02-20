import SwiftUI

struct StudentProfileView: View {
    let viewModel: AppViewModel
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showAchievements = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsGrid
                    xpSection
                    achievementsSection
                    streakSection
                    appearanceSection
                    logoutButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            Text(viewModel.currentUser?.fullName ?? "Student")
                .font(.title2.bold())
            Text(viewModel.currentUser?.email ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Level \(viewModel.currentUser?.level ?? 1)")
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            profileStat(icon: "bolt.fill", value: "\(viewModel.currentUser?.xp ?? 0)", label: "Total XP", color: .purple)
            profileStat(icon: "bitcoinsign.circle.fill", value: "\(viewModel.currentUser?.coins ?? 0)", label: "Coins", color: .yellow)
            profileStat(icon: "flame.fill", value: "\(viewModel.currentUser?.streak ?? 0) days", label: "Streak", color: .orange)
            profileStat(icon: "book.fill", value: "\(viewModel.courses.count)", label: "Courses", color: .blue)
        }
    }

    private func profileStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    private var xpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("XP Progress")
                    .font(.headline)
                Spacer()
                Text("Level \(viewModel.currentUser?.level ?? 1) → \((viewModel.currentUser?.level ?? 1) + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            XPBar(progress: viewModel.currentUser?.xpProgress ?? 0, level: viewModel.currentUser?.level ?? 1)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.achievements.filter(\.isUnlocked).count)/\(viewModel.achievements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.achievements) { achievement in
                        VStack(spacing: 8) {
                            Image(systemName: achievement.iconSystemName)
                                .font(.title2)
                                .foregroundStyle(achievement.isUnlocked ? Theme.courseColor(achievement.rarity.colorName) : .secondary.opacity(0.3))
                                .frame(width: 48, height: 48)
                                .background(
                                    achievement.isUnlocked
                                    ? Theme.courseColor(achievement.rarity.colorName).opacity(0.15)
                                    : Color(.tertiarySystemFill),
                                    in: Circle()
                                )
                            Text(achievement.title)
                                .font(.caption2.bold())
                                .lineLimit(1)
                            Text(achievement.rarity.rawValue)
                                .font(.caption2)
                                .foregroundStyle(achievement.isUnlocked ? Theme.courseColor(achievement.rarity.colorName) : .secondary)
                        }
                        .frame(width: 80)
                        .opacity(achievement.isUnlocked ? 1 : 0.5)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.currentUser?.streak ?? 0) Day Streak")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day < (viewModel.currentUser?.streak ?? 0) % 7 ? .green : Color(.tertiarySystemFill))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if day < (viewModel.currentUser?.streak ?? 0) % 7 {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        Text(Calendar.current.shortWeekdaySymbols[day])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var appearanceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(isDarkMode ? .indigo : .orange)
                .frame(width: 28)
            Text("Dark Mode")
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            viewModel.logout()
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
    }
}
