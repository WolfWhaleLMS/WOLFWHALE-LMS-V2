import Foundation

/// Generic pagination wrapper used by ViewModels to track paginated list state.
///
/// Usage:
/// ```swift
/// let page = PaginatedResponse(items: fetchedCourses, offset: currentOffset, limit: pageSize)
/// allCourses.append(contentsOf: page.items)
/// canLoadMore = page.hasMore
/// nextOffset = page.nextOffset
/// ```
struct PaginatedResponse<T> {
    let items: [T]
    let hasMore: Bool
    let nextOffset: Int

    init(items: [T], offset: Int, limit: Int) {
        self.items = items
        self.hasMore = items.count >= limit
        self.nextOffset = offset + items.count
    }
}
