import SwiftUI

// MARK: - Data Models

private enum MathDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case expert = "Expert"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .easy: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .hard: return "3.circle.fill"
        case .expert: return "4.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .blue
        case .hard: return .orange
        case .expert: return .red
        }
    }

    var description: String {
        switch self {
        case .easy: return "Single digit +/-"
        case .medium: return "Double digit +/-"
        case .hard: return "Multiplication & Division"
        case .expert: return "Mixed operations, larger numbers"
        }
    }

    var gradeRange: String {
        switch self {
        case .easy: return "Grades 4-5"
        case .medium: return "Grades 5-7"
        case .hard: return "Grades 7-9"
        case .expert: return "Grades 9-12"
        }
    }
}

private enum MathGameMode: String, CaseIterable, Identifiable {
    case timer = "Timed Challenge"
    case practice = "Practice Mode"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timer: return "timer"
        case .practice: return "infinity"
        }
    }
}

private enum MathOperation: String {
    case addition = "+"
    case subtraction = "-"
    case multiplication = "x"
    case division = "/"
}

private struct MathQuestion: Identifiable {
    let id = UUID()
    let operandA: Int
    let operandB: Int
    let operation: MathOperation
    let correctAnswer: Int
    var choices: [Int]

    var displayString: String {
        "\(operandA) \(operation.rawValue) \(operandB)"
    }
}

// MARK: - Question Generator

private struct MathQuestionGenerator {
    static func generate(difficulty: MathDifficulty) -> MathQuestion {
        switch difficulty {
        case .easy:
            return generateEasy()
        case .medium:
            return generateMedium()
        case .hard:
            return generateHard()
        case .expert:
            return generateExpert()
        }
    }

    private static func generateEasy() -> MathQuestion {
        let ops: [MathOperation] = [.addition, .subtraction]
        let op = ops.randomElement()!
        let a = Int.random(in: 1...9)
        let b = Int.random(in: 1...9)
        switch op {
        case .addition:
            return makeQuestion(a: a, b: b, op: .addition, answer: a + b)
        case .subtraction:
            let big = max(a, b)
            let small = min(a, b)
            return makeQuestion(a: big, b: small, op: .subtraction, answer: big - small)
        default:
            return makeQuestion(a: a, b: b, op: .addition, answer: a + b)
        }
    }

    private static func generateMedium() -> MathQuestion {
        let ops: [MathOperation] = [.addition, .subtraction]
        let op = ops.randomElement()!
        let a = Int.random(in: 10...99)
        let b = Int.random(in: 10...99)
        switch op {
        case .addition:
            return makeQuestion(a: a, b: b, op: .addition, answer: a + b)
        case .subtraction:
            let big = max(a, b)
            let small = min(a, b)
            return makeQuestion(a: big, b: small, op: .subtraction, answer: big - small)
        default:
            return makeQuestion(a: a, b: b, op: .addition, answer: a + b)
        }
    }

    private static func generateHard() -> MathQuestion {
        let ops: [MathOperation] = [.multiplication, .division]
        let op = ops.randomElement()!
        switch op {
        case .multiplication:
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            return makeQuestion(a: a, b: b, op: .multiplication, answer: a * b)
        case .division:
            let b = Int.random(in: 2...12)
            let answer = Int.random(in: 2...12)
            let a = b * answer
            return makeQuestion(a: a, b: b, op: .division, answer: answer)
        default:
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            return makeQuestion(a: a, b: b, op: .multiplication, answer: a * b)
        }
    }

    private static func generateExpert() -> MathQuestion {
        let ops: [MathOperation] = [.addition, .subtraction, .multiplication, .division]
        let op = ops.randomElement()!
        switch op {
        case .addition:
            let a = Int.random(in: 100...999)
            let b = Int.random(in: 100...999)
            return makeQuestion(a: a, b: b, op: .addition, answer: a + b)
        case .subtraction:
            let a = Int.random(in: 100...999)
            let b = Int.random(in: 100...999)
            let big = max(a, b)
            let small = min(a, b)
            return makeQuestion(a: big, b: small, op: .subtraction, answer: big - small)
        case .multiplication:
            let a = Int.random(in: 12...25)
            let b = Int.random(in: 2...15)
            return makeQuestion(a: a, b: b, op: .multiplication, answer: a * b)
        case .division:
            let b = Int.random(in: 3...15)
            let answer = Int.random(in: 5...25)
            let a = b * answer
            return makeQuestion(a: a, b: b, op: .division, answer: answer)
        }
    }

