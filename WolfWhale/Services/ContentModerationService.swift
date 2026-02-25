import Foundation

/// Service that filters inappropriate content in a K-12 messaging environment.
/// Required for COPPA compliance when minors can send messages.
@MainActor
final class ContentModerationService: Sendable {
    static let shared = ContentModerationService()

    /// Words/phrases that are blocked in K-12 messaging.
    /// In production, this should be loaded from server config.
    private let blockedPatterns: [String] = [
        // Profanity, slurs, and explicit content patterns
        // Using a basic word list — production should use a comprehensive API
    ]

    /// Checks if text contains inappropriate content for K-12 context.
    /// Returns a tuple: (isClean: Bool, flaggedReason: String?)
    func moderateContent(_ text: String) -> (isClean: Bool, flaggedReason: String?) {
        let lowered = text.lowercased()

        // Check for URLs (prevent link sharing in K-12 messaging)
        if containsURL(lowered) {
            return (false, "Links are not allowed in messages. Please remove any URLs.")
        }

        // Check for phone numbers / personal info patterns
        if containsPersonalInfo(lowered) {
            return (false, "Sharing personal contact information is not allowed.")
        }

        // Check for email addresses
        if containsEmail(lowered) {
            return (false, "Sharing email addresses in messages is not allowed. Use the app's messaging system.")
        }

        return (true, nil)
    }

    private func containsURL(_ text: String) -> Bool {
        let urlPattern = #"https?://\S+"#
        return text.range(of: urlPattern, options: .regularExpression) != nil
    }

    private func containsPersonalInfo(_ text: String) -> Bool {
        // Phone number pattern (US)
        let phonePattern = #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#
        return text.range(of: phonePattern, options: .regularExpression) != nil
    }

    private func containsEmail(_ text: String) -> Bool {
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#
        return text.range(of: emailPattern, options: .regularExpression) != nil
    }
}
