import Foundation

/// Circuit breaker pattern to prevent cascading failures.
///
/// When a service fails repeatedly, the circuit **opens** and fails fast
/// without making network requests. After a configurable timeout the circuit
/// moves to **half-open**, allowing a single test request through. If that
/// request succeeds the circuit **closes** (normal operation resumes); if it
/// fails the circuit re-opens.
///
/// Thread-safety is guaranteed by the `actor` isolation.
actor CircuitBreaker {

    // MARK: - State

    enum State: Sendable {
        case closed      // Normal operation
        case open        // Failing fast, not making requests
        case halfOpen    // Testing with a single request
    }

    // MARK: - Configuration

    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private let name: String

    // MARK: - Internal State

    private(set) var state: State = .closed
    private var failureCount: Int = 0
    private var lastFailureDate: Date?
    private var successCount: Int = 0

    // MARK: - Init

    init(name: String, failureThreshold: Int = 5, resetTimeout: TimeInterval = 60) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    // MARK: - Execute with Circuit Breaker

    /// Wraps an async throwing operation with circuit-breaker protection.
    ///
    /// - Throws: `CircuitBreakerError.circuitOpen` when the circuit is open
    ///           and the reset timeout has not yet elapsed, or re-throws any
    ///           error from the underlying operation.
    func execute<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        // Check if the circuit should transition from open -> half-open
        if state == .open {
            if let lastFailure = lastFailureDate,
               Date().timeIntervalSince(lastFailure) >= resetTimeout {
                state = .halfOpen
                #if DEBUG
                print("[CircuitBreaker][\(name)]: half-open, testing...")
                #endif
            } else {
                throw CircuitBreakerError.circuitOpen(name: name)
            }
        }

        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }

    // MARK: - State Transitions

    private func recordSuccess() {
        failureCount = 0
        if state == .halfOpen {
            state = .closed
            #if DEBUG
            print("[CircuitBreaker][\(name)]: closed (recovered)")
            #endif
        }
        successCount += 1
    }

    private func recordFailure() {
        failureCount += 1
        lastFailureDate = Date()

        if failureCount >= failureThreshold {
            state = .open
            #if DEBUG
            print("[CircuitBreaker][\(name)]: OPEN after \(failureCount) failures")
            #endif
        }
    }

    // MARK: - Manual Reset

    /// Force the circuit back to closed. Useful after a manual user retry.
    func reset() {
        state = .closed
        failureCount = 0
        lastFailureDate = nil
        successCount = 0
    }
}

// MARK: - Error

enum CircuitBreakerError: LocalizedError {
    case circuitOpen(name: String)

    var errorDescription: String? {
        switch self {
        case .circuitOpen(let name):
            return "Service '\(name)' is temporarily unavailable. Please try again shortly."
        }
    }
}
