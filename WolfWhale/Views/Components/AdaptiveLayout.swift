import SwiftUI

// MARK: - Adaptive Columns

/// Provides adaptive layouts that switch between single-column (iPhone)
/// and multi-column (iPad) based on horizontal size class.
///
/// On iPad (regular width), child views are displayed side-by-side.
/// On iPhone (compact width), child views are stacked vertically.
struct AdaptiveColumns<Leading: View, Trailing: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let sidebarWidth: CGFloat
    let leading: Leading
    let trailing: Trailing

    /// Creates an adaptive two-column layout.
    /// - Parameters:
    ///   - sidebarWidth: The width of the leading column on iPad. Defaults to 340.
    ///   - leading: The content shown in the leading (left / top) position.
    ///   - trailing: The content shown in the trailing (right / bottom) position.
    init(
        sidebarWidth: CGFloat = 340,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.sidebarWidth = sidebarWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        if sizeClass == .regular {
            // iPad layout: side-by-side columns
            HStack(spacing: 0) {
                ScrollView {
                    leading
                        .padding()
                }
                .frame(width: sidebarWidth)

                Divider()

                ScrollView {
                    trailing
                        .padding()
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            // iPhone layout: stacked vertically in a single ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    leading
                    trailing
                }
            }
        }
    }
}

// MARK: - Adaptive Grid

/// A grid layout that adapts its column count based on the horizontal size class.
///
/// On iPad (regular width), displays items in the specified `regularColumns` count.
/// On iPhone (compact width), displays items in the specified `compactColumns` count.
struct AdaptiveGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let compactColumns: Int
    let regularColumns: Int
    let spacing: CGFloat
    let content: Content

    /// Creates an adaptive grid.
    /// - Parameters:
    ///   - compactColumns: Number of columns on iPhone. Defaults to 2.
    ///   - regularColumns: Number of columns on iPad. Defaults to 3.
    ///   - spacing: The spacing between grid items. Defaults to 12.
    ///   - content: The grid content.
    init(
        compactColumns: Int = 2,
        regularColumns: Int = 3,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.compactColumns = compactColumns
        self.regularColumns = regularColumns
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        let columnCount = sizeClass == .regular ? regularColumns : compactColumns
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)

        LazyVGrid(columns: columns, spacing: spacing) {
            content
        }
    }
}

// MARK: - iPad Detection Helper

/// A view modifier that provides a Boolean binding indicating
/// whether the current horizontal size class is `.regular` (iPad-like).
struct iPadAwareModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.isRegularWidth, sizeClass == .regular)
    }
}

// MARK: - Custom Environment Key

private struct IsRegularWidthKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// `true` when the horizontal size class is `.regular` (typically iPad).
    var isRegularWidth: Bool {
        get { self[IsRegularWidthKey.self] }
        set { self[IsRegularWidthKey.self] = newValue }
    }
}

extension View {
    /// Makes the view iPad-aware by injecting `isRegularWidth` into the environment.
    func iPadAware() -> some View {
        modifier(iPadAwareModifier())
    }
}
