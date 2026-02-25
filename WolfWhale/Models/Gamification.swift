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

// MARK: - Badge System

nonisolated enum BadgeType: String, CaseIterable, Sendable, Codable {
    case firstAssignment = "First Assignment"
    case quizMaster = "Quiz Master"
    case perfectScore = "Perfect Score"
    case sevenDayStreak = "7-Day Streak"
    case courseComplete = "Course Complete"
    case earlyBird = "Early Bird"
    case socialLearner = "Social Learner"
    case firstSteps = "First Steps"
    case tenLessons = "10 Lessons"
    case thirtyDayStreak = "30-Day Streak"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .firstAssignment: "Submit your first assignment"
        case .quizMaster: "Complete 5 quizzes"
        case .perfectScore: "Score 100% on a quiz"
        case .sevenDayStreak: "Maintain a 7-day streak"
        case .courseComplete: "Complete all lessons in a course"
        case .earlyBird: "Submit 3 assignments early"
        case .socialLearner: "Send 10 messages"
        case .firstSteps: "Complete your first lesson"
        case .tenLessons: "Complete 10 lessons"
        case .thirtyDayStreak: "Maintain a 30-day streak"
        }
    }

    var iconSystemName: String {
        switch self {
        case .firstAssignment: "doc.text.fill"
        case .quizMaster: "checkmark.seal.fill"
        case .perfectScore: "star.circle.fill"
        case .sevenDayStreak: "flame.fill"
        case .courseComplete: "graduationcap.fill"
        case .earlyBird: "sunrise.fill"
        case .socialLearner: "bubble.left.and.bubble.right.fill"
        case .firstSteps: "figure.walk"
        case .tenLessons: "book.fill"
        case .thirtyDayStreak: "bolt.fill"
        }
    }

    var rarity: AchievementRarity {
        switch self {
        case .firstAssignment, .firstSteps: .common
        case .quizMaster, .sevenDayStreak, .tenLessons, .socialLearner: .rare
        case .perfectScore, .earlyBird, .courseComplete: .epic
        case .thirtyDayStreak: .legendary
        }
    }
}

nonisolated struct Badge: Identifiable, Hashable, Sendable {
    let id: UUID
    var badgeType: BadgeType
    var isEarned: Bool
    var earnedDate: Date?
    /// Progress toward earning the badge, from 0.0 to 1.0.
    var progress: Double

    var name: String { badgeType.displayName }
    var icon: String { badgeType.iconSystemName }
    var description: String { badgeType.description }
    var rarity: AchievementRarity { badgeType.rarity }

    init(badgeType: BadgeType, isEarned: Bool = false, earnedDate: Date? = nil, progress: Double = 0.0) {
        self.id = UUID()
        self.badgeType = badgeType
        self.isEarned = isEarned
        self.earnedDate = earnedDate
        self.progress = isEarned ? 1.0 : min(max(progress, 0.0), 1.0)
    }
}

// MARK: - XP Level System

/// Exponential level curve:
/// Level 1: 0-100 XP, Level 2: 101-300, Level 3: 301-600, Level 4: 601-1000, etc.
/// Formula: XP threshold for level N = sum(i=1..N-1) of (i * 100) + 100
/// i.e. Level 1 needs 0, Level 2 needs 101, Level 3 needs 301, Level 4 needs 601...
enum XPLevelSystem {
    /// Returns the minimum XP required to reach the given level.
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        // Level 2: 101, Level 3: 301, Level 4: 601, Level 5: 1001...
        // Sum of 100 + 200 + 300 + ... + (level-1)*100, then +1
        var total = 0
        for i in 1..<level {
            total += i * 100
        }
        return total + 1
    }

    /// Returns the XP needed to complete the given level (reach level+1).
    static func xpForNextLevel(currentLevel: Int) -> Int {
        return xpRequired(forLevel: currentLevel + 1)
    }

    /// Computes the level for a given total XP amount.
    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp {
            level += 1
        }
        return level
    }

    /// Returns progress (0.0-1.0) within the current level.
    static func progressInLevel(xp: Int) -> Double {
        let currentLevel = level(forXP: xp)
        let currentLevelStart = currentLevel > 1 ? xpRequired(forLevel: currentLevel) : 0
        let nextLevelStart = xpRequired(forLevel: currentLevel + 1)
        let range = nextLevelStart - currentLevelStart
        guard range > 0 else { return 1.0 }
        return Double(xp - currentLevelStart) / Double(range)
    }

    /// XP remaining until next level.
    static func xpToNextLevel(xp: Int) -> Int {
        let nextStart = xpRequired(forLevel: level(forXP: xp) + 1)
        return max(0, nextStart - xp)
    }

    /// Display name for the level tier.
    static func tierName(forLevel level: Int) -> String {
        switch level {
        case 1: "Beginner"
        case 2...3: "Learner"
        case 4...6: "Scholar"
        case 7...9: "Expert"
        case 10...: "Master"
        default: "Beginner"
        }
    }
}
