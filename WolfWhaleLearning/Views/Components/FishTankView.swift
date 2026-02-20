import SwiftUI

struct FishTankView: View {
    @State private var animating = false
    @State private var wavePhase: CGFloat = 0
    @State private var seaweedPhase: CGFloat = 0

    // MARK: - Fish Data

    struct Fish: Identifiable {
        let id = UUID()
        let color: Color
        let size: CGFloat
        let yPosition: CGFloat
        let speed: Double
        let delay: Double
    }

    private let fish: [Fish] = [
        Fish(color: .orange, size: 24, yPosition: 0.28, speed: 4.0, delay: 0),
        Fish(color: .yellow, size: 18, yPosition: 0.48, speed: 5.5, delay: 0.5),
        Fish(color: .red, size: 22, yPosition: 0.62, speed: 3.5, delay: 1.0),
        Fish(color: .cyan, size: 20, yPosition: 0.38, speed: 6.0, delay: 1.5),
        Fish(color: .green, size: 16, yPosition: 0.72, speed: 4.5, delay: 0.8),
        Fish(color: .pink, size: 19, yPosition: 0.55, speed: 5.0, delay: 2.0),
    ]

    // MARK: - Bubble Data

    struct Bubble: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let size: CGFloat
        let duration: Double
        let delay: Double
    }

    private let bubbles: [Bubble] = [
        Bubble(xFraction: 0.15, size: 6, duration: 3.5, delay: 0),
        Bubble(xFraction: 0.35, size: 4, duration: 4.0, delay: 0.8),
        Bubble(xFraction: 0.55, size: 5, duration: 3.0, delay: 1.6),
        Bubble(xFraction: 0.72, size: 7, duration: 4.5, delay: 0.4),
        Bubble(xFraction: 0.88, size: 3, duration: 3.8, delay: 2.0),
        Bubble(xFraction: 0.25, size: 5, duration: 4.2, delay: 1.2),
        Bubble(xFraction: 0.65, size: 4, duration: 3.2, delay: 2.5),
        Bubble(xFraction: 0.45, size: 6, duration: 3.6, delay: 0.6),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Campus Aquarium")
                .font(.headline)

            ZStack {
                waterBackground
                sandyBottom
                pebblesView
                seaweedView
                bubblesView

                ForEach(fish) { fish in
                    AnimatedFishView(fish: fish, animating: animating)
                }

                glassReflection
                waveOverlay
            }
            .frame(height: 180)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .blue.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .blue.opacity(0.2), radius: 10, y: 5)
        }
        .onAppear {
            animating = true
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                seaweedPhase = 1
            }
        }
    }

    // MARK: - Water Background

    private var waterBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.82, blue: 0.95),
                Color(red: 0.2, green: 0.5, blue: 0.78),
                Color(red: 0.12, green: 0.35, blue: 0.65),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Wave Overlay

    private var waveOverlay: some View {
        GeometryReader { geo in
            WaveShape(phase: wavePhase, amplitude: 4, frequency: 2)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Sandy Bottom

    private var sandyBottom: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.72, blue: 0.55),
                    Color(red: 0.72, green: 0.6, blue: 0.42),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 22)
            .overlay(alignment: .top) {
                // Sand texture dots
                HStack(spacing: 12) {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(Color(red: 0.75, green: 0.65, blue: 0.48).opacity(0.5))
                            .frame(width: CGFloat.random(in: 2...4), height: CGFloat.random(in: 2...4))
                            .offset(y: CGFloat.random(in: 2...6))
                    }
                }
            }
        }
    }

    // MARK: - Pebbles

    private var pebblesView: some View {
        GeometryReader { geo in
            ZStack {
                pebble(color: Color(red: 0.55, green: 0.55, blue: 0.52), size: 8)
                    .position(x: geo.size.width * 0.2, y: geo.size.height - 18)

                pebble(color: Color(red: 0.65, green: 0.58, blue: 0.5), size: 6)
                    .position(x: geo.size.width * 0.35, y: geo.size.height - 16)

                pebble(color: Color(red: 0.5, green: 0.5, blue: 0.48), size: 10)
                    .position(x: geo.size.width * 0.7, y: geo.size.height - 19)

                pebble(color: Color(red: 0.6, green: 0.55, blue: 0.45), size: 7)
                    .position(x: geo.size.width * 0.85, y: geo.size.height - 15)

                pebble(color: Color(red: 0.48, green: 0.48, blue: 0.46), size: 5)
                    .position(x: geo.size.width * 0.52, y: geo.size.height - 17)
            }
        }
    }

    private func pebble(color: Color, size: CGFloat) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: size, height: size * 0.65)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }

    // MARK: - Seaweed

    private var seaweedView: some View {
        GeometryReader { geo in
            ZStack {
                SeaweedShape(swayAmount: seaweedPhase * 8, segments: 6)
                    .fill(Color(red: 0.18, green: 0.6, blue: 0.25).opacity(0.8))
                    .frame(width: 14, height: 50)
                    .position(x: geo.size.width * 0.15, y: geo.size.height - 44)

                SeaweedShape(swayAmount: seaweedPhase * 6, segments: 5)
                    .fill(Color(red: 0.22, green: 0.7, blue: 0.3).opacity(0.7))
                    .frame(width: 12, height: 40)
                    .position(x: geo.size.width * 0.82, y: geo.size.height - 39)

                SeaweedShape(swayAmount: seaweedPhase * 10, segments: 7)
                    .fill(Color(red: 0.15, green: 0.55, blue: 0.22).opacity(0.75))
                    .frame(width: 10, height: 55)
                    .position(x: geo.size.width * 0.6, y: geo.size.height - 47)
            }
        }
    }

    // MARK: - Bubbles

    private var bubblesView: some View {
        GeometryReader { geo in
            ForEach(bubbles) { bubble in
                BubbleView(
                    bubble: bubble,
                    tankHeight: geo.size.height,
                    animating: animating
                )
                .position(x: geo.size.width * bubble.xFraction, y: geo.size.height)
            }
        }
    }

    // MARK: - Glass Reflection

    private var glassReflection: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width * 0.08, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.5))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.08))

            Path { path in
                path.move(to: CGPoint(x: geo.size.width * 0.12, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width * 0.16, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.7))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height * 0.55))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.05))
        }
    }
}