    private static func makeQuestion(a: Int, b: Int, op: MathOperation, answer: Int) -> MathQuestion {
        var choices = Set<Int>()
        choices.insert(answer)
        let spread = max(5, abs(answer) / 3 + 1)
        while choices.count < 4 {
            let offset = Int.random(in: -spread...spread)
            let wrongAnswer = answer + offset
            if wrongAnswer != answer && wrongAnswer >= 0 {
                choices.insert(wrongAnswer)
            }
        }
        return MathQuestion(
            operandA: a,
            operandB: b,
            operation: op,
            correctAnswer: answer,
            choices: choices.sorted().shuffled()
        )
    }
}

// MARK: - Main View

struct MathQuizView: View {
    // MARK: - Game State
    @State private var gamePhase: GamePhase = .menu
    @State private var difficulty: MathDifficulty = .easy
    @State private var gameMode: MathGameMode = .timer
    @State private var currentQuestion: MathQuestion = MathQuestionGenerator.generate(difficulty: .easy)
    @State private var score: Int = 0
    @State private var totalAnswered: Int = 0
    @State private var streak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var timeRemaining: Int = 60
    @State private var timerActive: Bool = false
    @State private var selectedAnswer: Int? = nil
    @State private var showFeedback: Bool = false
    @State private var isCorrect: Bool = false
    @State private var hapticTrigger: Int = 0
    @State private var wrongHapticTrigger: Int = 0
    @State private var questionScale: CGFloat = 1.0
    @State private var feedbackOpacity: Double = 0
    @State private var animateScore: Bool = false
    @State private var questionsHistory: [(question: String, userAnswer: Int, correctAnswer: Int, wasCorrect: Bool)] = []

    // MARK: - Persisted High Scores
    @AppStorage("mathQuiz_highScore_easy_timer") private var highScoreEasyTimer: Int = 0
    @AppStorage("mathQuiz_highScore_medium_timer") private var highScoreMediumTimer: Int = 0
    @AppStorage("mathQuiz_highScore_hard_timer") private var highScoreHardTimer: Int = 0
    @AppStorage("mathQuiz_highScore_expert_timer") private var highScoreExpertTimer: Int = 0
    @AppStorage("mathQuiz_totalSolved") private var totalSolvedAllTime: Int = 0
    @AppStorage("mathQuiz_bestStreak") private var bestStreakAllTime: Int = 0

    private enum GamePhase {
        case menu
        case playing
        case results
    }

    private var currentHighScore: Int {
        switch difficulty {
        case .easy: return highScoreEasyTimer
        case .medium: return highScoreMediumTimer
        case .hard: return highScoreHardTimer
        case .expert: return highScoreExpertTimer
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient

            switch gamePhase {
            case .menu:
                menuView
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case .playing:
                playingView
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
            case .results:
                resultsView
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
        .navigationTitle("Math Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .sensoryFeedback(.impact(weight: .heavy), trigger: wrongHapticTrigger)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                difficulty.color.opacity(0.15),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Menu View

    private var menuView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Math Quiz")
                        .font(.largeTitle.bold())
                    Text("Canadian Curriculum Aligned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Stats Overview
                statsOverviewCard

                // Difficulty Selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Select Difficulty", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    ForEach(MathDifficulty.allCases) { diff in
                        difficultyCard(diff)
                    }
                }

                // Mode Selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Game Mode", systemImage: "gamecontroller.fill")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        ForEach(MathGameMode.allCases) { mode in
                            modeCard(mode)
                        }
                    }
                }

