import SwiftUI

struct FishCollectionView: View {
    let viewModel: AppViewModel
    @State private var hapticTrigger = false
    @State private var selectedFish: AquariumFish?
    @State private var appearAnimation = false

    // MARK: - Computed Properties

    private var currentStreak: Int {
        viewModel.currentUser?.streak ?? 0
    }

    private var allFish: [AquariumFish] {
        AquariumFish.withUnlockStatus(currentStreak: currentStreak)
    }

    private var unlockedCount: Int {
        allFish.filter(\.isUnlocked).count
    }

    private var totalCount: Int {
        allFish.count
    }

    private var collectionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }

    /// Fish grouped by rarity, maintaining enum case order.
    private var groupedFish: [(rarity: FishRarity, fish: [AquariumFish])] {
        FishRarity.allCases.compactMap { rarity in
            let matching = allFish.filter { $0.rarity == rarity }
            return matching.isEmpty ? nil : (rarity, matching)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                rarityLegend
                fishSections
                progressFooter
            }
            .padding(.bottom, 32)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .navigationTitle("Fish Collection")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Streak badge
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("\(currentStreak)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Day Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 90)

                // Collection progress ring
                ZStack {
                    StatRing(
                        progress: collectionProgress,
                        color: Theme.brandPurple,
                        lineWidth: 8,
                        size: 80
                    )
                    VStack(spacing: 2) {
                        Text("\(unlockedCount)/\(totalCount)")
                            .font(.headline.bold().monospacedDigit())
                        Text("Unlocked")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Next unlock teaser
                if let next = AquariumFish.nextToUnlock(currentStreak: currentStreak) {
                    VStack(spacing: 4) {
                        Image(systemName: next.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("\(next.streakRequired - currentStreak)")
                            .font(.title2.bold().monospacedDigit())
                        Text("Days to Next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 90)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.brandGreen)
                        Text("Complete!")
                            .font(.headline.bold())
                        Text("All Unlocked")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 90)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 12)
    }

    // MARK: - Rarity Legend

    private var rarityLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FishRarity.allCases, id: \.rawValue) { rarity in
                    let countForRarity = allFish.filter { $0.rarity == rarity }.count
                    let unlockedForRarity = allFish.filter { $0.rarity == rarity && $0.isUnlocked }.count

                    HStack(spacing: 6) {
                        Circle()
                            .fill(rarity.color)
                            .frame(width: 10, height: 10)
                        Text(rarity.rawValue)
                            .font(.caption.bold())
                        Text("\(unlockedForRarity)/\(countForRarity)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(rarity.color.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal)
        }
        .opacity(appearAnimation ? 1 : 0)
    }

    // MARK: - Fish Sections

    private var fishSections: some View {
        LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
            ForEach(groupedFish, id: \.rarity) { group in
                Section {
                    VStack(spacing: 12) {
                        ForEach(group.fish) { fish in
                            fishCard(fish)
                        }
                    }
                    .padding(.horizontal)
                } header: {
                    sectionHeader(for: group.rarity, fish: group.fish)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(for rarity: FishRarity, fish: [AquariumFish]) -> some View {
        HStack {
            Circle()
                .fill(rarity.color)
                .frame(width: 12, height: 12)
            Text(rarity.rawValue)
                .font(.headline.bold())
            Text(rarity.label)
                .font(.subheadline)
            Spacer()
            let unlocked = fish.filter(\.isUnlocked).count
            Text("\(unlocked)/\(fish.count)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Fish Card

    private func fishCard(_ fish: AquariumFish) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                // Fish icon
                fishIcon(fish)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(fish.isUnlocked ? fish.name : "???")
                            .font(.headline.bold())
                            .foregroundStyle(fish.isUnlocked ? .primary : .secondary)

                        Spacer()

                        // Rarity badge
                        Text("\(fish.rarity.label) \(fish.rarity.rawValue)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(fish.rarity.color.opacity(0.2), in: Capsule())
                            .foregroundStyle(fish.rarity.color)
                    }

                    if fish.isUnlocked {
                        Text(fish.species)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            // Description / unlock status
            if fish.isUnlocked {
                unlockedDetails(fish)
            } else {
                lockedDetails(fish)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(fish.isUnlocked
                      ? Color(.systemBackground)
                      : Color(.systemGray6).opacity(0.7))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    fish.isUnlocked
                        ? fish.rarity.color.opacity(0.5)
                        : Color.gray.opacity(0.2),
                    lineWidth: fish.isUnlocked ? 1.5 : 1
                )
        }
        .shadow(color: fish.isUnlocked ? fish.rarity.glowColor : .clear, radius: 6, y: 2)
        .sensoryFeedback(.selection, trigger: selectedFish?.id == fish.id)
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) {
                selectedFish = selectedFish?.id == fish.id ? nil : fish
            }
            hapticTrigger.toggle()
        }
    }

    // MARK: - Fish Icon

    private func fishIcon(_ fish: AquariumFish) -> some View {
        ZStack {
            Circle()
                .fill(
                    fish.isUnlocked
                        ? fish.primaryColor.opacity(0.15)
                        : Color.gray.opacity(0.1)
                )
                .frame(width: 52, height: 52)

            if fish.isUnlocked {
                Image(systemName: fish.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(
                        fish.primaryColor.gradient
                    )
                    .shadow(color: fish.rarity.glowColor, radius: 4)
            } else {
                Image(systemName: fish.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "questionmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
            }
        }
    }

    // MARK: - Unlocked Details

    private func unlockedDetails(_ fish: AquariumFish) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedFish?.id == fish.id {
                Text(fish.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.brandGreen)
                    .font(.caption)
                Text("Unlocked at \(fish.streakRequired) day streak")
                    .font(.caption)
                    .foregroundStyle(Theme.brandGreen)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Locked Details

    private func lockedDetails(_ fish: AquariumFish) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress toward unlock
            let progress = min(Double(currentStreak) / Double(fish.streakRequired), 1.0)
            let daysRemaining = max(fish.streakRequired - currentStreak, 0)

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Unlock at \(fish.streakRequired) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(daysRemaining) days to go")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(fish.rarity.color.opacity(0.6))
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(currentStreak)/\(fish.streakRequired) days")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(fish.rarity.color.opacity(0.7))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Progress Footer

    private var progressFooter: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Collection Progress")
                    .font(.headline.bold())
                Spacer()
                Text("\(Int(collectionProgress * 100))%")
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(Theme.brandPurple)
            }

            // Full-width progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 10)
                    Capsule()
                        .fill(Theme.brandGradientHorizontal)
                        .frame(width: geo.size.width * collectionProgress, height: 10)
                }
            }
            .frame(height: 10)

            // Milestone markers
            HStack {
                ForEach(FishRarity.allCases, id: \.rawValue) { rarity in
                    let count = allFish.filter { $0.rarity == rarity && $0.isUnlocked }.count
                    let total = allFish.filter { $0.rarity == rarity }.count
                    let complete = count == total && total > 0

                    VStack(spacing: 2) {
                        Image(systemName: complete ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(complete ? rarity.color : .gray.opacity(0.4))
                        Text(String(rarity.rawValue.prefix(3)))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(complete ? rarity.color : .gray.opacity(0.4))
                    }
                    if rarity != .mythical {
                        Spacer()
                    }
                }
            }

            if unlockedCount == totalCount {
                Label("All fish collected! You are a true ocean master.", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FishCollectionView(viewModel: AppViewModel())
    }
}
