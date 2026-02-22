import Foundation

/// A debounce utility for search fields and other rapid-fire inputs.
///
/// Usage:
/// ```swift
/// @State private var debouncer = Debouncer()
///
/// TextField("Search", text: $query)
///     .onChange(of: query) { _, newValue in
///         debouncer.debounce {
///             await performSearch(newValue)
///         }
///     }
/// ```
@MainActor
@Observable
final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    /// Cancels any pending action and schedules a new one after the configured delay.
    func debounce(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancels any pending debounced action.
    func cancel() {
        task?.cancel()
        task = nil
    }
}
