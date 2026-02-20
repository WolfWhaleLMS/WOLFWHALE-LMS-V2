import Foundation

/// Lightweight pagination state for cursor-based or offset-based pagination.
/// Used by views to track where they are in a paginated data set and whether
/// more data is available to fetch.
nonisolated struct PaginationState: Sendable {
    /// The current zero-indexed page number
    var currentPage: Int = 0

    /// Number of items per page (default 20)
    var pageSize: Int = 20

    /// Whether there are more items beyond the current page
    var hasMore: Bool = true

    /// Whether a page fetch is currently in progress
    var isLoading: Bool = false

    /// Computed offset for the current page, used with Supabase `.range(from:to:)`
    var offset: Int { currentPage * pageSize }

    /// The upper bound (exclusive) for the current page range
    var rangeEnd: Int { offset + pageSize - 1 }

    /// Advance to the next page
    mutating func nextPage() {
        currentPage += 1
    }

    /// Reset to the first page (e.g., on pull-to-refresh)
    mutating func reset() {
        currentPage = 0
        hasMore = true
        isLoading = false
    }

    /// Mark that a fetch returned fewer items than pageSize, meaning no more pages
    mutating func updateHasMore(fetchedCount: Int) {
        hasMore = fetchedCount >= pageSize
    }
}
