import Foundation

/// Centralized input validation and sanitization for all user-facing data entry points.
/// All methods are pure (no async, no UI dependencies) and safe to call from any isolation context.
nonisolated enum InputValidator {

    // MARK: - Constants

    /// Maximum allowed length for general text fields before truncation.
    private static let maxGeneralTextLength = 5000
    /// Maximum allowed length for message content.
    private static let maxMessageLength = 10000

    // MARK: - Text Sanitization

    /// Trims whitespace, removes control characters, and limits length.
    /// Use this as a first pass on any free-text input before further validation.
    static func sanitizeText(_ input: String, maxLength: Int = maxGeneralTextLength) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove control characters (U+0000-U+001F, U+007F-U+009F) but keep newlines and tabs
        let allowedControlChars = CharacterSet(charactersIn: "\n\t")
        let controlChars = CharacterSet.controlCharacters.subtracting(allowedControlChars)
        let cleaned = trimmed.unicodeScalars.filter { !controlChars.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
        if result.count > maxLength {
            return String(result.prefix(maxLength))
        }
        return result
    }

    // MARK: - Email Validation

    /// Validates an email address using an RFC 5322-compliant pattern.
    /// Returns `true` if the email format is valid.
    static func validateEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // RFC 5322 simplified pattern: local part allows letters, digits, and common symbols;
        // domain requires at least one dot with a 2+ character TLD.
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Password Validation

    /// Validates password strength. Requires minimum 8 characters, at least one uppercase letter,
    /// one lowercase letter, and one digit.
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validatePassword(_ password: String) -> (valid: Bool, message: String) {
        guard password.count >= 8 else {
            return (false, "Password must be at least 8 characters long.")
        }
        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else {
            return (false, "Password must contain at least one uppercase letter.")
        }
        guard password.rangeOfCharacter(from: .lowercaseLetters) != nil else {
            return (false, "Password must contain at least one lowercase letter.")
        }
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            return (false, "Password must contain at least one number.")
        }
        return (true, "")
    }

    // MARK: - Course Name Validation

    /// Validates a course name. Must be 3-100 characters.
    /// Allows letters, digits, spaces, and basic punctuation (. , - : & ' /).
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validateCourseName(_ name: String) -> (valid: Bool, message: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            return (false, "Course name must be at least 3 characters.")
        }
        guard trimmed.count <= 100 else {
            return (false, "Course name must be 100 characters or fewer.")
        }
        // Allow letters (including accented), digits, spaces, and basic punctuation
        let allowedPattern = #"^[\p{L}\p{N}\s.,\-:&'/()]+$"#
        guard trimmed.range(of: allowedPattern, options: .regularExpression) != nil else {
            return (false, "Course name can only contain letters, numbers, and basic punctuation.")
        }
        return (true, "")
    }

    // MARK: - Assignment Title Validation

    /// Validates an assignment title. Must be 1-200 characters after trimming.
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validateAssignmentTitle(_ title: String) -> (valid: Bool, message: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, "Assignment title cannot be empty.")
        }
        guard trimmed.count <= 200 else {
            return (false, "Assignment title must be 200 characters or fewer.")
        }
        return (true, "")
    }

    // MARK: - Points Validation

    /// Validates that points are within the allowed range of 0-1000.
    static func validatePoints(_ points: Int) -> Bool {
        (0...1000).contains(points)
    }

    // MARK: - Grade Validation

    /// Validates that a grade percentage is within the allowed range.
    /// Standard range is 0-100, but allows up to 200 for extra credit scenarios.
    static func validateGrade(_ grade: Double) -> Bool {
        grade >= 0 && grade <= 200
    }

    // MARK: - HTML Sanitization

    /// Strips all HTML tags from the input to prevent XSS attacks.
    /// This is a defence-in-depth measure for content that may be rendered in web views.
    ///
    /// Decodes HTML entities first, then strips tags, and repeats in a loop
    /// (up to 3 iterations) to catch multi-layer encoded payloads such as
    /// `&lt;script&gt;` which would become `<script>` after a single decode.
    static func sanitizeHTML(_ input: String) -> String {
        var result = input

        for _ in 0..<3 {
            // 1. Decode common HTML entities so encoded tags become visible
            let decoded = result
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")

            // 2. Strip HTML/XML tags
            let pattern = "<[^>]+>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return decoded
            }
            let range = NSRange(decoded.startIndex..., in: decoded)
            let stripped = regex.stringByReplacingMatches(in: decoded, options: [], range: range, withTemplate: "")

            // If nothing changed this iteration, we are done
            if stripped == result {
                return stripped
            }
            result = stripped
        }

        return result
    }

    // MARK: - File Size Validation

    /// Validates that a file size (in bytes) does not exceed the maximum allowed size.
    /// - Parameters:
    ///   - bytes: The file size in bytes.
    ///   - maxMB: The maximum allowed size in megabytes.
    /// - Returns: `true` if the file is within the allowed size.
    static func validateFileSize(_ bytes: Int64, maxMB: Int) -> Bool {
        guard bytes >= 0, maxMB > 0 else { return false }
        let maxBytes = Int64(maxMB) * 1024 * 1024
        return bytes <= maxBytes
    }

    // MARK: - File Type Validation

    /// Validates that a filename has an extension in the allowed list.
    /// - Parameters:
    ///   - filename: The name of the file (e.g. "report.pdf").
    ///   - allowed: An array of allowed extensions, case-insensitive (e.g. ["pdf", "docx", "png"]).
    /// - Returns: `true` if the file extension is in the allowed list.
    static func validateFileType(_ filename: String, allowed: [String]) -> Bool {
        guard !filename.isEmpty, !allowed.isEmpty else { return false }
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return allowed.map { $0.lowercased() }.contains(ext)
    }

    // MARK: - Name Validation

    /// Validates a person's name (first or last). Must be 1-50 characters, letters and common name characters only.
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validateName(_ name: String, fieldName: String = "Name") -> (valid: Bool, message: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, "\(fieldName) cannot be empty.")
        }
        guard trimmed.count <= 50 else {
            return (false, "\(fieldName) must be 50 characters or fewer.")
        }
        // Allow letters (including accented/international), spaces, hyphens, and apostrophes
        let allowedPattern = #"^[\p{L}\s\-']+$"#
        guard trimmed.range(of: allowedPattern, options: .regularExpression) != nil else {
            return (false, "\(fieldName) can only contain letters, spaces, hyphens, and apostrophes.")
        }
        return (true, "")
    }

    // MARK: - Message Validation

    /// Validates message content. Must not be empty after trimming and sanitization.
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validateMessage(_ text: String) -> (valid: Bool, message: String) {
        let sanitized = sanitizeText(text, maxLength: maxMessageLength)
        let cleaned = sanitizeHTML(sanitized)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "Message cannot be empty.")
        }
        return (true, "")
    }

    // MARK: - Due Date Validation

    /// Validates that a due date is in the future.
    /// Returns a tuple with the validation result and a user-friendly message.
    static func validateDueDate(_ date: Date) -> (valid: Bool, message: String) {
        guard date > Date() else {
            return (false, "Due date must be in the future.")
        }
        return (true, "")
    }

    // MARK: - Announcement Validation

    /// Validates an announcement title. Must be 1-200 characters after trimming.
    static func validateAnnouncementTitle(_ title: String) -> (valid: Bool, message: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, "Announcement title cannot be empty.")
        }
        guard trimmed.count <= 200 else {
            return (false, "Announcement title must be 200 characters or fewer.")
        }
        return (true, "")
    }
}
