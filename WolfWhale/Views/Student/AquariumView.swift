import SwiftUI

// MARK: - Aquarium View

struct AquariumView: View {
    let viewModel: AppViewModel

    @State private var animating = false
    @State private var wavePhase: CGFloat = 0
    @State private var seaweedPhase: CGFloat = 0
    @State private var showCollection = false

    // MARK: - Computed Properties

    private var currentStreak: Int {
        viewModel.currentUser?.streak ?? 0
    }

    private var unlockedFish: [AquariumFish] {
        AquariumFish.unlockedFish(currentStreak: currentStreak)
    }

    private var allFishWithStatus: [AquariumFish] {
        AquariumFish.withUnlockStatus(currentStreak: currentStreak)
    }

    private var nextFish: AquariumFish? {
        AquariumFish.nextToUnlock(currentStreak: currentStreak)
    }

    private var totalFishCount: Int {
        AquariumFish.allFish.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        statsBar
                        tankView
                        if unlockedFish.isEmpty {
                            emptyState
                        }
                        if let next = nextFish {
                            nextFishCard(next)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("My Aquarium")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.12, blue: 0.22),
                Color(red: 0.05, green: 0.15, blue: 0.35),
                Color(red: 0.03, green: 0.10, blue: 0.28),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 12) {
            streakBadge
            fishCountBadge
            Spacer()
            collectionButton
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stats: \(currentStreak) day streak, \(unlockedFish.count) of \(totalFishCount) fish unlocked")
    }

