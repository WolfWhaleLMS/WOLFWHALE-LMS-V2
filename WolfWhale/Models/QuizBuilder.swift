import Foundation

// MARK: - Question Type

nonisolated enum QuestionType: String, Codable, CaseIterable, Sendable {
    case multipleChoice = "multiple_choice"
    case trueFalse = "true_false"
    case shortAnswer = "short_answer"
    case fillInBlank = "fill_in_blank"
    case matching = "matching"
    case essay = "essay"

    var displayName: String {
        switch self {
        case .multipleChoice: "Multiple Choice"
        case .trueFalse: "True / False"
        case .shortAnswer: "Short Answer"
        case .fillInBlank: "Fill in the Blank"
        case .matching: "Matching"
        case .essay: "Essay"
        }
    }

    var iconName: String {
        switch self {
        case .multipleChoice: "list.bullet.circle.fill"
        case .trueFalse: "checkmark.circle.fill"
        case .shortAnswer: "text.bubble.fill"
        case .fillInBlank: "rectangle.and.pencil.and.ellipsis"
        case .matching: "arrow.left.arrow.right"
        case .essay: "doc.text.fill"
        }
    }

    /// Maps to the view-facing QuizQuestionType for the Quiz model.
    var quizQuestionType: QuizQuestionType {
        switch self {
        case .multipleChoice: .multipleChoice
        case .trueFalse: .trueFalse
        case .shortAnswer: .fillInBlank   // treat short answer as fill-in for grading
        case .fillInBlank: .fillInBlank
        case .matching: .matching
        case .essay: .essay
        }
    }
}

// MARK: - Matching Pair Draft

nonisolated struct MatchingPairDraft: Identifiable, Sendable {
    let id: UUID
    var prompt: String
    var answer: String

    init(id: UUID = UUID(), prompt: String = "", answer: String = "") {
        self.id = id
        self.prompt = prompt
        self.answer = answer
    }
}

// MARK: - Quiz Draft

nonisolated struct QuizDraft: Identifiable, Sendable {
    let id: UUID
    var title: String
    var description: String
    var courseId: UUID?
    var timeLimitMinutes: Int?          // nil = no limit
    var pointsPerQuestion: Int
    var passingScorePercent: Int        // 0-100
    var allowedAttempts: Int            // 0 = unlimited
    var shuffleQuestions: Bool
    var shuffleOptions: Bool
    var showResultsImmediately: Bool
    var questions: [QuestionDraft]

    var totalPoints: Int {
        questions.reduce(0) { $0 + $1.points }
    }

    var isValid: Bool {
        let titleOK = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let hasQuestions = !questions.isEmpty
        let questionsOK = questions.allSatisfy { $0.isValid }
        let hasCourse = courseId != nil
        return titleOK && hasQuestions && questionsOK && hasCourse
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        courseId: UUID? = nil,
        timeLimitMinutes: Int? = nil,
        pointsPerQuestion: Int = 10,
        passingScorePercent: Int = 60,
        allowedAttempts: Int = 1,
        shuffleQuestions: Bool = false,
        shuffleOptions: Bool = false,
        showResultsImmediately: Bool = true,
        questions: [QuestionDraft] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.courseId = courseId
        self.timeLimitMinutes = timeLimitMinutes
        self.pointsPerQuestion = pointsPerQuestion
        self.passingScorePercent = passingScorePercent
        self.allowedAttempts = allowedAttempts
        self.shuffleQuestions = shuffleQuestions
        self.shuffleOptions = shuffleOptions
        self.showResultsImmediately = showResultsImmediately
        self.questions = questions
    }
}

// MARK: - Question Draft

nonisolated struct QuestionDraft: Identifiable, Sendable {
    let id: UUID
    var text: String
    var type: QuestionType
    var points: Int
    var options: [OptionDraft]          // For MC and T/F
    var correctAnswers: [String]        // For short answer / fill-in
    var matchingPairs: [MatchingPairDraft]  // For matching questions
    var essayPrompt: String             // Additional essay instructions
    var essayMinWords: Int              // Minimum word count for essay
    var explanation: String             // Shown after answering
    var caseInsensitive: Bool
    var allowPartialMatch: Bool

    var isValid: Bool {
        let textOK = !text.trimmingCharacters(in: .whitespaces).isEmpty
        switch type {
        case .multipleChoice:
            let optionsOK = options.count >= 2
                && options.allSatisfy { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            let hasCorrect = options.contains(where: \.isCorrect)
            return textOK && optionsOK && hasCorrect
        case .trueFalse:
            let hasCorrect = options.contains(where: \.isCorrect)
            return textOK && hasCorrect
        case .shortAnswer:
            return textOK && !correctAnswers.isEmpty
                && correctAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .fillInBlank:
            let hasBlanks = text.contains("___")
            return textOK && hasBlanks && !correctAnswers.isEmpty
                && correctAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .matching:
            return textOK && matchingPairs.count >= 2
                && matchingPairs.allSatisfy {
                    !$0.prompt.trimmingCharacters(in: .whitespaces).isEmpty
                    && !$0.answer.trimmingCharacters(in: .whitespaces).isEmpty
                }
        case .essay:
            return textOK
        }
    }

    init(
        id: UUID = UUID(),
        text: String = "",
        type: QuestionType = .multipleChoice,
        points: Int = 10,
        options: [OptionDraft]? = nil,
        correctAnswers: [String] = [],
        matchingPairs: [MatchingPairDraft] = [],
        essayPrompt: String = "",
        essayMinWords: Int = 50,
        explanation: String = "",
        caseInsensitive: Bool = true,
        allowPartialMatch: Bool = false
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.points = points
        self.correctAnswers = correctAnswers
        self.matchingPairs = matchingPairs
        self.essayPrompt = essayPrompt
        self.essayMinWords = essayMinWords
        self.explanation = explanation
        self.caseInsensitive = caseInsensitive
        self.allowPartialMatch = allowPartialMatch

        if let options {
            self.options = options
        } else {
            switch type {
            case .multipleChoice:
                self.options = [
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false)
                ]
            case .trueFalse:
                self.options = [
                    OptionDraft(text: "True", isCorrect: true),
                    OptionDraft(text: "False", isCorrect: false)
                ]
            case .shortAnswer, .fillInBlank:
                self.options = []
            case .matching:
                self.options = []
                if matchingPairs.isEmpty {
                    self.matchingPairs = [
                        MatchingPairDraft(),
                        MatchingPairDraft(),
                        MatchingPairDraft()
                    ]
                }
            case .essay:
                self.options = []
            }
        }
    }

    /// Creates a duplicate with a new ID (and new IDs for child options).
    func duplicate() -> QuestionDraft {
        QuestionDraft(
            id: UUID(),
            text: text,
            type: type,
            points: points,
            options: options.map { OptionDraft(text: $0.text, isCorrect: $0.isCorrect) },
            correctAnswers: correctAnswers,
            matchingPairs: matchingPairs.map { MatchingPairDraft(prompt: $0.prompt, answer: $0.answer) },
            essayPrompt: essayPrompt,
            essayMinWords: essayMinWords,
            explanation: explanation,
            caseInsensitive: caseInsensitive,
            allowPartialMatch: allowPartialMatch
        )
    }
}

// MARK: - Option Draft

nonisolated struct OptionDraft: Identifiable, Sendable {
    let id: UUID
    var text: String
    var isCorrect: Bool

    init(id: UUID = UUID(), text: String = "", isCorrect: Bool = false) {
        self.id = id
        self.text = text
        self.isCorrect = isCorrect
    }
}
