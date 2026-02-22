import SwiftUI

/// A full-bleed holographic/chrome background that mimics liquid metal
/// with rainbow refractions. Uses MeshGradient for resolution-independent
/// rendering across all devices.
///
/// Usage:
///   .background { HolographicBackground() }
struct HolographicBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let slow = t * 0.08 // very slow drift

            MeshGradient(
                width: 4, height: 4,
                points: [
                    // Row 0
                    [0.0, 0.0],
                    [Float(0.33 + 0.02 * sin(slow)), 0.0],
                    [Float(0.67 + 0.02 * cos(slow * 1.1)), 0.0],
                    [1.0, 0.0],
                    // Row 1
                    [0.0, Float(0.33 + 0.015 * sin(slow * 0.9))],
                    [Float(0.33 + 0.03 * cos(slow * 0.7)), Float(0.33 + 0.02 * sin(slow * 1.2))],
                    [Float(0.67 + 0.02 * sin(slow * 0.8)), Float(0.33 + 0.02 * cos(slow))],
                    [1.0, Float(0.33 + 0.015 * cos(slow * 1.1))],
                    // Row 2
                    [0.0, Float(0.67 + 0.015 * cos(slow * 1.1))],
                    [Float(0.33 + 0.02 * sin(slow * 1.3)), Float(0.67 + 0.02 * cos(slow * 0.9))],
                    [Float(0.67 + 0.03 * cos(slow * 0.6)), Float(0.67 + 0.02 * sin(slow * 1.1))],
                    [1.0, Float(0.67 + 0.015 * sin(slow * 0.8))],
                    // Row 3
                    [0.0, 1.0],
                    [Float(0.33 + 0.02 * cos(slow * 1.2)), 1.0],
                    [Float(0.67 + 0.02 * sin(slow * 0.9)), 1.0],
                    [1.0, 1.0]
                ],
                colors: [
                    // Row 0 — top edge
                    Color(red: 0.78, green: 0.80, blue: 0.85), // silver
                    Color(red: 0.60, green: 0.70, blue: 0.92), // light blue
                    Color(red: 0.55, green: 0.82, blue: 0.72), // seafoam green
                    Color(red: 0.75, green: 0.78, blue: 0.84), // silver

                    // Row 1 — upper mid
                    Color(red: 0.65, green: 0.62, blue: 0.88), // lavender
                    Color(red: 0.45, green: 0.60, blue: 0.95), // bright blue
                    Color(red: 0.35, green: 0.85, blue: 0.55), // vivid green
                    Color(red: 0.80, green: 0.75, blue: 0.82), // pale purple

                    // Row 2 — lower mid
                    Color(red: 0.72, green: 0.68, blue: 0.80), // dusty mauve
                    Color(red: 0.40, green: 0.72, blue: 0.88), // ocean blue
                    Color(red: 0.50, green: 0.78, blue: 0.65), // jade
                    Color(red: 0.82, green: 0.70, blue: 0.60), // warm chrome

                    // Row 3 — bottom edge
                    Color(red: 0.76, green: 0.76, blue: 0.82), // cool silver
                    Color(red: 0.58, green: 0.65, blue: 0.90), // periwinkle
                    Color(red: 0.48, green: 0.80, blue: 0.70), // mint
                    Color(red: 0.80, green: 0.78, blue: 0.82)  // silver
                ]
            )
            .ignoresSafeArea()
        }
    }
}

/// A static (non-animated) version for places where animation would be
/// distracting or when lower power usage is preferred.
struct HolographicBackgroundStatic: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                Color(red: 0.78, green: 0.80, blue: 0.85),
                Color(red: 0.55, green: 0.68, blue: 0.92),
                Color(red: 0.50, green: 0.82, blue: 0.68),

                Color(red: 0.62, green: 0.60, blue: 0.88),
                Color(red: 0.45, green: 0.72, blue: 0.90),
                Color(red: 0.42, green: 0.80, blue: 0.60),

                Color(red: 0.75, green: 0.72, blue: 0.82),
                Color(red: 0.55, green: 0.65, blue: 0.88),
                Color(red: 0.48, green: 0.78, blue: 0.72)
            ]
        )
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card Modifier

/// Applies a frosted glass card style: `.regularMaterial` background with
/// `.glassEffect(.regular)` for the full Apple glass UI look on iOS 26+.
/// Provides excellent contrast on vibrant/holographic backgrounds.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// A tinted glass card variant that adds a subtle color wash.
struct TintedGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var tint: Color = .clear
    var tintOpacity: Double = 0.1

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .glassEffect(.regular.tint(tint.opacity(tintOpacity)), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    /// Applies frosted glass card styling with `.regularMaterial` + `.glassEffect`.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    /// Applies tinted frosted glass card styling.
    func tintedGlassCard(cornerRadius: CGFloat = 16, tint: Color, opacity: Double = 0.1) -> some View {
        modifier(TintedGlassCard(cornerRadius: cornerRadius, tint: tint, tintOpacity: opacity))
    }
}
