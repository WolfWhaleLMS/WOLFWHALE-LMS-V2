import Foundation

nonisolated struct Achievement: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var description: String
    var iconSystemName: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    var xpReward: Int
    var rarity: AchievementRarity
}

nonisolated enum AchievementRarity: String, Sendable, Codable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var colorName: String {
        switch self {
        case .common: "gray"
        case .rare: "blue"
        case .epic: "purple"
        case .legendary: "orange"
        }
    }
}

nonisolated struct LeaderboardEntry: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var userName: String
    var xp: Int
    var level: Int
    var rank: Int
    var avatarSystemName: String
}
