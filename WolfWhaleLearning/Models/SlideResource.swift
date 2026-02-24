import Foundation

/// Represents a resource/tool attached to a specific lesson slide.
nonisolated struct SlideResource: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var slideIndex: Int
    var resourceTitle: String
    var resourceIcon: String
    var colorName: String

    init(id: UUID = UUID(), slideIndex: Int, resourceTitle: String, resourceIcon: String, colorName: String = "purple") {
        self.id = id
        self.slideIndex = slideIndex
        self.resourceTitle = resourceTitle
        self.resourceIcon = resourceIcon
        self.colorName = colorName
    }
}

/// Available resources that teachers can attach to slides
enum AttachableResource: String, CaseIterable, Identifiable, Sendable {
    // Study Tools
    case flashcardCreator = "Flashcard Creator"
    case unitConverter = "Unit Converter"
    case typingTutor = "Typing Tutor"
    case aiStudyAssistant = "AI Study Assistant"
    // Math
    case mathQuiz = "Math Quiz"
    case fractionBuilder = "Fraction Builder"
    case geometryExplorer = "Geometry Explorer"
    // Science
    case periodicTable = "Periodic Table"
    case humanBody = "Human Body"
    // English
    case wordBuilder = "Word Builder"
    case spellingBee = "Spelling Bee"
    case grammarQuest = "Grammar Quest"
    // French
    case frenchVocab = "French Vocab"
    case frenchVerbs = "French Verbs"
    // Canadian Studies
    case canadianHistory = "Canadian History"
    case canadianGeography = "Canadian Geography"
    case indigenousPeoples = "Indigenous Peoples"
    // Geography
    case worldMapQuiz = "World Map Quiz"
    // Games
    case chess = "Chess"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .flashcardCreator: "rectangle.on.rectangle.angled"
        case .unitConverter: "arrow.left.arrow.right"
        case .typingTutor: "keyboard.fill"
        case .aiStudyAssistant: "sparkles"
        case .mathQuiz: "function"
        case .fractionBuilder: "circle.lefthalf.filled"
        case .geometryExplorer: "triangle.fill"
        case .periodicTable: "tablecells.fill"
        case .humanBody: "figure.stand"
        case .wordBuilder: "textformat.abc"
        case .spellingBee: "textformat"
        case .grammarQuest: "text.book.closed.fill"
        case .frenchVocab: "character.book.closed.fill"
        case .frenchVerbs: "text.word.spacing"
        case .canadianHistory: "clock.arrow.circlepath"
        case .canadianGeography: "map.fill"
        case .indigenousPeoples: "leaf.fill"
        case .worldMapQuiz: "globe.desk.fill"
        case .chess: "crown.fill"
        }
    }

    var category: String {
        switch self {
        case .flashcardCreator, .unitConverter, .typingTutor, .aiStudyAssistant: "Study Tools"
        case .mathQuiz, .fractionBuilder, .geometryExplorer: "Mathematics"
        case .periodicTable, .humanBody: "Science"
        case .wordBuilder, .spellingBee, .grammarQuest: "English"
        case .frenchVocab, .frenchVerbs: "French"
        case .canadianHistory, .canadianGeography, .indigenousPeoples: "Canadian Studies"
        case .worldMapQuiz: "Geography"
        case .chess: "Games"
        }
    }
}
