import Foundation

nonisolated enum UserRole: String, CaseIterable, Sendable, Identifiable {
    case student = "Student"
    case teacher = "Teacher"
    case parent = "Parent"
    case admin = "Admin"
    case superAdmin = "SuperAdmin"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .student: "graduationcap.fill"
        case .teacher: "person.crop.rectangle.fill"
        case .parent: "figure.2.and.child.holdinghands"
        case .admin: "gearshape.2.fill"
        case .superAdmin: "shield.lefthalf.filled"
        }
    }

    static func from(_ string: String) -> UserRole? {
        let lowered = string.lowercased()
        return Self.allCases.first { $0.rawValue.lowercased() == lowered }
    }
}

nonisolated struct User: Identifiable, Hashable, Sendable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var role: UserRole
    var avatarSystemName: String
    var xp: Int
    var level: Int
    var coins: Int
    var streak: Int
    var joinDate: Date
    var schoolId: String?
    var userSlotsTotal: Int
    var userSlotsUsed: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var xpForNextLevel: Int { level * 500 }
    var xpProgress: Double {
        let needed = Double(xpForNextLevel)
        guard needed > 0 else { return 0 }
        return Double(xp % max(Int(needed), 1)) / max(needed, 1)
    }

    init(
        id: UUID,
        firstName: String,
        lastName: String,
        email: String = "",
        role: UserRole = .student,
        avatarSystemName: String = "person.crop.circle.fill",
        xp: Int = 0,
        level: Int = 1,
        coins: Int = 0,
        streak: Int = 0,
        joinDate: Date = Date(),
        schoolId: String? = nil,
        userSlotsTotal: Int = 0,
        userSlotsUsed: Int = 0
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.role = role
        self.avatarSystemName = avatarSystemName
        self.xp = xp
        self.level = level
        self.coins = coins
        self.streak = streak
        self.joinDate = joinDate
        self.schoolId = schoolId
        self.userSlotsTotal = userSlotsTotal
        self.userSlotsUsed = userSlotsUsed
    }
}
