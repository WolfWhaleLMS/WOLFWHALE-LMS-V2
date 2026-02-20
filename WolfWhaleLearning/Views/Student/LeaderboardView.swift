import SwiftUI

struct LeaderboardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedScope: LeaderboardScope = .allTime
    @State private var appeared = false

    private var currentUserId: UUID? {
        viewModel.currentUser?.id
    }

    private var sortedEntries: [LeaderboardEntry] {
        viewModel.leaderboard.sorted { $0.rank < $1.rank }
    }

    private var topThree: [LeaderboardEntry] {
        Array(sortedEntries.prefix(3))
    }

    private var remainingEntries: [LeaderboardEntry] {
        Array(sortedEntries.dropFirst(3))
    }

    private var currentUserEntry: LeaderboardEntry? {
        guard let userId = currentUserId else { return nil }
        return viewModel.leaderboard.first { $0.id == userId }
    }

    private var currentUserRank: Int {
        if let entry = currentUserEntry {
            return entry.rank
        }
        // Fallback: find by name
        if let user = viewModel.currentUser {
            return viewModel.leaderboard.first { $0.userName == user.fullName }?.rank ?? 0
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.leaderboard.isEmpty {
                    loadingState
                } else if viewModel.leaderboard.isEmpty {
                    emptyState
                } else {
                    leaderboardContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leaderboard")
            .refreshable {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Main Content

    private var leaderboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                scopePicker
                userStatsCard
                podiumSection
                rankingsListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading rankings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading leaderboard rankings")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Rankings Yet",
            systemImage: "trophy",
            description: Text("Complete lessons and assignments to earn XP and appear on the leaderboard")
        )
    }

    // MARK: - Scope Picker

    private var scopePicker: some View {
        Picker("Time Period", selection: $selectedScope) {
            ForEach(LeaderboardScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - User Stats Card

    private var userStatsCard: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "number",
                value: currentUserRank > 0 ? "#\(currentUserRank)" : "--",
                label: "Your Rank",
                color: .pink
            )
            divider
            statItem(
                icon: "bolt.fill",
                value: "\(viewModel.currentUser?.xp ?? 0)",
                label: "XP",
                color: .purple
            )
            divider
            statItem(
                icon: "star.fill",
                value: "Lv.\(viewModel.currentUser?.level ?? 1)",
                label: "Level",
                color: .yellow
            )
            divider
            statItem(
                icon: "flame.fill",
                value: "\(viewModel.currentUser?.streak ?? 0)",
                label: "Streak",
                color: .orange
            )
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 40)
    }

    // MARK: - Podium Section

    private var podiumSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Top Players")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 20)

            if topThree.count >= 3 {
                podiumLayout
            } else if topThree.count > 0 {
                // Fewer than 3 entries: show what we have
                HStack(spacing: 16) {
                    ForEach(topThree) { entry in
                        podiumPlayer(entry: entry, height: 100)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private var podiumLayout: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Second place - left
            podiumPlayer(entry: topThree[1], height: 90)

            // First place - center (tallest)
            podiumPlayer(entry: topThree[0], height: 120)

            // Third place - right
            podiumPlayer(entry: topThree[2], height: 75)
        }
    }

    private func podiumPlayer(entry: LeaderboardEntry, height: CGFloat) -> some View {
        let medalColor = medalColor(for: entry.rank)
        let isFirst = entry.rank == 1

        return VStack(spacing: 8) {
            // Crown for first place
            if isFirst {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                    .transition(.scale.combined(with: .opacity))
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarGradient(for: entry.rank),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isFirst ? 64 : 52, height: isFirst ? 64 : 52)
                    .shadow(color: medalColor.opacity(0.4), radius: 6)

                Image(systemName: entry.avatarSystemName)
                    .font(isFirst ? .title2 : .title3)
                    .foregroundStyle(.white)

                // Rank badge
                Text("\(entry.rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(medalColor, in: Circle())
                    .overlay(
                        Circle().stroke(.white, lineWidth: 2)
                    )
                    .offset(x: 0, y: isFirst ? 28 : 22)
            }
            .padding(.bottom, isFirst ? 10 : 6)

            // Name
            Text(entry.userName)
                .font(isFirst ? .subheadline.bold() : .caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // XP
            Text("\(entry.xp) XP")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Level badge
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                Text("Lv.\(entry.level)")
                    .font(.caption2.bold())
            }
            .foregroundStyle(medalColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(medalColor.opacity(0.12), in: Capsule())

            // Podium bar
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [medalColor.opacity(0.6), medalColor.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height)
                .overlay(alignment: .top) {
                    Text(rankLabel(for: entry.rank))
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank): \(entry.userName), level \(entry.level), \(entry.xp) XP")
    }

    // MARK: - Rankings List

    private var rankingsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(.pink)
                Text("Full Rankings")
                    .font(.headline)
                Spacer()
                Text("\(sortedEntries.count) players")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if remainingEntries.isEmpty && topThree.count <= 3 {
                // All entries are in the podium
                HStack {
                    Spacer()
                    Text("All players shown in the podium above")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                // Also show top 3 in the list for completeness
                ForEach(sortedEntries) { entry in
                    rankingRow(entry: entry)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func rankingRow(entry: LeaderboardEntry) -> some View {
        let isCurrentUser = isCurrentUserEntry(entry)

        return HStack(spacing: 12) {
            // Rank number
            if entry.rank <= 3 {
                Image(systemName: "medal.fill")
                    .font(.subheadline)
                    .foregroundStyle(medalColor(for: entry.rank))
                    .frame(width: 28)
            } else {
                Text("#\(entry.rank)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarGradient(for: entry.rank),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)

                Image(systemName: entry.avatarSystemName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            // Name and XP bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.userName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                }

                // XP progress mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: entry.rank <= 3
                                        ? [medalColor(for: entry.rank).opacity(0.8), medalColor(for: entry.rank)]
                                        : [.purple.opacity(0.6), .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: xpBarWidth(entry: entry, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // XP amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.xp)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Level badge
            Text("Lv.\(entry.level)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    entry.rank <= 3
                        ? medalColor(for: entry.rank)
                        : .purple,
                    in: Capsule()
                )
        }
        .padding(12)
        .background(
            isCurrentUser
                ? AnyShapeStyle(.pink.opacity(0.08))
                : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? .pink.opacity(0.3) : .clear, lineWidth: 1.5)
        )
        .animation(.smooth, value: entry.rank)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank): \(entry.userName)\(isCurrentUserEntry(entry) ? ", that's you" : ""), level \(entry.level), \(entry.xp) XP")
    }

    // MARK: - Helpers

    private func isCurrentUserEntry(_ entry: LeaderboardEntry) -> Bool {
        if let userId = currentUserId, entry.id == userId {
            return true
        }
        if let user = viewModel.currentUser, entry.userName == user.fullName {
            return true
        }
        return false
    }

    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: .yellow
        case 2: Color(.systemGray3)
        case 3: .orange
        default: .purple
        }
    }

    private func avatarGradient(for rank: Int) -> [Color] {
        switch rank {
        case 1: [.yellow, .orange]
        case 2: [Color(.systemGray3), Color(.systemGray4)]
        case 3: [.orange, .red.opacity(0.7)]
        default: [.purple, .blue]
        }
    }

    private func rankLabel(for rank: Int) -> String {
        switch rank {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(rank)th"
        }
    }

    private func xpBarWidth(entry: LeaderboardEntry, totalWidth: CGFloat) -> CGFloat {
        guard let maxXP = sortedEntries.first?.xp, maxXP > 0 else { return 0 }
        return totalWidth * CGFloat(entry.xp) / CGFloat(maxXP)
    }
}

// MARK: - Leaderboard Scope

enum LeaderboardScope: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    LeaderboardView(viewModel: {
        let vm = AppViewModel()
        vm.loginAsDemo(role: .student)
        return vm
    }())
}
