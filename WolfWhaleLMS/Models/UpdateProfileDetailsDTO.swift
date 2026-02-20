import Foundation

nonisolated struct UpdateProfileDetailsDTO: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
    }
}