// MARK: - Animated Fish View

/// Each fish manages its own repeating animation independently.
private struct AnimatedFishView: View {
    let fish: FishTankView.Fish
    let animating: Bool

    @State private var atEnd = false
    @State private var bobOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let padding = fish.size + 10
            let startX = -padding
            let endX = geo.size.width + padding
            let yPos = geo.size.height * fish.yPosition

            Image(systemName: "fish.fill")
                .font(.system(size: fish.size))
                .foregroundStyle(fish.color.gradient)
                .shadow(color: fish.color.opacity(0.4), radius: 3, y: 1)
                .scaleEffect(x: atEnd ? 1 : -1, y: 1)
                .offset(
                    x: atEnd ? endX : startX,
                    y: yPos + bobOffset
                )
                .onAppear {
                    // Bobbing animation
                    withAnimation(
                        .easeInOut(duration: 1.2 + fish.speed * 0.1)
                            .repeatForever(autoreverses: true)
                            .delay(fish.delay)
                    ) {
                        bobOffset = CGFloat.random(in: 6...12)
                    }

                    // Swimming animation
                    startSwimming()
                }
        }
    }

    private func startSwimming() {
        // Initial delay before first swim
        DispatchQueue.main.asyncAfter(deadline: .now() + fish.delay) {
            swim()
        }
    }

    private func swim() {
        withAnimation(.linear(duration: fish.speed)) {
            atEnd.toggle()
        } completion: {
            swim()
        }
    }
}

// MARK: - Bubble View

private struct BubbleView: View {
    let bubble: FishTankView.Bubble
    let tankHeight: CGFloat
    let animating: Bool

    @State private var yOffset: CGFloat = 0
    @State private var opacity: CGFloat = 0

    var body: some View {
        Circle()
            .fill(.white.opacity(opacity))
            .frame(width: bubble.size, height: bubble.size)
            .overlay(
                Circle()
                    .stroke(.white.opacity(opacity * 0.5), lineWidth: 0.5)
            )
            .offset(y: yOffset)
            .onAppear {
                guard animating else { return }
                startBubbleAnimation()
            }
    }

    private func startBubbleAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + bubble.delay) {
            animateBubble()
        }
    }

    private func animateBubble() {
        // Reset to bottom
        yOffset = 0
        opacity = 0

        // Fade in quickly
        withAnimation(.easeIn(duration: 0.3)) {
            opacity = 0.55
        }

        // Float upward
        withAnimation(.easeOut(duration: bubble.duration)) {
            yOffset = -(tankHeight * 0.85)
        }

        // Fade out near the top
        withAnimation(.easeIn(duration: 0.6).delay(bubble.duration * 0.65)) {
            opacity = 0
        }

        // Restart after completing
        DispatchQueue.main.asyncAfter(deadline: .now() + bubble.duration + 0.2) {
            animateBubble()
        }
    }
}

// MARK: - Wave Shape

private struct WaveShape: Shape {
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

// MARK: - Seaweed Shape

private struct SeaweedShape: Shape {
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
            let y = rect.maxY - (segmentHeight * CGFloat(i))
            let progress = CGFloat(i) / CGFloat(segments)
            let sway = sin(progress * .pi * 1.5) * swayAmount * progress
            let cp1 = CGPoint(
                x: centerX + sway * 0.5,
                y: rect.maxY - segmentHeight * (CGFloat(i) - 0.5)
            )
            let end = CGPoint(x: centerX + sway, y: y)
            path.addQuadCurve(to: end, control: cp1)
        }

        // Draw the other side going back down
        for i in stride(from: segments, through: 1, by: -1) {
            let y = rect.maxY - (segmentHeight * CGFloat(i))
            let progress = CGFloat(i) / CGFloat(segments)
            let sway = sin(progress * .pi * 1.5) * swayAmount * progress
            let cp1 = CGPoint(
                x: centerX + sway + rect.width * 0.3,
                y: y + segmentHeight * 0.5
            )
            let end = CGPoint(
                x: centerX + (i > 1 ? sin(CGFloat(i - 1) / CGFloat(segments) * .pi * 1.5) * swayAmount * CGFloat(i - 1) / CGFloat(segments) : 0) + rect.width * 0.15,
                y: rect.maxY - segmentHeight * CGFloat(i - 1)
            )
            path.addQuadCurve(to: end, control: cp1)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    FishTankView()
        .padding()
}
