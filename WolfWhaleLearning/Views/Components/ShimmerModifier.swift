import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    var duration: Double = 1.4
    var bounce: Bool = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(shimmerOverlay)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: bounce)
                ) {
                    phase = 2
                }
            }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.3), location: 0.3),
                    .init(color: .white.opacity(0.5), location: 0.5),
                    .init(color: .white.opacity(0.3), location: 0.7),
                    .init(color: .clear, location: 1.0),
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.7)
            .offset(x: width * phase)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - View Extension

extension View {
    /// Applies a shimmer/skeleton loading effect to the view.
    /// The content is redacted and an animated gradient slides across it.
    func shimmer(duration: Double = 1.4, bounce: Bool = false) -> some View {
        modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}

// MARK: - Preview

#Preview("Shimmer Effect") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            Circle()
                .fill(.secondary.opacity(0.15))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.1))
                    .frame(height: 10)
                    .frame(maxWidth: 180)
            }
        }
        .padding(14)
        .shimmer()

        RoundedRectangle(cornerRadius: 16)
            .fill(.secondary.opacity(0.1))
            .frame(height: 120)
            .shimmer()
    }
    .padding()
}
