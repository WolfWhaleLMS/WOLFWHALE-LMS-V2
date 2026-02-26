import SwiftUI

// MARK: - Fish Rarity

enum FishRarity: String, CaseIterable, Sendable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    case mythical = "Mythical"
    
    var color: Color {
        switch self {
        case .common: .gray
        case .uncommon: .green
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        case .mythical: Color(red: 1, green: 0.84, blue: 0) // gold
        }
    }
    
    var glowColor: Color {
        switch self {
        case .common: .clear
        case .uncommon: .green.opacity(0.3)
        case .rare: .blue.opacity(0.4)
        case .epic: .purple.opacity(0.5)
        case .legendary: .orange.opacity(0.6)
        case .mythical: Color(red: 1, green: 0.84, blue: 0).opacity(0.7)
        }
    }
    
    var label: String {
        switch self {
        case .common: "⭐"
        case .uncommon: "⭐⭐"
        case .rare: "⭐⭐⭐"
        case .epic: "⭐⭐⭐⭐"
        case .legendary: "⭐⭐⭐⭐⭐"
        case .mythical: "👑"
        }
    }
}

// MARK: - Fish Species

struct AquariumFish: Identifiable, Sendable {
    let id: String
    let name: String
    let species: String
    let description: String
    let rarity: FishRarity
    let streakRequired: Int
    let icon: String          // SF Symbol name
    let primaryColor: Color
    let secondaryColor: Color
    let size: CGFloat         // relative size multiplier (1.0 = normal)
    let swimSpeed: Double     // animation speed multiplier
    
    var isUnlocked: Bool = false
    
    /// All available fish in the aquarium system, ordered by streak requirement.
    static let allFish: [AquariumFish] = [
        AquariumFish(
            id: "goldfish",
            name: "Goldie",
            species: "Goldfish",
            description: "A friendly little goldfish — everyone starts somewhere! Keep showing up and your tank will grow.",
            rarity: .common,
            streakRequired: 5,
            icon: "fish.fill",
            primaryColor: .orange,
            secondaryColor: .yellow,
            size: 0.8,
            swimSpeed: 1.0
        ),
        AquariumFish(
            id: "clownfish",
            name: "Nemo",
            species: "Clownfish",
            description: "A vibrant clownfish with bold orange and white stripes. Found hiding in anemones... and in consistent students' tanks!",
            rarity: .common,
            streakRequired: 10,
            icon: "fish.fill",
            primaryColor: Color(red: 1.0, green: 0.4, blue: 0.0),
            secondaryColor: .white,
            size: 0.85,
            swimSpeed: 1.2
        ),
        AquariumFish(
            id: "blue_tang",
            name: "Dory",
            species: "Blue Tang",
            description: "A stunning royal blue tang with a bright yellow tail. Just keep swimming, just keep attending!",
            rarity: .uncommon,
            streakRequired: 15,
            icon: "fish.fill",
            primaryColor: Color(red: 0.0, green: 0.4, blue: 0.9),
            secondaryColor: .yellow,
            size: 0.9,
            swimSpeed: 1.1
        ),
        AquariumFish(
            id: "angelfish",
            name: "Halo",
            species: "Angelfish",
            description: "An elegant angelfish with flowing fins that shimmer in the light. A sign of true dedication.",
            rarity: .uncommon,
            streakRequired: 20,
            icon: "fish.fill",
            primaryColor: Color(red: 0.9, green: 0.9, blue: 0.3),
            secondaryColor: Color(red: 0.0, green: 0.0, blue: 0.0),
            size: 1.0,
            swimSpeed: 0.8
        ),
        AquariumFish(
            id: "seahorse",
            name: "Poseidon",
            species: "Seahorse",
            description: "A graceful seahorse that bobs gently through the water. Only the dedicated earn this rare companion.",
            rarity: .rare,
            streakRequired: 30,
            icon: "fish.fill",
            primaryColor: Color(red: 0.6, green: 0.2, blue: 0.8),
            secondaryColor: Color(red: 0.8, green: 0.5, blue: 1.0),
            size: 0.75,
            swimSpeed: 0.6
        ),
        AquariumFish(
            id: "pufferfish",
            name: "Bubbles",
            species: "Pufferfish",
            description: "A round, spiky pufferfish who puffs up with pride. 40 days of attendance is no joke!",
            rarity: .rare,
            streakRequired: 40,
            icon: "fish.fill",
            primaryColor: Color(red: 0.3, green: 0.8, blue: 0.5),
            secondaryColor: Color(red: 0.9, green: 0.9, blue: 0.6),
            size: 1.1,
            swimSpeed: 0.7
        ),
        AquariumFish(
            id: "dolphin",
            name: "Echo",
            species: "Dolphin",
            description: "A playful dolphin that leaps through your tank! 50 days of perfect attendance unlocks this epic friend.",
            rarity: .epic,
            streakRequired: 50,
            icon: "fish.fill",
            primaryColor: Color(red: 0.4, green: 0.6, blue: 0.8),
            secondaryColor: Color(red: 0.7, green: 0.85, blue: 0.95),
            size: 1.3,
            swimSpeed: 1.5
        ),
        AquariumFish(
            id: "sea_turtle",
            name: "Shelly",
            species: "Sea Turtle",
            description: "A wise old sea turtle who has seen it all. Patience and perseverance earned you this epic creature.",
            rarity: .epic,
            streakRequired: 60,
            icon: "tortoise.fill",
            primaryColor: Color(red: 0.2, green: 0.6, blue: 0.3),
            secondaryColor: Color(red: 0.5, green: 0.4, blue: 0.2),
            size: 1.2,
            swimSpeed: 0.4
        ),
        AquariumFish(
            id: "orca",
            name: "Shadow",
            species: "Orca",
            description: "The legendary orca — apex of the ocean. 75 days of unwavering attendance calls this magnificent creature to your tank.",
            rarity: .legendary,
            streakRequired: 75,
            icon: "fish.fill",
            primaryColor: Color(red: 0.1, green: 0.1, blue: 0.15),
            secondaryColor: .white,
            size: 1.5,
            swimSpeed: 1.3
        ),
        AquariumFish(
            id: "narwhal",
            name: "Stardust",
            species: "Narwhal",
            description: "The mythical narwhal — the unicorn of the sea. Only the most dedicated students in history have earned this ultimate prize. 100 days. Legendary.",
            rarity: .mythical,
            streakRequired: 100,
            icon: "fish.fill",
            primaryColor: Color(red: 0.55, green: 0.4, blue: 0.9),
            secondaryColor: Color(red: 1.0, green: 0.84, blue: 0.0),
            size: 1.6,
            swimSpeed: 1.0
        )
    ]
    
    /// Returns the list of fish with unlock status applied based on the current streak.
    static func withUnlockStatus(currentStreak: Int) -> [AquariumFish] {
        allFish.map { fish in
            var f = fish
            f.isUnlocked = currentStreak >= fish.streakRequired
            return f
        }
    }
    
    /// Returns only the unlocked fish for the given streak.
    static func unlockedFish(currentStreak: Int) -> [AquariumFish] {
        allFish.filter { currentStreak >= $0.streakRequired }
    }
    
    /// Returns the next fish to unlock, or nil if all are unlocked.
    static func nextToUnlock(currentStreak: Int) -> AquariumFish? {
        allFish.first { currentStreak < $0.streakRequired }
    }
}
