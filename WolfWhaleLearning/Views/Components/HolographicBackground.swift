import SwiftUI

/// A full-bleed background using the Frutiger Aero landscape image.
/// Adapts to light and dark mode with a subtle dark overlay for readability.
///
/// Usage:
///   .background { HolographicBackground() }
struct HolographicBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Image("AppBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Dark mode overlay for readability
            if colorScheme == .dark {
                Color.black.opacity(0.45)
            }
        }
        .ignoresSafeArea()
    }
}

/// A static version that uses the same Frutiger Aero background image.
/// Identical to HolographicBackground but kept for API compatibility.
struct HolographicBackgroundStatic: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Image("AppBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)

            if colorScheme == .dark {
                Color.black.opacity(0.45)
            }
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
