import Foundation

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let avatarUrl: String?
    let xp: Int
    let level: Int
    let coins: Int
    let streak: Int
    let createdAt: String?
    let schoolId: String?
    let userSlotsTotal: Int?
    let userSlotsUsed: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email, role
        case avatarUrl = "avatar_url"
        case xp, level, coins, streak
        case createdAt = "created_at"
        case schoolId = "school_id"
        case userSlotsTotal = "user_slots_total"
        case userSlotsUsed = "user_slots_used"
    }

    func toUser() -> User {
        User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            role: UserRole(rawValue: role) ?? .student,
            avatarSystemName: "person.crop.circle.fill",
            xp: xp,
            level: level,
            coins: coins,
            streak: streak,
            joinDate: Date(),
            schoolId: schoolId,
            userSlotsTotal: userSlotsTotal ?? 0,
            userSlotsUsed: userSlotsUsed ?? 0
        )
    }
}

nonisolated struct InsertProfileDTO: Encodable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let schoolId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email, role
        case schoolId = "school_id"
    }
}

nonisolated struct UpdateProfileDTO: Encodable, Sendable {
    var xp: Int?
    var level: Int?
    var coins: Int?
    var streak: Int?
}

nonisolated struct UpdateSlotsDTO: Encodable, Sendable {
    var userSlotsUsed: Int

    enum CodingKeys: String, CodingKey {
        case userSlotsUsed = "user_slots_used"
    }
}
