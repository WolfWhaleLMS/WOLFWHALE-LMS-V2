import SwiftUI

/// A reusable card component for the Learning Tools grid.
/// Displays an SF Symbol icon inside a tinted circle, a title, and a brief subtitle,
/// styled with the app's indigo/purple glass-material theme.
struct ToolCard: View, Equatable {
    let title: String
    let subtitle: String
    let icon: String
    let gradientColors: [Color]

    static func == (lhs: ToolCard, rhs: ToolCard) -> Bool {
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.icon == rhs.icon &&
        lhs.gradientColors == rhs.gradientColors
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
        ToolCard(
            title: "Flashcards",
            subtitle: "Create & study",
            icon: "rectangle.on.rectangle.angled",
            gradientColors: [.indigo, .purple]
        )
        ToolCard(
            title: "Math Quiz",
            subtitle: "Test your skills",
            icon: "function",
            gradientColors: [.green, .mint]
        )
    }
    .padding()
}