    private var streakBadge: some View {
        Label {
            Text("\(currentStreak) Day Streak")
                .font(.subheadline.weight(.semibold))
        } icon: {
            Text("\u{1F525}")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var fishCountBadge: some View {
        Label {
            Text("\(unlockedFish.count)/\(totalFishCount) Fish")
                .font(.subheadline.weight(.semibold))
        } icon: {
            Text("\u{1F41F}")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var collectionButton: some View {
        NavigationLink {
            FishCollectionView(viewModel: viewModel)
        } label: {
            Label("Collection", systemImage: "square.grid.2x2.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.brandPurple.opacity(0.8), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    // MARK: - Tank View

    private var tankView: some View {
        ZStack {
            // Ocean water gradient
            oceanBackground

            // Sand floor
            sandFloor

            // Coral decorations
            coralDecorations

            // Seaweed
            seaweedLayer

            // Bubbles
            bubblesLayer

            // Swimming fish
            fishLayer

            // Glass reflections
            glassReflection

            // Wave surface
            waveOverlay
        }
        .frame(height: 380)
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.35),
                            .cyan.opacity(0.15),
                            .blue.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        }
        .shadow(color: .cyan.opacity(0.2), radius: 16, y: 8)
        .accessibilityLabel("Your aquarium tank")
    }

    private var oceanBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.78, blue: 0.95),
                Color(red: 0.20, green: 0.55, blue: 0.85),
                Color(red: 0.10, green: 0.35, blue: 0.70),
                Color(red: 0.06, green: 0.22, blue: 0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Sand Floor

    private var sandFloor: some View {
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                // Sand base
                LinearGradient(
                    colors: [
                        Color(red: 0.82, green: 0.72, blue: 0.55),
                        Color(red: 0.68, green: 0.56, blue: 0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)

                // Pebbles scattered on sand
                GeometryReader { geo in
                    pebbleCluster(geo: geo)
                }
                .frame(height: 36)
            }
        }
    }

    private func pebbleCluster(geo: GeometryProxy) -> some View {
        ZStack {
            pebble(color: Color(red: 0.50, green: 0.50, blue: 0.48), w: 10, h: 7)
                .position(x: geo.size.width * 0.12, y: 12)
            pebble(color: Color(red: 0.62, green: 0.55, blue: 0.44), w: 8, h: 5)
                .position(x: geo.size.width * 0.28, y: 8)
            pebble(color: Color(red: 0.55, green: 0.52, blue: 0.48), w: 12, h: 8)
                .position(x: geo.size.width * 0.45, y: 14)
            pebble(color: Color(red: 0.58, green: 0.48, blue: 0.38), w: 7, h: 5)
                .position(x: geo.size.width * 0.65, y: 10)
            pebble(color: Color(red: 0.52, green: 0.50, blue: 0.46), w: 9, h: 6)
                .position(x: geo.size.width * 0.82, y: 13)
            pebble(color: Color(red: 0.60, green: 0.54, blue: 0.42), w: 6, h: 4)
                .position(x: geo.size.width * 0.92, y: 8)
        }
    }

    private func pebble(color: Color, w: CGFloat, h: CGFloat) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }

    // MARK: - Coral Decorations

    private var coralDecorations: some View {
        GeometryReader { geo in
            ZStack {
                // Left coral - branching fan shape
                coralBranch(
                    color: Color(red: 1.0, green: 0.4, blue: 0.5),
                    height: 50,
                    width: 35
                )
                .position(x: geo.size.width * 0.10, y: geo.size.height - 58)

                // Center coral - round brain coral
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.9, green: 0.6, blue: 0.2),
                                Color(red: 0.7, green: 0.35, blue: 0.1),
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 18
                        )
                    )
                    .frame(width: 32, height: 28)
                    .position(x: geo.size.width * 0.42, y: geo.size.height - 48)

                // Right coral - tall branching
                coralBranch(
                    color: Color(red: 0.85, green: 0.3, blue: 0.55),
                    height: 60,
                    width: 28
                )
                .position(x: geo.size.width * 0.88, y: geo.size.height - 64)

                // Small accent coral
                coralBranch(
                    color: Color(red: 0.4, green: 0.8, blue: 0.65),
                    height: 30,
                    width: 20
                )
                .position(x: geo.size.width * 0.68, y: geo.size.height - 49)
            }
        }
    }

    private func coralBranch(color: Color, height: CGFloat, width: CGFloat) -> some View {
        ZStack {
            // Main trunk
            RoundedRectangle(cornerRadius: width * 0.3)
                .fill(color.opacity(0.9))
                .frame(width: width * 0.35, height: height)

            // Left branch
            RoundedRectangle(cornerRadius: width * 0.25)
                .fill(color.opacity(0.75))
                .frame(width: width * 0.25, height: height * 0.55)
                .rotationEffect(.degrees(-25))
                .offset(x: -width * 0.25, y: -height * 0.15)

            // Right branch
            RoundedRectangle(cornerRadius: width * 0.25)
                .fill(color.opacity(0.8))
                .frame(width: width * 0.22, height: height * 0.5)
                .rotationEffect(.degrees(20))
                .offset(x: width * 0.22, y: -height * 0.18)
        }
    }

    // MARK: - Seaweed

    private var seaweedLayer: some View {
        GeometryReader { geo in
            ZStack {
                AquariumSeaweedShape(swayAmount: seaweedPhase * 8, segments: 7)
                    .fill(Color(red: 0.15, green: 0.58, blue: 0.25).opacity(0.8))
                    .frame(width: 14, height: 65)
                    .position(x: geo.size.width * 0.22, y: geo.size.height - 68)

                AquariumSeaweedShape(swayAmount: seaweedPhase * 6, segments: 5)
                    .fill(Color(red: 0.20, green: 0.65, blue: 0.30).opacity(0.7))
                    .frame(width: 12, height: 48)
                    .position(x: geo.size.width * 0.52, y: geo.size.height - 58)

                AquariumSeaweedShape(swayAmount: seaweedPhase * 10, segments: 8)
                    .fill(Color(red: 0.12, green: 0.52, blue: 0.20).opacity(0.75))
                    .frame(width: 11, height: 72)
                    .position(x: geo.size.width * 0.78, y: geo.size.height - 72)

                AquariumSeaweedShape(swayAmount: seaweedPhase * 7, segments: 4)
                    .fill(Color(red: 0.18, green: 0.60, blue: 0.28).opacity(0.65))
                    .frame(width: 10, height: 38)
                    .position(x: geo.size.width * 0.35, y: geo.size.height - 53)
            }
        }
    }

    // MARK: - Bubbles

    private var bubblesLayer: some View {
        GeometryReader { geo in
            ForEach(AquariumBubbleData.all) { bubble in
                AquariumBubbleView(
                    data: bubble,
                    tankHeight: geo.size.height,
                    animating: animating
                )
                .position(x: geo.size.width * bubble.xFraction, y: geo.size.height)
            }
        }
    }

    // MARK: - Fish Layer

    private var fishLayer: some View {
        GeometryReader { geo in
            ForEach(unlockedFish) { fish in
                SwimmingFishView(
                    fish: fish,
                    tankSize: geo.size,
                    animating: animating
                )
            }
        }
    }

    // MARK: - Glass Reflection

    private var glassReflection: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width * 0.07, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.45))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.08))

            Path { path in
                path.move(to: CGPoint(x: geo.size.width * 0.11, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width * 0.15, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.65))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.50))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.05))
        }
    }

    // MARK: - Wave Overlay

    private var waveOverlay: some View {
        GeometryReader { _ in
            AquariumWaveShape(phase: wavePhase, amplitude: 5, frequency: 2.5)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fish.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.brandBlue.opacity(0.6))
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)

            Text("Your Aquarium Awaits!")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            let daysNeeded = max(0, 5 - currentStreak)
            Text("Start your attendance streak to unlock your first fish! \(daysNeeded) day\(daysNeeded == 1 ? "" : "s") to go!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Next Fish Card

    private func nextFishCard(_ fish: AquariumFish) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: fish.icon)
                    .font(.title2)
                    .foregroundStyle(fish.primaryColor.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Next: \(fish.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(fish.rarity.rawValue)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(fish.rarity.color.opacity(0.8), in: Capsule())
                            .foregroundStyle(.white)
                    }

                    Text("\(currentStreak)/\(fish.streakRequired) days")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text(fish.rarity.label)
                    .font(.caption)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.brandBlue, fish.rarity.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * min(1.0, CGFloat(currentStreak) / CGFloat(fish.streakRequired)),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Animation Start

    private func startAnimations() {
        animating = true
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            seaweedPhase = 1
        }
    }
}

