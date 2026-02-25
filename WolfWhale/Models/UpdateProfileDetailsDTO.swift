import Foundation

/// Update DTO for the `profiles` table.
/// Includes all writable columns from: first_name, last_name, avatar_url,
/// phone, date_of_birth, bio, timezone, language, preferences, grade_level, full_name
nonisolated struct UpdateProfileDetailsDTO: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var avatarUrl: String?
    var phone: String?
    var dateOfBirth: String?
    var bio: String?
    var timezone: String?
    var language: String?
    var preferences: String?
    var gradeLevel: String?
    var fullName: String?

    enum CodingKeys: String, CodingKey {
        case phone, bio, timezone, language, preferences
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case dateOfBirth = "date_of_birth"
        case gradeLevel = "grade_level"
        case fullName = "full_name"
    }
}
