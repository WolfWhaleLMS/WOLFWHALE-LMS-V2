import SwiftUI

// MARK: - Main Background

/// A dark sky with twinkling stars, wavy northern lights, and
/// an evergreen tree skyline silhouette. Used on the sign-in screen.
struct AuroraNightSkyBackground: View {
    var body: some View {
        ZStack {
            // Deep night sky gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.04, green: 0.05, blue: 0.15),
                    Color(red: 0.06, green: 0.08, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Stars
            TwinklingStarsView()

            // Northern lights
            AuroraView()

            // Evergreen tree skyline
            EvergreenSkylineView()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Twinkling Stars

private struct Star: Identifiable {
    let id: Int
    let x: CGFloat      // 0...1
    let y: CGFloat      // 0...1
    let size: CGFloat    // point size
    let brightness: CGFloat
    let twinkleSpeed: Double
    let twinkleDelay: Double
}

private struct TwinklingStarsView: View {
    let stars: [Star]

    init(count: Int = 120) {
        var rng = SeededRNG(seed: 42)
        stars = (0..<count).map { i in
            Star(
                id: i,
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...0.75, using: &rng),
                size: CGFloat.random(in: 1.0...3.0, using: &rng),
                brightness: CGFloat.random(in: 0.4...1.0, using: &rng),
                twinkleSpeed: Double.random(in: 1.0...3.5, using: &rng),
                twinkleDelay: Double.random(in: 0...3.0, using: &rng)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { star in
                TwinklingStar(star: star)
                    .position(
                        x: star.x * geo.size.width,
                        y: star.y * geo.size.height
                    )
            }
        }
        .ignoresSafeArea()
    }
}

private struct TwinklingStar: View {
    let star: Star
    @State private var isTwinkling = false

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: star.size, height: star.size)
            .opacity(isTwinkling ? star.brightness : star.brightness * 0.3)
            .blur(radius: star.size > 2 ? 0.5 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: star.twinkleSpeed)
                    .repeatForever(autoreverses: true)
                    .delay(star.twinkleDelay)
                ) {
                    isTwinkling = true
                }
            }
    }
}

// MARK: - Aurora / Northern Lights

private struct AuroraView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Draw 4 aurora bands with different colors, heights, and speeds
                drawAuroraBand(
                    context: context, size: size, time: time,
                    baseY: 0.20, amplitude: 40, wavelength: 1.2, speed: 0.15,
                    colors: [
                        Color(red: 0.1, green: 0.8, blue: 0.4).opacity(0.0),
                        Color(red: 0.1, green: 0.8, blue: 0.4).opacity(0.18),
                        Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.12),
                        Color(red: 0.1, green: 0.8, blue: 0.4).opacity(0.0),
                    ],
                    height: 120
                )

                drawAuroraBand(
                    context: context, size: size, time: time,
                    baseY: 0.28, amplitude: 55, wavelength: 0.9, speed: -0.12,
                    colors: [
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.0),
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.15),
                        Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.12),
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.0),
                    ],
                    height: 100
                )

                drawAuroraBand(
                    context: context, size: size, time: time,
                    baseY: 0.22, amplitude: 35, wavelength: 1.5, speed: 0.08,
                    colors: [
                        Color(red: 0.6, green: 0.2, blue: 0.7).opacity(0.0),
                        Color(red: 0.6, green: 0.2, blue: 0.7).opacity(0.12),
                        Color(red: 0.8, green: 0.3, blue: 0.6).opacity(0.08),
                        Color(red: 0.6, green: 0.2, blue: 0.7).opacity(0.0),
                    ],
                    height: 90
                )

                drawAuroraBand(
                    context: context, size: size, time: time,
                    baseY: 0.15, amplitude: 25, wavelength: 2.0, speed: 0.18,
                    colors: [
                        Color(red: 0.1, green: 0.9, blue: 0.7).opacity(0.0),
                        Color(red: 0.1, green: 0.9, blue: 0.7).opacity(0.10),
                        Color(red: 0.1, green: 0.7, blue: 0.5).opacity(0.06),
                        Color(red: 0.1, green: 0.9, blue: 0.7).opacity(0.0),
                    ],
                    height: 80
                )
            }
        }
        .ignoresSafeArea()
        .blendMode(.screen)
    }

    private func drawAuroraBand(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        baseY: CGFloat,
        amplitude: CGFloat,
        wavelength: CGFloat,
        speed: CGFloat,
        colors: [Color],
        height: CGFloat
    ) {
        let steps = Int(size.width / 3)
        let phase = time * Double(speed)

        // Build the wavy top edge
        var topPath = Path()
        for i in 0...steps {
            let x = CGFloat(i) / CGFloat(steps) * size.width
            let normalizedX = x / size.width
            let y = size.height * baseY
                + sin(normalizedX * .pi * 2 * wavelength + phase) * amplitude
                + sin(normalizedX * .pi * 3 * wavelength * 0.7 + phase * 1.3) * amplitude * 0.4
                + cos(normalizedX * .pi * 1.5 * wavelength + phase * 0.8) * amplitude * 0.3

            if i == 0 {
                topPath.move(to: CGPoint(x: x, y: y))
            } else {
                topPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close the shape downward to form a filled band
        let bottomY = size.height * baseY + height
        topPath.addLine(to: CGPoint(x: size.width, y: bottomY))
        topPath.addLine(to: CGPoint(x: 0, y: bottomY))
        topPath.closeSubpath()

        // Fill with vertical gradient
        let gradient = Gradient(colors: colors)
        let startPt = CGPoint(x: size.width / 2, y: size.height * baseY - amplitude)
        let endPt = CGPoint(x: size.width / 2, y: bottomY)

        context.fill(
            topPath,
            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt)
        )
    }
}