// MARK: - Swimming Fish View

/// Displays a single AquariumFish with horizontal swimming animation and vertical bobbing.
/// Uses phaseAnimator for swimming and a repeatForever animation for the bob.
private struct SwimmingFishView: View {
    let fish: AquariumFish
    let tankSize: CGSize
    let animating: Bool

    @State private var bobOffset: CGFloat = 0

    /// Deterministic vertical position based on fish id hash
    private var yFraction: CGFloat {
        let hash = abs(fish.id.hashValue)
        let fraction = CGFloat(hash % 600) / 1000.0 + 0.12
        return min(fraction, 0.72)
    }

    /// Base font size scaled by fish size multiplier
    private var fontSize: CGFloat {
        28 * fish.size
    }

    /// Animation duration derived from swim speed (higher speed = faster = shorter duration)
    private var swimDuration: Double {
        max(3.0, 8.0 / fish.swimSpeed)
    }

    /// Stagger delay based on fish id so they don't all start at once
    private var staggerDelay: Double {
        Double(abs(fish.id.hashValue) % 300) / 100.0
    }

    private var isSpecialRarity: Bool {
        fish.rarity == .legendary || fish.rarity == .mythical
    }

    var body: some View {
        let padding = fontSize + 10
        let startX = -padding
        let endX = tankSize.width + padding
        let yPos = tankSize.height * yFraction

        Image(systemName: fish.icon)
            .font(.system(size: fontSize))
            .foregroundStyle(fish.primaryColor.gradient)
            .shadow(color: fish.primaryColor.opacity(0.5), radius: 4, y: 2)
            .overlay {
                if isSpecialRarity {
                    Image(systemName: fish.icon)
                        .font(.system(size: fontSize))
                        .foregroundStyle(fish.rarity.glowColor)
                        .blur(radius: 6)
                }
            }
            .modifier(SpecialRarityEffect(isSpecial: isSpecialRarity))
            .offset(y: yPos + bobOffset)
            .phaseAnimator(
                [false, true],
                trigger: animating
            ) { content, phase in
                content
                    .scaleEffect(x: phase ? 1 : -1, y: 1)
                    .offset(x: phase ? endX : startX)
            } animation: { phase in
                .linear(duration: swimDuration).delay(phase ? 0 : staggerDelay)
            }
            .accessibilityLabel("\(fish.name) fish")
            .accessibilityHidden(false)
            .onAppear {
                let bobAmount = CGFloat.random(in: 6...14)
                withAnimation(
                    .easeInOut(duration: 1.4 + Double.random(in: 0...0.6))
                        .repeatForever(autoreverses: true)
                        .delay(staggerDelay * 0.3)
                ) {
                    bobOffset = bobAmount
                }
            }
    }
}

// MARK: - Special Rarity Effect Modifier

private struct SpecialRarityEffect: ViewModifier {
    let isSpecial: Bool

    func body(content: Content) -> some View {
        if isSpecial {
            content
                .symbolEffect(.pulse.wholeSymbol, options: .repeating.speed(0.5))
        } else {
            content
        }
    }
}

// MARK: - Aquarium Bubble Data & View

private struct AquariumBubbleData: Identifiable {
    let id: Int
    let xFraction: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double

