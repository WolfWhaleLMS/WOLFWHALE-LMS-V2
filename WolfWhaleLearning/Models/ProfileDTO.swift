import Foundation

nonisolated struct ProfileDTO: Codable, Sendable, Identifiable {
    let id: UUID
    var firstName: String?
    var lastName: String?
    var avatarUrl: String?
    var phone: String?
    var dateOfBirth: String?
    var bio: String?
    var timezone: String?
    var language: String?
    var preferences: String?
    var createdAt: String?
    var updatedAt: String?
    var gradeLevel: String?
    var fullName: String?

    var role: String = ""
    var email: String = ""

    enum CodingKeys: String, CodingKey {
        case id, phone, bio, timezone, language, preferences, role, email
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case dateOfBirth = "date_of_birth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case gradeLevel = "grade_level"
        case fullName = "full_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        dateOfBirth = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        preferences = try c.decodeIfPresent(String.self, forKey: .preferences)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        gradeLevel = try c.decodeIfPresent(String.self, forKey: .gradeLevel)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
    }

    init(
        id: UUID,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarUrl: String? = nil,
        phone: String? = nil,
        dateOfBirth: String? = nil,
        bio: String? = nil,
        timezone: String? = nil,
        language: String? = nil,
        preferences: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        gradeLevel: String? = nil,
        fullName: String? = nil,
        role: String = "",
        email: String = ""
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.bio = bio
        self.timezone = timezone
        self.language = language
        self.preferences = preferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.gradeLevel = gradeLevel
        self.fullName = fullName
        self.role = role
        self.email = email
    }

    func toUser(
        email: String = "",
        role: UserRole = .student,
        streak: Int = 0
    ) -> User {
        User(
            id: id,
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            email: email,
            role: role,
            avatarSystemName: "person.crop.circle.fill",
            streak: streak,
            joinDate: Date()
        )
    }
}

nonisolated struct TenantMembershipDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let userId: UUID
    let role: String
    let status: String?
    let joinedAt: String?
    let invitedAt: String?
    let invitedBy: UUID?
    let suspendedAt: String?
    let suspendedReason: String?

    enum CodingKeys: String, CodingKey {
        case id, role, status
        case tenantId = "tenant_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case invitedAt = "invited_at"
        case invitedBy = "invited_by"
        case suspendedAt = "suspended_at"
        case suspendedReason = "suspended_reason"
    }
}

nonisolated struct StudentXpDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let studentId: UUID
    let totalXp: Int?
    let currentLevel: Int?
    let currentTier: String?
    let streakDays: Int?
    let lastLoginDate: String?
    let coins: Int?
    let totalCoinsEarned: Int?
    let totalCoinsSpent: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, coins
        case tenantId = "tenant_id"
        case studentId = "student_id"
        case totalXp = "total_xp"
        case currentLevel = "current_level"
        case currentTier = "current_tier"
        case streakDays = "streak_days"
        case lastLoginDate = "last_login_date"
        case totalCoinsEarned = "total_coins_earned"
        case totalCoinsSpent = "total_coins_spent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ClassCodeDTO: Codable, Sendable {
    let id: UUID?
    let tenantId: UUID?
    let courseId: UUID
    let code: String
    let isActive: Bool?
    let expiresAt: String?
    let maxUses: Int?
    let useCount: Int?
    let createdBy: UUID?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, code
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case isActive = "is_active"
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case useCount = "use_count"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

nonisolated struct InsertClassCodeDTO: Encodable, Sendable {
    let tenantId: UUID?
    let courseId: UUID
    let code: String
    let isActive: Bool?
    let expiresAt: String?
    let maxUses: Int?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case code
        case tenantId = "tenant_id"
        case courseId = "course_id"
        case isActive = "is_active"
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case createdBy = "created_by"
    }
}

nonisolated struct InsertProfileDTO: Encodable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let avatarUrl: String?
    let phone: String?
    let dateOfBirth: String?
    let bio: String?
    let timezone: String?
    let language: String?
    let gradeLevel: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id, phone, bio, timezone, language
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case dateOfBirth = "date_of_birth"
        case gradeLevel = "grade_level"
        case fullName = "full_name"
    }
}

nonisolated struct InsertTenantMembershipDTO: Encodable, Sendable {
    let userId: UUID
    let tenantId: UUID?
    let role: String
    let status: String?
    let joinedAt: String?
    let invitedAt: String?
    let invitedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case role, status
        case userId = "user_id"
        case tenantId = "tenant_id"
        case joinedAt = "joined_at"
        case invitedAt = "invited_at"
        case invitedBy = "invited_by"
    }
}

nonisolated struct InsertStudentXpDTO: Encodable, Sendable {
    let studentId: UUID
    let tenantId: UUID?
    let totalXp: Int
    let currentLevel: Int
    let currentTier: String?
    let streakDays: Int
    let coins: Int
    let totalCoinsEarned: Int?
    let totalCoinsSpent: Int?

    enum CodingKeys: String, CodingKey {
        case coins
        case studentId = "student_id"
        case tenantId = "tenant_id"
        case totalXp = "total_xp"
        case currentLevel = "current_level"
        case currentTier = "current_tier"
        case streakDays = "streak_days"
        case totalCoinsEarned = "total_coins_earned"
        case totalCoinsSpent = "total_coins_spent"
    }
}

nonisolated struct UpdateStudentXpDTO: Encodable, Sendable {
    var totalXp: Int?
    var currentLevel: Int?
    var currentTier: String?
    var streakDays: Int?
    var lastLoginDate: String?
    var coins: Int?
    var totalCoinsEarned: Int?
    var totalCoinsSpent: Int?

    enum CodingKeys: String, CodingKey {
        case coins
        case totalXp = "total_xp"
        case currentLevel = "current_level"
        case currentTier = "current_tier"
        case streakDays = "streak_days"
        case lastLoginDate = "last_login_date"
        case totalCoinsEarned = "total_coins_earned"
        case totalCoinsSpent = "total_coins_spent"
    }
}
