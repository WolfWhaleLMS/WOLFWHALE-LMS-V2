import SwiftUI

// MARK: - Quiz Mode

struct VocabQuizModeView: View {
    @Binding var category: VocabCategory
    @State private var direction: QuizDirection = .frenchToEnglish
    @State private var currentWordIndex = 0
    @State private var options: [String] = []
    @State private var selectedAnswer: String?
    @State private var isCorrect: Bool?
    @State private var score = 0
    @State private var totalAttempts = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var quizWords: [FrenchWord] = []
    @State private var showResults = false

    var body: some View {
        if showResults {
            quizResultsView
        } else if quizWords.isEmpty {
            quizSetupView
        } else {
            quizPlayView
        }
    }

    private var quizSetupView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [category.color1, category.color2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Quiz Mode")
                .font(.title.bold())

            VStack(spacing: 12) {
                Text("Translation Direction")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Picker("Direction", selection: $direction) {
                    Text("French -> English").tag(QuizDirection.frenchToEnglish)
                    Text("English -> French").tag(QuizDirection.englishToFrench)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
            }

            Button {
                startQuiz()
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [category.color1, category.color2],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }

            Spacer()
        }
        .padding()
    }

    private var quizPlayView: some View {
        VStack(spacing: 20) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Streak: \(streak)")
                        .font(.subheadline.bold().monospacedDigit())
                }

                Spacer()

                Text("Q\(currentWordIndex + 1)/\(quizWords.count)")
                    .font(.subheadline.bold())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(score)/\(totalAttempts)")
                        .font(.subheadline.bold().monospacedDigit())
                }
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [category.color1, category.color2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * (Double(currentWordIndex + 1) / Double(quizWords.count)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            Spacer()

            let word = quizWords[currentWordIndex]
            VStack(spacing: 12) {
                Text(direction == .frenchToEnglish ? "What does this mean?" : "How do you say this in French?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(direction == .frenchToEnglish ? word.french : word.english)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                if direction == .frenchToEnglish {
                    Text(word.phonetic)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Spacer()

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    quizOptionButton(option: option)
                }
            }
            .padding(.horizontal)

            if selectedAnswer != nil {
                Button {
                    nextQuestion()
                } label: {
                    Text(currentWordIndex < quizWords.count - 1 ? "Next Question" : "See Results")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [category.color1, category.color2],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 8)
        }
    }

    private func quizOptionButton(option: String) -> some View {
        let word = quizWords[currentWordIndex]
        let correctAnswer = direction == .frenchToEnglish ? word.english : word.french
        let isSelected = selectedAnswer == option
        let isTheCorrectOne = option == correctAnswer
        let hasAnswered = selectedAnswer != nil

        return Button {
            guard selectedAnswer == nil else { return }
            selectedAnswer = option
            totalAttempts += 1

            if option == correctAnswer {
                score += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
            } else {
                streak = 0
                if let idx = category.words.firstIndex(where: { $0.id == word.id }) {
                    category.words[idx].wrongCount += 1
                }
            }
        } label: {
            HStack {
                Text(option)
                    .font(.body.bold())
                    .foregroundStyle(
                        hasAnswered
                            ? (isTheCorrectOne ? .green : (isSelected ? .red : .primary))
                            : .primary
                    )

                Spacer()

                if hasAnswered {
                    if isTheCorrectOne {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        hasAnswered
                            ? (isTheCorrectOne ? Color.green.opacity(0.1) : (isSelected ? Color.red.opacity(0.1) : .clear))
                            : .clear
                    )
            )
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        hasAnswered
                            ? (isTheCorrectOne ? Color.green : (isSelected ? Color.red : Color.clear))
                            : (isSelected ? category.color1 : Color.clear),
                        lineWidth: 2
                    )
            )
        }
        .disabled(selectedAnswer != nil)
    }

    private var quizResultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            let percentage = totalAttempts > 0 ? Double(score) / Double(totalAttempts) : 0

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(
                        LinearGradient(
                            colors: [category.color1, category.color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 36, weight: .bold))
                    Text("\(score)/\(totalAttempts)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            Text(percentage >= 0.9 ? "Excellent!" : percentage >= 0.7 ? "Great job!" : percentage >= 0.5 ? "Good effort!" : "Keep practicing!")
                .font(.title.bold())

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(bestStreak)")
                        .font(.title3.bold())
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(score)")
                        .font(.title3.bold())
                    Text("Correct")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                resetQuiz()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [category.color1, category.color2],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }

            Spacer()
        }
        .padding()
    }

    private func startQuiz() {
        let pool = category.words
        // Spaced repetition: words with more wrong answers appear more often
        var weighted: [FrenchWord] = []
        for word in pool {
            let repeats = max(1, word.wrongCount + (word.mastered ? 0 : 1))
            for _ in 0..<repeats {
                weighted.append(word)
            }
        }
        weighted.shuffle()
        var seen = Set<UUID>()
        quizWords = weighted.filter { seen.insert($0.id).inserted }
        if quizWords.count > 20 { quizWords = Array(quizWords.prefix(20)) }
        currentWordIndex = 0
        score = 0
        totalAttempts = 0
        streak = 0
        bestStreak = 0
        selectedAnswer = nil
        showResults = false
        generateOptions()
    }

    private func generateOptions() {
        guard currentWordIndex < quizWords.count else { return }
        let word = quizWords[currentWordIndex]
        let correctAnswer = direction == .frenchToEnglish ? word.english : word.french

        var allAnswers = category.words.map { direction == .frenchToEnglish ? $0.english : $0.french }
        allAnswers.removeAll { $0 == correctAnswer }
        allAnswers.shuffle()

        var opts = Array(allAnswers.prefix(3))
        opts.append(correctAnswer)
        options = opts.shuffled()
    }

    private func nextQuestion() {
        if currentWordIndex < quizWords.count - 1 {
            currentWordIndex += 1
            selectedAnswer = nil
            isCorrect = nil
            generateOptions()
        } else {
            // Mark high scorers as mastered
            if totalAttempts > 0 && Double(score) / Double(totalAttempts) >= 0.8 {
                for word in quizWords {
                    if let idx = category.words.firstIndex(where: { $0.id == word.id }) {
                        category.words[idx].mastered = true
                    }
                }
            }
            showResults = true
        }
    }

    private func resetQuiz() {
        quizWords = []
        showResults = false
        selectedAnswer = nil
    }
}
