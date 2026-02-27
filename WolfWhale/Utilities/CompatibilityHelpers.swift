import SwiftUI
import MapKit

// MARK: - Glass Effect Compatibility (iOS 26+)

extension View {
    /// Applies `.glassEffect(.regular, in: shape)` on iOS 26+, falls back to `.background(.ultraThinMaterial, in: shape)`.
    @ViewBuilder
    func compatGlassEffect(in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Applies `.glassEffect(in: shape)` (identity style) on iOS 26+, falls back to `.background(.ultraThinMaterial, in: shape)`.
    @ViewBuilder
    func compatGlassEffectIdentity(in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Applies `.glassEffect(.regular.tint(color), in: shape)` on iOS 26+, falls back to `.background(.ultraThinMaterial, in: shape)`.
    @ViewBuilder
    func compatGlassEffectTinted(_ tintColor: Color, in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(tintColor), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Applies `.glassEffect(.regular.tint(color).interactive(), in: shape)` on iOS 26+, falls back to `.background(.ultraThinMaterial, in: shape)`.
    @ViewBuilder
    func compatGlassEffectTintedInteractive(_ tintColor: Color, in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(tintColor).interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Applies conditional glass effect based on a Bool (e.g., message.isFromCurrentUser).
    /// When `condition` is true: tinted glass. When false: identity glass.
    @ViewBuilder
    func compatGlassEffectConditional(isActive: Bool, tintColor: Color, in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                isActive ? .regular.tint(tintColor) : .identity,
                in: shape
            )
        } else {
            if isActive {
                self.background(.ultraThinMaterial, in: shape)
            } else {
                self.background(Color(.secondarySystemGroupedBackground), in: shape)
            }
        }
    }
}

// MARK: - GlassEffectContainer Compatibility (iOS 26+)

/// On iOS 26+, wraps content in `GlassEffectContainer`. On older iOS, passes through content.
struct CompatGlassEffectContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - MeshGradient Compatibility (iOS 18+)

/// Returns a `MeshGradient` on iOS 18+ or a `LinearGradient` fallback.
struct CompatMeshGradient: View {
    let width: Int
    let height: Int
    let points: [SIMD2<Float>]
    let colors: [Color]

    var body: some View {
        if #available(iOS 18, *) {
            MeshGradient(width: width, height: height, points: points, colors: colors)
        } else {
            // Fallback: use the first and last colors as a linear gradient
            let fallbackColors = colors.isEmpty ? [.purple, .indigo] : [colors.first!, colors.last!]
            LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Symbol Effect Compatibility (iOS 18+ for .breathe)

extension View {
    /// Applies `.symbolEffect(.breathe, ...)` on iOS 18+, falls back to `.symbolEffect(.pulse, ...)` on iOS 17.
    @ViewBuilder
    func compatBreatheEffect(options: some Any = 0, isActive: Bool = true) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe)
        } else {
            self.symbolEffect(.pulse)
        }
    }

    /// Applies `.symbolEffect(.breathe.pulse, ...)` on iOS 18+, falls back to `.symbolEffect(.pulse, ...)` on iOS 17.
    @ViewBuilder
    func compatBreathePulseEffect() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.pulse)
        } else {
            self.symbolEffect(.pulse)
        }
    }

    /// Applies `.symbolEffect(.breathe, options: .repeating)` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatBreatheRepeating() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe, options: .repeating)
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.breathe, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatBreathePeriodic(delay: Double) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe, options: .repeat(.periodic(delay: delay)))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.breathe.pulse, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatBreathePulsePeriodic(delay: Double) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.pulse, options: .repeat(.periodic(delay: delay)))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.breathe.pulse, options: .repeat(.continuous))` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatBreathePulseContinuous() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.pulse, options: .repeat(.continuous))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    // MARK: - Non-breathe periodic/continuous helpers

    /// Applies `.symbolEffect(.pulse, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatBouncePeriodic(delay: Double) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.pulse, options: .repeat(.periodic(delay: delay)))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.pulse, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating)`.
    @ViewBuilder
    func compatPulsePeriodic(delay: Double) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.pulse, options: .repeat(.periodic(delay: delay)))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back to `.symbolEffect(.variableColor.iterative, options: .repeating)`.
    @ViewBuilder
    func compatVariableColorPeriodic(delay: Double) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: delay)))
        } else {
            self.symbolEffect(.variableColor.iterative, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.variableColor.iterative, options: .repeat(.continuous))` on iOS 18+, falls back to `.symbolEffect(.variableColor.iterative, options: .repeating)`.
    @ViewBuilder
    func compatVariableColorContinuous() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
        } else {
            self.symbolEffect(.variableColor.iterative, options: .repeating)
        }
    }

    /// Applies `.symbolEffect(.pulse, options: .repeat(.periodic(delay:)), isActive:)` on iOS 18+, falls back to `.symbolEffect(.pulse, options: .repeating, isActive:)`.
    @ViewBuilder
    func compatBouncePeriodicActive(delay: Double, isActive: Bool) -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.pulse, options: .repeat(.periodic(delay: delay)), isActive: isActive)
        } else {
            self.symbolEffect(.pulse, options: .repeating, isActive: isActive)
        }
    }

    /// Applies `.symbolEffect(.pulse, options: .repeat(.periodic(delay:)))` on iOS 18+, falls back.
    @ViewBuilder
    func compatPulseContinuous() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.pulse, options: .repeat(.continuous))
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }
}

// MARK: - RealityKit Cylinder Compatibility (iOS 18+)

import RealityKit

extension MeshResource {
    /// Generates a cylinder mesh on iOS 18+, falls back to a box approximation on iOS 17.
    static func compatGenerateCylinder(height: Float, radius: Float) -> MeshResource {
        if #available(iOS 18, *) {
            return .generateCylinder(height: height, radius: radius)
        } else {
            // Approximate cylinder with a box of similar dimensions
            return .generateBox(width: radius * 2, height: height, depth: radius * 2, cornerRadius: radius * 0.8)
        }
    }
}

// MARK: - MKMapItem Compatibility

extension MKMapItem {
    /// Creates an `MKMapItem` from a coordinate, compatible with all iOS versions.
    static func compatItem(coordinate: CLLocationCoordinate2D) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }
}