    static let all: [AquariumBubbleData] = [
        AquariumBubbleData(id: 0, xFraction: 0.10, size: 5, duration: 4.0, delay: 0),
        AquariumBubbleData(id: 1, xFraction: 0.25, size: 4, duration: 3.5, delay: 1.0),
        AquariumBubbleData(id: 2, xFraction: 0.38, size: 6, duration: 4.5, delay: 0.5),
        AquariumBubbleData(id: 3, xFraction: 0.52, size: 3, duration: 3.8, delay: 2.0),
        AquariumBubbleData(id: 4, xFraction: 0.65, size: 5, duration: 4.2, delay: 0.8),
        AquariumBubbleData(id: 5, xFraction: 0.78, size: 4, duration: 3.2, delay: 1.5),
        AquariumBubbleData(id: 6, xFraction: 0.88, size: 6, duration: 3.6, delay: 2.5),
        AquariumBubbleData(id: 7, xFraction: 0.45, size: 3, duration: 4.8, delay: 1.8),
        AquariumBubbleData(id: 8, xFraction: 0.18, size: 4, duration: 3.4, delay: 3.0),
        AquariumBubbleData(id: 9, xFraction: 0.72, size: 5, duration: 4.0, delay: 0.3),
    ]
}

private struct AquariumBubbleView: View {
    let data: AquariumBubbleData
    let tankHeight: CGFloat
    let animating: Bool

    enum Phase: CaseIterable {
        case bottom, rising, fadedTop
    }

    var body: some View {
        Circle()
            .frame(width: data.size, height: data.size)
            .phaseAnimator(Phase.allCases, trigger: animating) { content, phase in
                content
                    .foregroundStyle(.white.opacity(opacity(for: phase)))
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(opacity(for: phase) * 0.5), lineWidth: 0.5)
                    }
                    .offset(y: yOffset(for: phase))
            } animation: { phase in
                switch phase {
                case .bottom: .easeIn(duration: 0.01).delay(data.delay)
                case .rising: .easeOut(duration: data.duration)
                case .fadedTop: .easeIn(duration: 0.5)
                }
            }
    }

    private func opacity(for phase: Phase) -> CGFloat {
        switch phase {
        case .bottom: 0
        case .rising: 0.5
        case .fadedTop: 0
        }
    }

    private func yOffset(for phase: Phase) -> CGFloat {
        switch phase {
        case .bottom: 0
        case .rising: -(tankHeight * 0.55)
        case .fadedTop: -(tankHeight * 0.88)
        }
    }
}

// MARK: - Aquarium Wave Shape

private struct AquariumWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let midY = rect.midY

        path.move(to: CGPoint(x: 0, y: 0))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let y = midY + sin((relativeX * frequency * .pi * 2) + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Aquarium Seaweed Shape

private struct AquariumSeaweedShape: Shape {
    var swayAmount: CGFloat
    var segments: Int

    var animatableData: CGFloat {
        get { swayAmount }
        set { swayAmount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segmentHeight = rect.height / CGFloat(segments)
        let centerX = rect.midX

        path.move(to: CGPoint(x: centerX, y: rect.maxY))

        for i in 1...segments {
            let progress = CGFloat(i) / CGFloat(segments)
            let sway = sin(progress * .pi * 1.5) * swayAmount * progress
            let controlPoint = CGPoint(
                x: centerX + sway * 0.5,
                y: rect.maxY - segmentHeight * (CGFloat(i) - 0.5)
            )
            let endPoint = CGPoint(
                x: centerX + sway,
                y: rect.maxY - segmentHeight * CGFloat(i)
            )
            path.addQuadCurve(to: endPoint, control: controlPoint)
        }

        // Return path along the right side
        for i in stride(from: segments, through: 1, by: -1) {
            let progress = CGFloat(i) / CGFloat(segments)
            let sway = sin(progress * .pi * 1.5) * swayAmount * progress
            let prevProgress = CGFloat(i - 1) / CGFloat(segments)
            let prevSway = i > 1 ? sin(prevProgress * .pi * 1.5) * swayAmount * prevProgress : 0

            let controlPoint = CGPoint(
                x: centerX + sway + rect.width * 0.3,
                y: rect.maxY - segmentHeight * CGFloat(i) + segmentHeight * 0.5
            )
            let endPoint = CGPoint(
                x: centerX + prevSway + rect.width * 0.15,
                y: rect.maxY - segmentHeight * CGFloat(i - 1)
            )
            path.addQuadCurve(to: endPoint, control: controlPoint)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("With Fish") {
    AquariumView(viewModel: AppViewModel())
}
