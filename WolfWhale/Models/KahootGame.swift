import SwiftUI

// MARK: - Kahoot Question

struct KahootQuestion: Identifiable, Sendable {
    let id: UUID
    let questionText: String
    let answers: [KahootAnswer]
    let timeLimit: Int // seconds (default 20)
    let pointsBase: Int // base points (default 1000)
    let imageSystemName: String? // optional SF Symbol for the question

    init(
        id: UUID = UUID(),
        questionText: String,
        answers: [KahootAnswer],
        timeLimit: Int = 20,
        pointsBase: Int = 1000,
        imageSystemName: String? = nil
    ) {
        self.id = id
        self.questionText = questionText
        self.answers = answers
        self.timeLimit = timeLimit
        self.pointsBase = pointsBase
        self.imageSystemName = imageSystemName
    }
}

struct KahootAnswer: Identifiable, Sendable {
    let id: UUID
    let text: String
    let isCorrect: Bool

    init(id: UUID = UUID(), text: String, isCorrect: Bool) {
        self.id = id
        self.text = text
        self.isCorrect = isCorrect
    }
}

// MARK: - Game State

enum KahootGamePhase: Sendable {
    case lobby          // waiting to start, showing quiz info
    case countdown      // 3-2-1 countdown before question
    case question       // timer running, showing question + answers
    case answerReveal   // showing correct answer + streak info
    case leaderboard    // showing standings between questions
    case results        // final results screen
}

// MARK: - Player Result

struct KahootPlayerResult: Identifiable, Sendable {
    let id = UUID()
    var totalScore: Int = 0
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var streak: Int = 0
    var bestStreak: Int = 0
    var averageTime: Double = 0.0
    var answerTimes: [Double] = []
}

// MARK: - Answer Color/Shape (Kahoot classic 4-shape layout)

enum KahootAnswerStyle: Int, CaseIterable {
    case triangle = 0   // Red triangle
    case diamond = 1    // Blue diamond
    case circle = 2     // Orange circle
    case square = 3     // Green square

    var color: Color {
        switch self {
        case .triangle: Color(red: 0.89, green: 0.18, blue: 0.18) // Kahoot red
        case .diamond: Color(red: 0.15, green: 0.42, blue: 0.84)  // Kahoot blue
        case .circle: Color(red: 0.85, green: 0.55, blue: 0.0)    // Kahoot orange/yellow
        case .square: Color(red: 0.15, green: 0.68, blue: 0.25)   // Kahoot green
        }
    }

    var iconName: String {
        switch self {
        case .triangle: "triangle.fill"
        case .diamond: "diamond.fill"
        case .circle: "circle.fill"
        case .square: "square.fill"
        }
    }
}

// MARK: - Quiz Packs (built-in sample quizzes)

struct KahootQuizPack: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let category: String
    let icon: String
    let color: Color
    let questions: [KahootQuestion]

    var questionCount: Int { questions.count }

    init(id: UUID = UUID(), title: String, description: String, category: String, icon: String, color: Color, questions: [KahootQuestion]) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.questions = questions
    }
}

// MARK: - Sample Quiz Packs

