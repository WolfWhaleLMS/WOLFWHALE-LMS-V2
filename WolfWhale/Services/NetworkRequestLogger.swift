import Foundation
import os.log

/// Lightweight network request/response logger for debugging.
///
/// All logging is wrapped in `#if DEBUG` so it compiles away entirely in
/// release builds. Uses the structured `os.log` `Logger` API.
enum NetworkRequestLogger {

    private static let logger = Logger(subsystem: "ca.wolfwhale.lms", category: "network")

    /// Log an outgoing request.
    static func logRequest(method: String, path: String, table: String) {
        #if DEBUG
        logger.debug("[\(method)] /\(table) -- \(path)")
        #endif
    }

    /// Log a successful response with row count and elapsed time.
    static func logResponse(table: String, count: Int, duration: TimeInterval) {
        #if DEBUG
        let ms = String(format: "%.0f", duration * 1000)
        logger.debug("[OK] /\(table) -- \(count) rows in \(ms)ms")
        #endif
    }

    /// Log a failed request with error details.
    static func logError(table: String, error: Error, duration: TimeInterval) {
        let ms = String(format: "%.0f", duration * 1000)
        logger.error("[FAIL] /\(table) failed in \(ms)ms -- \(error.localizedDescription)")
    }
}
