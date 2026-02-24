import SwiftUI

/// A full-bleed background using the Frutiger Aero landscape image.
/// Adapts to light and dark mode with a subtle dark overlay for readability.
///
/// Usage:
///   .background { HolographicBackground() }
struct HolographicBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Seamless gradient that extends the image's sky and grass
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.55, blue: 0.88),
                        Color(red: 0.30, green: 0.65, blue: 0.95),
                        Color(red: 0.35, green: 0.75, blue: 0.35),
                        Color(red: 0.28, green: 0.62, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Image fitted to show the full scene
                Image("AppBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)

                // Dark mode overlay for readability
                if colorScheme == .dark {
                    Color.black.opacity(0.45)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

/// A static version that uses the same Frutiger Aero background image.
/// Identical to HolographicBackground but kept for API compatibility.
struct HolographicBackgroundStatic: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.55, blue: 0.88),
                        Color(red: 0.30, green: 0.65, blue: 0.95),
                        Color(red: 0.35, green: 0.75, blue: 0.35),
                        Color(red: 0.28, green: 0.62, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image("AppBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)

                if colorScheme == .dark {
                    Color.black.opacity(0.45)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
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
