import Foundation

nonisolated struct ARResource: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
    let category: ARResourceCategory
    let subject: ARSubject
    let iconSystemName: String
    let colorName: String
    let experienceType: ARExperienceType
    let tags: [String]
    let gradeLevel: String
    let estimatedDuration: Int
    let linkedLessonKeywords: [String]
}

nonisolated enum ARResourceCategory: String, CaseIterable, Sendable, Hashable {
    case biology = "Biology"
    case history = "History"
    case geography = "Geography"
    case chemistry = "Chemistry"
    case physics = "Physics"
    case astronomy = "Astronomy"
    case anatomy = "Anatomy"
    case ecology = "Ecology"

    var iconName: String {
        switch self {
        case .biology: "leaf.fill"
        case .history: "building.columns.fill"
        case .geography: "globe.americas.fill"
        case .chemistry: "flask.fill"
        case .physics: "atom"
        case .astronomy: "moon.stars.fill"
        case .anatomy: "figure.stand"
        case .ecology: "tree.fill"
        }
    }

    var colorName: String {
        switch self {
        case .biology: "green"
        case .history: "orange"
        case .geography: "blue"
        case .chemistry: "purple"
        case .physics: "indigo"
        case .astronomy: "cyan"
        case .anatomy: "red"
        case .ecology: "mint"
        }
    }
}

nonisolated enum ARSubject: String, CaseIterable, Sendable, Hashable {
    case science = "Science"
    case socialStudies = "Social Studies"
    case math = "Mathematics"
    case art = "Art"
}

nonisolated enum ARExperienceType: String, Sendable, Hashable {
    case humanCell = "human_cell"
    case placeholder = "placeholder"
}

nonisolated struct CellOrganelle: Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let funFact: String
    let colorHex: UInt
    let relativePosition: SIMD3<Float>
    let size: SIMD3<Float>
    let shape: OrganelleShape
}

nonisolated enum OrganelleShape: String, Sendable, Hashable {
    case sphere
    case ellipsoid
    case cylinder
    case flatDisc
    case tinyDots
}