// MARK: - Evergreen Tree Skyline

private struct EvergreenSkylineView: View {
    var body: some View {
        GeometryReader { geo in
            EvergreenSkylineShape()
                .fill(Color(red: 0.01, green: 0.02, blue: 0.04))
                .frame(width: geo.size.width, height: geo.size.height * 0.28)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
}

private struct EvergreenSkylineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Seeded random tree generation for consistent layout
        var rng = SeededRNG(seed: 77)
        let treeCount = 30

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: h))

        // Small rolling hills as a base
        let hillY = h * 0.55

        for i in 0...treeCount {
            let fraction = CGFloat(i) / CGFloat(treeCount)
            let x = fraction * w

            // Vary the tree height — some are huge, some medium
            let maxTreeH = CGFloat.random(in: 0.50...0.95, using: &rng)
            let treeWidth = CGFloat.random(in: 0.025...0.05, using: &rng) * w
            let treeTop = h - h * maxTreeH
            let treeBase = hillY + CGFloat.random(in: -10...10, using: &rng)

            // Left side of tree (jagged evergreen layers)
            let leftX = x - treeWidth / 2
            let rightX = x + treeWidth / 2
            let layers = Int.random(in: 4...7, using: &rng)

            // Move to tree base left
            path.addLine(to: CGPoint(x: leftX, y: treeBase))

            // Build tree upward with staggered branches
            for layer in 0..<layers {
                let layerFraction = CGFloat(layer) / CGFloat(layers)
                let layerY = treeBase - (treeBase - treeTop) * layerFraction
                let spread = treeWidth * (1.0 - layerFraction * 0.6)

                // Branch out left
                path.addLine(to: CGPoint(x: x - spread * 0.6, y: layerY))
                // In to trunk
                path.addLine(to: CGPoint(x: x - spread * 0.15, y: layerY - (treeBase - treeTop) / CGFloat(layers) * 0.3))
            }

            // Peak
            path.addLine(to: CGPoint(x: x, y: treeTop))

            // Mirror down the right side
            for layer in stride(from: layers - 1, through: 0, by: -1) {
                let layerFraction = CGFloat(layer) / CGFloat(layers)
                let layerY = treeBase - (treeBase - treeTop) * layerFraction
                let spread = treeWidth * (1.0 - layerFraction * 0.6)

                path.addLine(to: CGPoint(x: x + spread * 0.15, y: layerY - (treeBase - treeTop) / CGFloat(layers) * 0.3))
                path.addLine(to: CGPoint(x: x + spread * 0.6, y: layerY))
            }

            // Back to base right
            path.addLine(to: CGPoint(x: rightX, y: treeBase))
        }

        // Close along the bottom
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Seeded RNG (deterministic star/tree placement)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
