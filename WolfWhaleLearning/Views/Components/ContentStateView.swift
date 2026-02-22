import SwiftUI

/// A generic wrapper that handles the four common view states: loading, error, empty, and content.
///
/// Usage:
/// ```swift
/// ContentStateView(
///     isLoading: viewModel.isLoading,
///     error: viewModel.error,
///     isEmpty: viewModel.courses.isEmpty,
///     emptyIcon: "book.closed",
///     emptyTitle: "No Courses",
///     emptyMessage: "Browse the course catalog to get started.",
///     emptyActionLabel: "Browse Catalog",
///     emptyAction: { showCatalog = true },
///     retryAction: { await viewModel.load() }
/// ) {
///     CourseListView(courses: viewModel.courses)
/// }
/// ```
struct ContentStateView<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    var emptyActionLabel: String? = nil
    var emptyAction: (() -> Void)? = nil
    var retryAction: (() async -> Void)? = nil
    @ViewBuilder let content: () -> Content

    /// Controls the skeleton variant shown during loading.
    var skeletonStyle: SkeletonStyle = .list

    enum SkeletonStyle {
        /// A list of row skeletons.
        case list
        /// A grid of card skeletons.
        case grid
        /// Dashboard-style stat cards.
        case dashboard
        /// A custom skeleton count for lists.
        case custom(count: Int)
    }

    var body: some View {
        Group {
            if isLoading && isEmpty {
                loadingView
                    .transition(.opacity)
            } else if let error {
                ErrorStateView(message: error, retryAction: retryAction)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyTitle,
                    message: emptyMessage,
                    actionLabel: emptyActionLabel,
                    action: emptyAction
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isLoading)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: error != nil)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isEmpty)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        ScrollView {
            switch skeletonStyle {
            case .list:
                SkeletonList(count: 5, showChevrons: true)
                    .padding(.top, 8)
            case .grid:
                SkeletonGrid(count: 6)
                    .padding(.top, 8)
            case .dashboard:
                VStack(spacing: 12) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ],
                        spacing: 12
                    ) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonDashboardCard()
                        }
                    }
                    .padding(.horizontal, 16)

                    SkeletonList(count: 3)
                }
                .padding(.top, 8)
            case .custom(let count):
                SkeletonList(count: count, showChevrons: true)
                    .padding(.top, 8)
            }
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading content")
    }
}

// MARK: - Convenience Initializer (no empty action)

extension ContentStateView {
    /// Convenience initializer without an empty-state action button.
    init(
        isLoading: Bool,
        error: String?,
        isEmpty: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        retryAction: (() async -> Void)? = nil,
        skeletonStyle: SkeletonStyle = .list,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.isEmpty = isEmpty
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.emptyActionLabel = nil
        self.emptyAction = nil
        self.retryAction = retryAction
        self.skeletonStyle = skeletonStyle
        self.content = content
    }
}

// MARK: - Previews

#Preview("Loading State") {
    ContentStateView(
        isLoading: true,
        error: nil,
        isEmpty: true,
        emptyIcon: "book.closed",
        emptyTitle: "No Courses",
        emptyMessage: "Browse the course catalog."
    ) {
        Text("Content")
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Error State") {
    ContentStateView(
        isLoading: false,
        error: "Unable to connect to the server. Please check your internet connection.",
        isEmpty: true,
        emptyIcon: "book.closed",
        emptyTitle: "No Courses",
        emptyMessage: "Browse the course catalog.",
        retryAction: {
            try? await Task.sleep(for: .seconds(2))
        }
    ) {
        Text("Content")
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Empty State") {
    ContentStateView(
        isLoading: false,
        error: nil,
        isEmpty: true,
        emptyIcon: "book.closed",
        emptyTitle: "No Courses",
        emptyMessage: "Browse the course catalog to get started with your learning journey.",
        emptyActionLabel: "Browse Catalog",
        emptyAction: { }
    ) {
        Text("Content")
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Content State") {
    ContentStateView(
        isLoading: false,
        error: nil,
        isEmpty: false,
        emptyIcon: "book.closed",
        emptyTitle: "No Courses",
        emptyMessage: "Browse the course catalog."
    ) {
        List {
            ForEach(0..<5, id: \.self) { i in
                Text("Course \(i + 1)")
            }
        }
    }
}

#Preview("Grid Skeleton") {
    ContentStateView(
        isLoading: true,
        error: nil,
        isEmpty: true,
        emptyIcon: "square.grid.2x2",
        emptyTitle: "No Items",
        emptyMessage: "Nothing to display.",
        skeletonStyle: .grid
    ) {
        Text("Content")
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}

#Preview("Dashboard Skeleton") {
    ContentStateView(
        isLoading: true,
        error: nil,
        isEmpty: true,
        emptyIcon: "chart.bar",
        emptyTitle: "No Data",
        emptyMessage: "Nothing yet.",
        skeletonStyle: .dashboard
    ) {
        Text("Content")
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemGroupedBackground))
    #endif
}
