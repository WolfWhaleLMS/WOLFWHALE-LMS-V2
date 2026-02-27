import SwiftUI

/// A plain system background that adapts to light and dark mode.
/// Used as the standard background across all views.
///
/// Usage:
///   .background { HolographicBackground() }
struct HolographicBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

/// A static version using the same plain background.
/// Identical to HolographicBackground but kept for API compatibility.
struct HolographicBackgroundStatic: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color(.systemGroupedBackground)
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
            .compatGlassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
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
            .compatGlassEffectTinted(tint.opacity(tintOpacity), in: RoundedRectangle(cornerRadius: cornerRadius))
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
