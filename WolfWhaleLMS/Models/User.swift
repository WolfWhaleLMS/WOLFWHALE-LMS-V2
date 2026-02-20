import Foundation

nonisolated enum UserRole: String, CaseIterable, Sendable, Identifiable {
    case student = "Student"
    case teacher = "Teacher"
    case parent = "Parent"
    case admin = "Admin"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .student: "graduationcap.fill"
        case .teacher: "person.crop.rectangle.fill"
        case .parent: "figure.2.and.child.holdinghands"
        case .admin: "gearshape.2.fill"
        }
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
}
