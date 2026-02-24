import SwiftUI

// MARK: - Underwater Background

/// A full-screen animated underwater scene with bubbles, sun rays, caustic light beams, and fish.
struct UnderwaterBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Deep ocean gradient
                let gradient = Gradient(colors: [
                    Color(red: 0.0, green: 0.05, blue: 0.15),
                    Color(red: 0.0, green: 0.08, blue: 0.25),
                    Color(red: 0.0, green: 0.12, blue: 0.35),
                    Color(red: 0.0, green: 0.18, blue: 0.45),
                    Color(red: 0.05, green: 0.25, blue: 0.55),
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(gradient, startPoint: CGPoint(x: size.width / 2, y: 0), endPoint: CGPoint(x: size.width / 2, y: size.height))
                )

                // Sun rays from top center
                drawSunRays(context: context, size: size, time: t)

                // Caustic light patterns
                drawCaustics(context: context, size: size, time: t)
            }
            .overlay {
                // Bubbles layer
                BubblesView(time: t)
            }
            .overlay {
                // Fish layer
                FishSwimmingView(time: t)
            }
        }
        .ignoresSafeArea()
    }

    private func drawSunRays(context: GraphicsContext, size: CGSize, time: Double) {
        let centerX = size.width * 0.5
        let centerY: CGFloat = -20
        let rayCount = 12
        let maxLength = size.height * 1.4

        for i in 0..<rayCount {
            let baseAngle = Double(i) * (.pi / Double(rayCount)) + .pi * 0.15
            let sway = sin(time * 0.3 + Double(i) * 0.7) * 0.04
            let angle = baseAngle + sway

            let spreadAngle = 0.025 + sin(time * 0.2 + Double(i)) * 0.008
            let leftX = centerX + cos(angle - spreadAngle) * maxLength
            let leftY = centerY + sin(angle - spreadAngle) * maxLength
            let rightX = centerX + cos(angle + spreadAngle) * maxLength
            let rightY = centerY + sin(angle + spreadAngle) * maxLength

            var path = Path()
            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addLine(to: CGPoint(x: leftX, y: leftY))
            path.addLine(to: CGPoint(x: rightX, y: rightY))
            path.closeSubpath()

            let opacity = 0.04 + sin(time * 0.5 + Double(i) * 1.2) * 0.02
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }

    private func drawCaustics(context: GraphicsContext, size: CGSize, time: Double) {
        // Shimmering caustic light patches
        for i in 0..<8 {
            let seed = Double(i) * 3.7
            let x = size.width * (0.1 + 0.8 * ((sin(seed + time * 0.15) + 1) / 2))
            let y = size.height * (0.15 + 0.5 * ((cos(seed * 1.3 + time * 0.1) + 1) / 2))
            let radius = 40.0 + sin(time * 0.4 + seed) * 20.0
            let opacity = 0.03 + sin(time * 0.6 + seed * 2) * 0.015

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(opacity))
            )
        }
    }
}

// MARK: - Bubbles View

private struct BubblesView: View {
    let time: Double

    private struct Bubble: Identifiable {
        let id: Int
        let xOffset: Double   // 0-1 horizontal position
        let speed: Double      // rise speed multiplier
        let size: CGFloat      // diameter
        let wobblePhase: Double
    }

    private let bubbles: [Bubble] = (0..<25).map { i in
        let seed = Double(i) * 2.3
        return Bubble(
            id: i,
            xOffset: (sin(seed * 1.7) + 1) / 2,
            speed: 0.03 + (sin(seed * 0.9) + 1) / 2 * 0.04,
            size: CGFloat(4 + (sin(seed * 2.1) + 1) / 2 * 14),
            wobblePhase: seed
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(bubbles) { bubble in
                let cycleTime = time * bubble.speed
                let yProgress = 1.0 - (cycleTime.truncatingRemainder(dividingBy: 1.0))
                let wobble = sin(time * 1.5 + bubble.wobblePhase) * 12

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.3),
                                Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.15),
                                .clear
                            ],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: bubble.size * 0.6
                        )
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .frame(width: bubble.size, height: bubble.size)
                    .position(
                        x: geometry.size.width * bubble.xOffset + wobble,
                        y: geometry.size.height * yProgress
                    )
                    .opacity(yProgress > 0.05 && yProgress < 0.95 ? 0.8 : 0.0)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Fish Swimming View

private struct FishSwimmingView: View {
    let time: Double

    private struct Fish: Identifiable {
        let id: Int
        let yPosition: Double
        let speed: Double
        let size: CGFloat
        let colorIndex: Int
        let goesRight: Bool
        let verticalWobble: Double
    }

    private static let fishData: [Fish] = (0..<8).map { i in
        let seed = Double(i) * 3.1
        return Fish(
            id: i,
            yPosition: 0.25 + (sin(seed * 1.3) + 1) / 2 * 0.55,
            speed: 0.015 + (sin(seed * 0.7) + 1) / 2 * 0.025,
            size: CGFloat(16 + (sin(seed * 2.5) + 1) / 2 * 16),
            colorIndex: i % 8,
            goesRight: i % 2 == 0,
            verticalWobble: seed
        )
    }

    private func fishColor(index: Int) -> (Color, Color) {
        switch index {
        case 0: return (.orange, .yellow)
        case 1: return (.cyan, .blue)
        case 2: return (.orange, .red)
        case 3: return (.yellow, .orange)
        case 4: return (.mint, .teal)
        case 5: return (.purple, .indigo)
        case 6: return (Color(red: 1, green: 0.6, blue: 0), Color(red: 1, green: 0.3, blue: 0))
        default: return (.blue, .cyan)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(Self.fishData) { f in
                let cycleTime = time * f.speed
                let xProgress: Double = f.goesRight
                    ? cycleTime.truncatingRemainder(dividingBy: 1.0)
                    : 1.0 - cycleTime.truncatingRemainder(dividingBy: 1.0)
                let yWobble = sin(time * 0.8 + f.verticalWobble) * 15
                let colors = fishColor(index: f.colorIndex)

                Image(systemName: "fish.fill")
                    .font(.system(size: f.size))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colors.0, colors.1],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: f.goesRight ? 1 : -1, y: 1)
                    .shadow(color: colors.0.opacity(0.4), radius: 6)
                    .position(
                        x: -30 + (geometry.size.width + 60) * xProgress,
                        y: geometry.size.height * f.yPosition + yWobble
                    )
                    .opacity(0.85)
            }
        }
        .allowsHitTesting(false)
    }
}
