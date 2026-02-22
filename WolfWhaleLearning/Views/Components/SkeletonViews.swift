import SwiftUI

// MARK: - Skeleton Card

/// A rounded rectangle card placeholder with shimmer, suitable for course cards or content cards.
struct SkeletonCard: View {
    var height: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [.indigo.opacity(0.08), .purple.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: height * 0.55)

            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.12))
                .frame(height: 14)
                .frame(maxWidth: .infinity)

            // Subtitle placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.08))
                .frame(height: 10)
                .frame(maxWidth: 140)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: height)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton List Row

/// A list row placeholder with a circular icon and two text lines, matching common list item layouts.
struct SkeletonListRow: View {
    var iconSize: CGFloat = 44
    var showTrailingChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.indigo.opacity(0.1), .purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: iconSize, height: iconSize)

            // Text lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.12))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 10)
                    .frame(maxWidth: 180)
            }

            if showTrailingChevron {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.08))
                    .frame(width: 8, height: 14)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton Dashboard Card

/// A dashboard-style card skeleton with a stat number, label, and small chart placeholder.
struct SkeletonDashboardCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.1), .purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Spacer()

                // Trend indicator placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.08))
                    .frame(width: 40, height: 18)
            }

            // Large stat number
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.12))
                .frame(height: 24)
                .frame(maxWidth: 80)

            // Label text
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.08))
                .frame(height: 10)
                .frame(maxWidth: 120)

            // Mini chart / progress bar
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.indigo.opacity(0.06), .purple.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton Grid

/// A grid of skeleton card placeholders, useful for loading states in grid-based views.
struct SkeletonGrid: View {
    let count: Int
    var columns: Int = 2
    var cardHeight: CGFloat = 180

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(0..<count, id: \.self) { index in
                SkeletonCard(height: cardHeight)
                    .opacity(opacityForIndex(index))
            }
        }
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
        .accessibilityLabel("Loading content")
    }

    /// Stagger opacity so cards further down appear slightly fainter,
    /// giving a progressive loading feel.
    private func opacityForIndex(_ index: Int) -> Double {
        let maxOpacity = 1.0
        let minOpacity = 0.5
        let step = (maxOpacity - minOpacity) / max(Double(count - 1), 1)
        return maxOpacity - step * Double(index)
    }
}

// MARK: - Skeleton List

/// A vertical stack of skeleton list row placeholders.
struct SkeletonList: View {
    let count: Int
    var showChevrons: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                SkeletonListRow(showTrailingChevron: showChevrons)
                    .opacity(opacityForIndex(index))
            }
        }
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
        .accessibilityLabel("Loading content")
    }

    private func opacityForIndex(_ index: Int) -> Double {
        let maxOpacity = 1.0
        let minOpacity = 0.5
        let step = (maxOpacity - minOpacity) / max(Double(count - 1), 1)
        return maxOpacity - step * Double(index)
    }
}

// MARK: - Previews

#Preview("Skeleton Cards") {
    ScrollView {
        VStack(spacing: 20) {
            SkeletonCard()
            SkeletonCard(height: 200)
        }
        .padding()
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Skeleton List Rows") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonListRow(showTrailingChevron: true)
            }
        }
        .padding()
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Skeleton Dashboard") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonDashboardCard()
            }
        }
        .padding()
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Skeleton Grid") {
    ScrollView {
        SkeletonGrid(count: 6)
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Skeleton List") {
    ScrollView {
        SkeletonList(count: 5, showChevrons: true)
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}