extension KahootQuizPack {
    static let samplePacks: [KahootQuizPack] = [
        // Math quiz
        KahootQuizPack(
            title: "Math Mania",
            description: "Test your math skills with quick-fire questions!",
            category: "Mathematics",
            icon: "function",
            color: .green,
            questions: [
                KahootQuestion(questionText: "What is 7 \u{00D7} 8?", answers: [
                    KahootAnswer(text: "54", isCorrect: false),
                    KahootAnswer(text: "56", isCorrect: true),
                    KahootAnswer(text: "58", isCorrect: false),
                    KahootAnswer(text: "48", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is the square root of 144?", answers: [
                    KahootAnswer(text: "14", isCorrect: false),
                    KahootAnswer(text: "11", isCorrect: false),
                    KahootAnswer(text: "12", isCorrect: true),
                    KahootAnswer(text: "13", isCorrect: false),
                ]),
                KahootQuestion(questionText: "Which number is prime?", answers: [
                    KahootAnswer(text: "15", isCorrect: false),
                    KahootAnswer(text: "21", isCorrect: false),
                    KahootAnswer(text: "23", isCorrect: true),
                    KahootAnswer(text: "25", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is 15% of 200?", answers: [
                    KahootAnswer(text: "25", isCorrect: false),
                    KahootAnswer(text: "30", isCorrect: true),
                    KahootAnswer(text: "35", isCorrect: false),
                    KahootAnswer(text: "20", isCorrect: false),
                ]),
                KahootQuestion(questionText: "Solve: 3x + 5 = 20. What is x?", answers: [
                    KahootAnswer(text: "3", isCorrect: false),
                    KahootAnswer(text: "7", isCorrect: false),
                    KahootAnswer(text: "5", isCorrect: true),
                    KahootAnswer(text: "4", isCorrect: false),
                ]),
                KahootQuestion(questionText: "How many degrees in a triangle?", answers: [
                    KahootAnswer(text: "360\u{00B0}", isCorrect: false),
                    KahootAnswer(text: "180\u{00B0}", isCorrect: true),
                    KahootAnswer(text: "90\u{00B0}", isCorrect: false),
                    KahootAnswer(text: "270\u{00B0}", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is 2\u{2075} (2 to the 5th power)?", answers: [
                    KahootAnswer(text: "10", isCorrect: false),
                    KahootAnswer(text: "25", isCorrect: false),
                    KahootAnswer(text: "32", isCorrect: true),
                    KahootAnswer(text: "64", isCorrect: false),
                ]),
            ]
        ),

        // Science quiz
        KahootQuizPack(
            title: "Science Showdown",
            description: "How well do you know science? Let's find out!",
            category: "Science",
            icon: "atom",
            color: .orange,
            questions: [
                KahootQuestion(questionText: "What is the chemical symbol for water?", answers: [
                    KahootAnswer(text: "O2", isCorrect: false),
                    KahootAnswer(text: "H2O", isCorrect: true),
                    KahootAnswer(text: "CO2", isCorrect: false),
                    KahootAnswer(text: "HO", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What planet is known as the Red Planet?", answers: [
                    KahootAnswer(text: "Venus", isCorrect: false),
                    KahootAnswer(text: "Jupiter", isCorrect: false),
                    KahootAnswer(text: "Mars", isCorrect: true),
                    KahootAnswer(text: "Saturn", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What gas do plants absorb from the air?", answers: [
                    KahootAnswer(text: "Oxygen", isCorrect: false),
                    KahootAnswer(text: "Nitrogen", isCorrect: false),
                    KahootAnswer(text: "Hydrogen", isCorrect: false),
                    KahootAnswer(text: "Carbon Dioxide", isCorrect: true),
                ]),
                KahootQuestion(questionText: "What is the hardest natural substance on Earth?", answers: [
                    KahootAnswer(text: "Gold", isCorrect: false),
                    KahootAnswer(text: "Iron", isCorrect: false),
                    KahootAnswer(text: "Diamond", isCorrect: true),
                    KahootAnswer(text: "Platinum", isCorrect: false),
                ]),
                KahootQuestion(questionText: "How many bones are in the adult human body?", answers: [
                    KahootAnswer(text: "206", isCorrect: true),
                    KahootAnswer(text: "186", isCorrect: false),
                    KahootAnswer(text: "256", isCorrect: false),
                    KahootAnswer(text: "196", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What force keeps us on the ground?", answers: [
                    KahootAnswer(text: "Magnetism", isCorrect: false),
                    KahootAnswer(text: "Friction", isCorrect: false),
                    KahootAnswer(text: "Gravity", isCorrect: true),
                    KahootAnswer(text: "Inertia", isCorrect: false),
                ]),
            ]
        ),

        // Canadian History quiz
        KahootQuizPack(
            title: "Canadian History Challenge",
            description: "Test your knowledge of Canadian history!",
            category: "Canadian Studies",
            icon: "mappin.and.ellipse",
            color: .red,
            questions: [
                KahootQuestion(questionText: "In what year did Canada become a country?", answers: [
                    KahootAnswer(text: "1776", isCorrect: false),
                    KahootAnswer(text: "1867", isCorrect: true),
                    KahootAnswer(text: "1812", isCorrect: false),
                    KahootAnswer(text: "1901", isCorrect: false),
                ]),
                KahootQuestion(questionText: "Who was Canada's first Prime Minister?", answers: [
                    KahootAnswer(text: "Wilfrid Laurier", isCorrect: false),
                    KahootAnswer(text: "John A. Macdonald", isCorrect: true),
                    KahootAnswer(text: "Alexander Mackenzie", isCorrect: false),
                    KahootAnswer(text: "Robert Borden", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is the national animal of Canada?", answers: [
                    KahootAnswer(text: "Moose", isCorrect: false),
                    KahootAnswer(text: "Polar Bear", isCorrect: false),
                    KahootAnswer(text: "Beaver", isCorrect: true),
                    KahootAnswer(text: "Bald Eagle", isCorrect: false),
                ]),
                KahootQuestion(questionText: "Which Canadian beach was stormed on D-Day?", answers: [
                    KahootAnswer(text: "Omaha Beach", isCorrect: false),
                    KahootAnswer(text: "Juno Beach", isCorrect: true),
                    KahootAnswer(text: "Gold Beach", isCorrect: false),
                    KahootAnswer(text: "Sword Beach", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What year was the Canadian flag adopted?", answers: [
                    KahootAnswer(text: "1867", isCorrect: false),
                    KahootAnswer(text: "1965", isCorrect: true),
                    KahootAnswer(text: "1949", isCorrect: false),
                    KahootAnswer(text: "1982", isCorrect: false),
                ]),
                KahootQuestion(questionText: "Which province was the last to join Confederation?", answers: [
                    KahootAnswer(text: "BC", isCorrect: false),
                    KahootAnswer(text: "PEI", isCorrect: false),
                    KahootAnswer(text: "Newfoundland", isCorrect: true),
                    KahootAnswer(text: "Alberta", isCorrect: false),
                ]),
            ]
        ),

        // General Knowledge quiz
        KahootQuizPack(
            title: "General Knowledge Blast",
            description: "Random fun facts and trivia!",
            category: "General",
            icon: "brain.head.profile.fill",
            color: .purple,
            questions: [
                KahootQuestion(questionText: "How many continents are there?", answers: [
                    KahootAnswer(text: "5", isCorrect: false),
                    KahootAnswer(text: "6", isCorrect: false),
                    KahootAnswer(text: "7", isCorrect: true),
                    KahootAnswer(text: "8", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is the largest ocean on Earth?", answers: [
                    KahootAnswer(text: "Atlantic", isCorrect: false),
                    KahootAnswer(text: "Pacific", isCorrect: true),
                    KahootAnswer(text: "Indian", isCorrect: false),
                    KahootAnswer(text: "Arctic", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What language has the most native speakers?", answers: [
                    KahootAnswer(text: "English", isCorrect: false),
                    KahootAnswer(text: "Spanish", isCorrect: false),
                    KahootAnswer(text: "Mandarin Chinese", isCorrect: true),
                    KahootAnswer(text: "Hindi", isCorrect: false),
                ]),
                KahootQuestion(questionText: "How many strings does a standard guitar have?", answers: [
                    KahootAnswer(text: "4", isCorrect: false),
                    KahootAnswer(text: "5", isCorrect: false),
                    KahootAnswer(text: "6", isCorrect: true),
                    KahootAnswer(text: "8", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is the currency of Japan?", answers: [
                    KahootAnswer(text: "Won", isCorrect: false),
                    KahootAnswer(text: "Yuan", isCorrect: false),
                    KahootAnswer(text: "Yen", isCorrect: true),
                    KahootAnswer(text: "Ringgit", isCorrect: false),
                ]),
            ]
        ),

        // French Language quiz
        KahootQuizPack(
            title: "French Vocabulary Sprint",
            description: "Parlez-vous fran\u{00E7}ais? Test your French!",
            category: "French",
            icon: "globe.europe.africa.fill",
            color: .blue,
            questions: [
                KahootQuestion(questionText: "What does 'bonjour' mean in English?", answers: [
                    KahootAnswer(text: "Goodbye", isCorrect: false),
                    KahootAnswer(text: "Hello / Good day", isCorrect: true),
                    KahootAnswer(text: "Thank you", isCorrect: false),
                    KahootAnswer(text: "Please", isCorrect: false),
                ]),
                KahootQuestion(questionText: "How do you say 'cat' in French?", answers: [
                    KahootAnswer(text: "Chien", isCorrect: false),
                    KahootAnswer(text: "Chat", isCorrect: true),
                    KahootAnswer(text: "Oiseau", isCorrect: false),
                    KahootAnswer(text: "Poisson", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What color is 'rouge' in English?", answers: [
                    KahootAnswer(text: "Blue", isCorrect: false),
                    KahootAnswer(text: "Green", isCorrect: false),
                    KahootAnswer(text: "Red", isCorrect: true),
                    KahootAnswer(text: "Yellow", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What number is 'vingt' in English?", answers: [
                    KahootAnswer(text: "10", isCorrect: false),
                    KahootAnswer(text: "15", isCorrect: false),
                    KahootAnswer(text: "20", isCorrect: true),
                    KahootAnswer(text: "25", isCorrect: false),
                ]),
                KahootQuestion(questionText: "What is 'merci beaucoup'?", answers: [
                    KahootAnswer(text: "You're welcome", isCorrect: false),
                    KahootAnswer(text: "Excuse me", isCorrect: false),
                    KahootAnswer(text: "Thank you very much", isCorrect: true),
                    KahootAnswer(text: "See you later", isCorrect: false),
                ]),
            ]
        ),
    ]
}

// MARK: - Kahoot Game Engine

@MainActor @Observable
final class KahootGameEngine {
    // Game state
    var phase: KahootGamePhase = .lobby
    var currentQuestionIndex: Int = 0
    var timeRemaining: Int = 20
    var countdownValue: Int = 3
    var selectedAnswerId: UUID?
    var playerResult = KahootPlayerResult()
    var quizPack: KahootQuizPack?

    // Derived
    var currentQuestion: KahootQuestion? {
        guard let pack = quizPack,
              currentQuestionIndex < pack.questions.count else { return nil }
        return pack.questions[currentQuestionIndex]
    }

    var isLastQuestion: Bool {
        guard let pack = quizPack else { return true }
        return currentQuestionIndex >= pack.questions.count - 1
    }

    var progressFraction: Double {
        guard let pack = quizPack, !pack.questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(pack.questions.count)
    }

    var timeFraction: Double {
        guard let q = currentQuestion, q.timeLimit > 0 else { return 0 }
        return Double(timeRemaining) / Double(q.timeLimit)
    }

    nonisolated(unsafe) private var timer: Timer?
    private var questionStartTime: Date?

    // MARK: - Start Game

    func startGame(with pack: KahootQuizPack) {
        quizPack = pack
        currentQuestionIndex = 0
        playerResult = KahootPlayerResult()
        selectedAnswerId = nil
        startCountdown()
    }

    // MARK: - Countdown

    func startCountdown() {
        phase = .countdown
        countdownValue = 3
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let engine = self
            Task { @MainActor in
                guard let engine else { return }
                if engine.countdownValue > 1 {
                    engine.countdownValue -= 1
                } else {
                    engine.timer?.invalidate()
                    engine.startQuestion()
                }
            }
        }
    }

    // MARK: - Start Question

    func startQuestion() {
        guard let question = currentQuestion else { return }
        phase = .question
        timeRemaining = question.timeLimit
        selectedAnswerId = nil
        questionStartTime = Date()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let engine = self
            Task { @MainActor in
                guard let engine else { return }
                if engine.timeRemaining > 0 {
                    engine.timeRemaining -= 1
                } else {
                    // Time's up — treat as wrong answer
                    engine.timer?.invalidate()
                    engine.handleTimeout()
                }
            }
        }
    }

    // MARK: - Submit Answer

    func submitAnswer(_ answerId: UUID) {
        guard phase == .question, selectedAnswerId == nil else { return }
        timer?.invalidate()
        selectedAnswerId = answerId

        let timeTaken = questionStartTime.map { Date().timeIntervalSince($0) } ?? Double(currentQuestion?.timeLimit ?? 20)
        playerResult.answerTimes.append(timeTaken)

        if let question = currentQuestion,
           let answer = question.answers.first(where: { $0.id == answerId }) {
            if answer.isCorrect {
                // Calculate score: faster = more points
                let maxPoints = question.pointsBase
                let timeFraction = max(0, Double(timeRemaining)) / Double(question.timeLimit)
                let points = Int(Double(maxPoints) * (0.5 + 0.5 * timeFraction))
                let streakBonus = min(playerResult.streak, 5) * 100

                playerResult.totalScore += points + streakBonus
                playerResult.correctCount += 1
                playerResult.streak += 1
                playerResult.bestStreak = max(playerResult.bestStreak, playerResult.streak)
            } else {
                playerResult.incorrectCount += 1
                playerResult.streak = 0
            }
        }

        // Update average time
        let totalTime = playerResult.answerTimes.reduce(0, +)
        playerResult.averageTime = totalTime / Double(playerResult.answerTimes.count)

        // Show answer reveal
        withAnimation(.spring(duration: 0.3)) {
            phase = .answerReveal
        }
    }

    // MARK: - Timeout

    private func handleTimeout() {
        playerResult.incorrectCount += 1
        playerResult.streak = 0
        playerResult.answerTimes.append(Double(currentQuestion?.timeLimit ?? 20))

        let totalTime = playerResult.answerTimes.reduce(0, +)
        playerResult.averageTime = totalTime / Double(playerResult.answerTimes.count)

        withAnimation(.spring(duration: 0.3)) {
            phase = .answerReveal
        }
    }

    // MARK: - Next Question

    func nextQuestion() {
        if isLastQuestion {
            withAnimation(.spring(duration: 0.4)) {
                phase = .results
            }
        } else {
            currentQuestionIndex += 1
            selectedAnswerId = nil
            startCountdown()
        }
    }

    // MARK: - Show Leaderboard (between questions)

    func showLeaderboard() {
        withAnimation(.spring(duration: 0.3)) {
            phase = .leaderboard
        }
    }

    // MARK: - Reset

    func reset() {
        timer?.invalidate()
        phase = .lobby
        currentQuestionIndex = 0
        timeRemaining = 20
        countdownValue = 3
        selectedAnswerId = nil
        playerResult = KahootPlayerResult()
        quizPack = nil
    }

    deinit {
        timer?.invalidate()
    }
}