                // Start Button
                Button {
                    startGame()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Start Quiz")
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [difficulty.color, difficulty.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var statsOverviewCard: some View {
        HStack(spacing: 16) {
            statBubble(title: "Solved", value: "\(totalSolvedAllTime)", icon: "checkmark.circle.fill", color: .green)
            statBubble(title: "Best Streak", value: "\(bestStreakAllTime)", icon: "flame.fill", color: .orange)
            statBubble(title: "High Score", value: "\(currentHighScore)", icon: "trophy.fill", color: .yellow)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statBubble(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func difficultyCard(_ diff: MathDifficulty) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                difficulty = diff
            }
            hapticTrigger += 1
        } label: {
            HStack(spacing: 14) {
                Image(systemName: diff.icon)
                    .font(.title2)
                    .foregroundStyle(diff.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(diff.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(diff.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(diff.gradeRange)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(diff.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(diff.color)

                if difficulty == diff {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(diff.color)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(difficulty == diff ? diff.color.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(difficulty == diff ? diff.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeCard(_ mode: MathGameMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                gameMode = mode
            }
            hapticTrigger += 1
        } label: {
            VStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.title)
                    .foregroundStyle(gameMode == mode ? .white : difficulty.color)
                Text(mode.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(gameMode == mode ? .white : .primary)
                Text(mode == .timer ? "60 seconds" : "No time limit")
                    .font(.caption2)
                    .foregroundStyle(gameMode == mode ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(gameMode == mode ?
                        AnyShapeStyle(LinearGradient(colors: [difficulty.color, difficulty.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                        AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playing View

    private var playingView: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            // Question Display
            questionDisplay
                .scaleEffect(questionScale)

            Spacer()

            // Answer Choices
            answerChoices
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .overlay {
            feedbackOverlay
        }
        .task(id: timerActive) {
            guard timerActive && gameMode == .timer else { return }
            while timerActive && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if timerActive {
                    timeRemaining -= 1
                    if timeRemaining <= 0 {
                        endGame()
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Score
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("\(score)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)
                    .scaleEffect(animateScore ? 1.3 : 1.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Streak
            if streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                        .font(.headline.bold().monospacedDigit())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Timer / Counter
            if gameMode == .timer {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(timeRemaining <= 10 ? .red : .blue)
                    Text("\(timeRemaining)s")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(timeRemaining <= 10 ? .red : .primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .animation(.easeInOut(duration: 0.3), value: timeRemaining <= 10)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundStyle(.blue)
                    Text("\(totalAnswered)")
                        .font(.title3.bold().monospacedDigit())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var questionDisplay: some View {
        VStack(spacing: 20) {
            Text(currentQuestion.displayString)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [difficulty.color, difficulty.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("= ?")
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }

    private var answerChoices: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(currentQuestion.choices, id: \.self) { choice in
                Button {
                    guard selectedAnswer == nil else { return }
                    selectAnswer(choice)
                } label: {
                    Text("\(choice)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(answerTextColor(for: choice))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(answerBackground(for: choice), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(answerBorderColor(for: choice), lineWidth: selectedAnswer == choice ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedAnswer != nil)
            }
        }
    }

    private func answerTextColor(for choice: Int) -> Color {
        guard let selected = selectedAnswer else { return .primary }
        if choice == currentQuestion.correctAnswer { return .white }
        if choice == selected { return .white }
        return .primary.opacity(0.4)
    }

    private func answerBackground(for choice: Int) -> some ShapeStyle {
        guard let selected = selectedAnswer else {
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        }
        if choice == currentQuestion.correctAnswer {
            return AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if choice == selected && choice != currentQuestion.correctAnswer {
            return AnyShapeStyle(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.4))
    }

    private func answerBorderColor(for choice: Int) -> Color {
        guard let selected = selectedAnswer else { return .clear }
        if choice == currentQuestion.correctAnswer { return .green }
        if choice == selected { return .red }
        return .clear
    }

    private var feedbackOverlay: some View {
        Group {
            if showFeedback {
                VStack {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(isCorrect ? .green : .red)
                        .symbolEffect(.bounce, value: showFeedback)

                    if isCorrect && streak > 1 {
                        Text("\(streak) Streak!")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .opacity(feedbackOpacity)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Trophy/Result Icon
                VStack(spacing: 12) {
                    let percentage = totalAnswered > 0 ? Double(score) / Double(totalAnswered) * 100 : 0

                    Image(systemName: percentage >= 80 ? "trophy.fill" : percentage >= 50 ? "star.fill" : "arrow.trianglehead.counterclockwise")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: percentage >= 80 ? [.yellow, .orange] : percentage >= 50 ? [.blue, .purple] : [.gray, .gray.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(percentage >= 80 ? "Excellent!" : percentage >= 50 ? "Good Job!" : "Keep Practicing!")
                        .font(.largeTitle.bold())

                    if gameMode == .timer {
                        let isNewHighScore = score > currentHighScore
                        if isNewHighScore {
                            Text("New High Score!")
                                .font(.headline)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.15), in: Capsule())
                        }
                    }
                }
                .padding(.top, 20)

                // Score Cards
                HStack(spacing: 12) {
                    resultStatCard(title: "Score", value: "\(score)/\(totalAnswered)", icon: "checkmark.circle.fill", color: .green)
                    resultStatCard(title: "Best Streak", value: "\(bestStreak)", icon: "flame.fill", color: .orange)
                    if gameMode == .timer {
                        resultStatCard(title: "Per Min", value: "\(totalAnswered)", icon: "bolt.fill", color: .blue)
                    }
                }
                .padding(.horizontal)

                // Accuracy Ring
                let accuracy = totalAnswered > 0 ? Double(score) / Double(totalAnswered) : 0
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(difficulty.color.opacity(0.2), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: accuracy)
                            .stroke(
                                LinearGradient(colors: [difficulty.color, difficulty.color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(Int(accuracy * 100))%")
                                .font(.title.bold().monospacedDigit())
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Question Review
                if !questionsHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Question Review")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(Array(questionsHistory.suffix(10).enumerated()), id: \.offset) { index, item in
                            HStack {
                                Image(systemName: item.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(item.wasCorrect ? .green : .red)
                                Text(item.question)
                                    .font(.subheadline)
                                Spacer()
                                if !item.wasCorrect {
                                    Text("Your: \(item.userAnswer)")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Text("Ans: \(item.correctAnswer)")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("= \(item.correctAnswer)")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        startGame()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Play Again")
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [difficulty.color, difficulty.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            gamePhase = .menu
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                            Text("Back to Menu")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func resultStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func startGame() {
        score = 0
        totalAnswered = 0
        streak = 0
        bestStreak = 0
        timeRemaining = 60
        selectedAnswer = nil
        showFeedback = false
        questionsHistory = []
        currentQuestion = MathQuestionGenerator.generate(difficulty: difficulty)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            gamePhase = .playing
        }

        if gameMode == .timer {
            timerActive = true
        }
    }

    private func selectAnswer(_ choice: Int) {
        selectedAnswer = choice
        let correct = choice == currentQuestion.correctAnswer
        isCorrect = correct

        if correct {
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            hapticTrigger += 1
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                animateScore = true
            }
        } else {
            streak = 0
            wrongHapticTrigger += 1
        }

        totalAnswered += 1

        questionsHistory.append((
            question: currentQuestion.displayString,
            userAnswer: choice,
            correctAnswer: currentQuestion.correctAnswer,
            wasCorrect: correct
        ))

        withAnimation(.easeOut(duration: 0.2)) {
            showFeedback = true
            feedbackOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.2)) {
                feedbackOpacity = 0
                animateScore = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showFeedback = false
                selectedAnswer = nil
                currentQuestion = MathQuestionGenerator.generate(difficulty: difficulty)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    questionScale = 0.9
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.05)) {
                    questionScale = 1.0
                }
            }
        }
    }

    private func endGame() {
        timerActive = false

        // Update persisted stats
        totalSolvedAllTime += score
        if bestStreak > bestStreakAllTime {
            bestStreakAllTime = bestStreak
        }

        if gameMode == .timer {
            switch difficulty {
            case .easy:
                if score > highScoreEasyTimer { highScoreEasyTimer = score }
            case .medium:
                if score > highScoreMediumTimer { highScoreMediumTimer = score }
            case .hard:
                if score > highScoreHardTimer { highScoreHardTimer = score }
            case .expert:
                if score > highScoreExpertTimer { highScoreExpertTimer = score }
            }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gamePhase = .results
        }
    }
}

// MARK: - Practice Mode End Button Extension

private struct PracticeModeEndButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                Text("End Practice")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1), in: Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MathQuizView()
    }
}
