import Foundation

/// Sanitizes raw backend errors into user-friendly messages.
/// Raw errors are logged in DEBUG builds but never shown to users.
/// This prevents leaking database table names, column names, constraint names,
/// and PostgreSQL error codes to end users.
enum UserFacingError: LocalizedError {
    case authentication(String)
    case network(String)
    case notFound(String)
    case permissionDenied(String)
    case validation(String)
    case generic

    var errorDescription: String? {
        switch self {
        case .authentication(let msg): return msg
        case .network(let msg): return msg
        case .notFound(let msg): return msg
        case .permissionDenied(let msg): return msg
        case .validation(let msg): return msg
        case .generic: return "Something went wrong. Please try again."
        }
    }

    /// Converts any raw error into a safe, user-facing error message.
    /// Logs the original error in DEBUG builds for debugging.
    static func sanitize(_ error: Error) -> UserFacingError {
        #if DEBUG
        print("[ErrorSanitizer] Raw error: \(error)")
        #endif

        // URLError — network issues
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .network("No internet connection. Please check your network.")
            case .timedOut:
                return .network("The request timed out. Please try again.")
            case .cancelled:
                return .generic // User cancelled, don't show error
            default:
                return .network("A network error occurred. Please try again.")
            }
        }

        // CancellationError — task was cancelled
        if error is CancellationError {
            return .generic
        }

        // String-based matching for Supabase/Postgrest errors
        let errorString = String(describing: error).lowercased()

        if errorString.contains("unauthorized") || errorString.contains("401")
            || errorString.contains("invalid login") || errorString.contains("invalid_credentials") {
            return .authentication("Invalid email or password. Please try again.")
        }

        if errorString.contains("token") && (errorString.contains("expired") || errorString.contains("revoked")) {
            return .authentication("Your session has expired. Please sign in again.")
        }

        if errorString.contains("forbidden") || errorString.contains("403") || errorString.contains("permission") {
            return .permissionDenied("You don't have permission to perform this action.")
        }

        if errorString.contains("not found") || errorString.contains("404") {
            return .notFound("The requested content was not found.")
        }

        if errorString.contains("validation") || errorString.contains("invalid") || errorString.contains("constraint") {
            return .validation("Please check your input and try again.")
        }

        if errorString.contains("duplicate") || errorString.contains("unique") || errorString.contains("already exists") {
            return .validation("This item already exists.")
        }

        return .generic
    }

    /// Convenience: returns a sanitized user-facing message string directly.
    static func message(from error: Error) -> String {
        sanitize(error).errorDescription ?? "Something went wrong. Please try again."
    }
}
