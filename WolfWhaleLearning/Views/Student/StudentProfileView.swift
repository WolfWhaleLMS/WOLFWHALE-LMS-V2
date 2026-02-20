import SwiftUI

struct StudentProfileView: View {
    let viewModel: AppViewModel
    var walletService = WalletPassService()
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @State private var showAchievements = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsGrid
                    schoolIDLink
                    xpSection
                    achievementsSection
                    streakSection
                    appearanceSection
                    aboutSection
                    logoutButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AppSettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Double tap to open settings")
                }
            }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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

    private var schoolIDLink: some View {
        Group {
            if let user = viewModel.currentUser {
                NavigationLink {
                    SchoolIDView(user: user, walletService: walletService)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.text.rectangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("School ID")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("View your digital student ID card")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("School ID")
                .accessibilityHint("Double tap to view your digital school ID card")
            }
        }
    }

    private var appearanceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: colorSchemePreference == "dark" ? "moon.fill" : colorSchemePreference == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                .foregroundStyle(colorSchemePreference == "dark" ? .indigo : colorSchemePreference == "light" ? .orange : .gray)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text("Appearance")
                .font(.subheadline)
            Spacer()
            Picker("Appearance", selection: $colorSchemePreference) {
                Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                Label("Light", systemImage: "sun.max.fill").tag("light")
                Label("Dark", systemImage: "moon.fill").tag("dark")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
            .accessibilityLabel("Appearance mode")
            .accessibilityHint("Select system, light, or dark mode")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var aboutSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text("About")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                Image(systemName: "w.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("WolfWhale LMS")
                    .font(.headline)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Version")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("1.0.0")
                            .font(.caption.monospaced())
                    }
                    VStack(spacing: 2) {
                        Text("Build")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("2024.1")
                            .font(.caption.monospaced())
                    }
                }

                Text("\u{00A9} 2024 WolfWhale. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
        .padding(16)
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
