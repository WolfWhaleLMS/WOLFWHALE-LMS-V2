import SwiftUI

// MARK: - Data Models

struct FrenchWord: Identifiable, Equatable {
    let id = UUID()
    let french: String
    let english: String
    let phonetic: String
    var mastered: Bool = false
    var wrongCount: Int = 0
    var lastSeen: Date?
}

struct VocabCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color1: Color
    let color2: Color
    var words: [FrenchWord]
}

enum VocabMode {
    case flashcard
    case quiz
}

enum QuizDirection {
    case frenchToEnglish
    case englishToFrench
}

// MARK: - Main View

struct FrenchVocabView: View {
    @State private var categories: [VocabCategory] = FrenchVocabData.allCategories
    @State private var selectedCategory: VocabCategory?
    @State private var mode: VocabMode = .flashcard
    @State private var showingCategoryDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                statsOverview
                categoriesGrid
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("French Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCategory) { category in
            NavigationStack {
                CategoryDetailView(
                    category: binding(for: category),
                    allCategories: $categories
                )
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.blue, .indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 150)

            VStack(spacing: 8) {
                Image(systemName: "textbook.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Vocabulaire Francais")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Canadian French Immersion Curriculum")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Total Words",
                value: "\(totalWords)",
                icon: "character.book.closed.fill",
                color: .blue
            )
            statCard(
                title: "Mastered",
                value: "\(masteredWords)",
                icon: "checkmark.seal.fill",
                color: .green
            )
            statCard(
                title: "Practicing",
                value: "\(totalWords - masteredWords)",
                icon: "arrow.triangle.2.circlepath",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    private var totalWords: Int {
        categories.reduce(0) { $0 + $1.words.count }
    }

    private var masteredWords: Int {
        categories.reduce(0) { sum, cat in
            sum + cat.words.filter { $0.mastered }.count
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text("Categories")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    categoryCard(category: category, index: index)
                        .onTapGesture {
                            selectedCategory = categories[index]
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryCard(category: VocabCategory, index: Int) -> some View {
        let mastered = category.words.filter { $0.mastered }.count
        let total = category.words.count
        let progress = total > 0 ? Double(mastered) / Double(total) : 0

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color1, category.color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Text(category.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text("\(mastered)/\(total) mastered")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func binding(for category: VocabCategory) -> Binding<VocabCategory> {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return .constant(category)
        }
        return $categories[index]
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    @Binding var category: VocabCategory
    @Binding var allCategories: [VocabCategory]
    @State private var mode: VocabMode = .flashcard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                    .tag(VocabMode.flashcard)
                Label("Quiz", systemImage: "questionmark.circle.fill")
                    .tag(VocabMode.quiz)
            }
            .pickerStyle(.segmented)
            .padding()

            switch mode {
            case .flashcard:
                FlashcardModeView(category: $category)
            case .quiz:
                VocabQuizModeView(category: $category)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Flashcard Mode

struct FlashcardModeView: View {
    @Binding var category: VocabCategory
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0
    @State private var showPronunciation = true

    private var sortedWords: [FrenchWord] {
        category.words.sorted { a, b in
            if a.mastered != b.mastered { return !a.mastered }
            return a.wrongCount > b.wrongCount
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            progressIndicator

            Spacer()

            if !sortedWords.isEmpty {
                flashcard
                    .offset(x: dragOffset)
                    .gesture(swipeGesture)
            }

            Spacer()

            controlButtons

            navigationButtons
        }
        .padding()
    }

    private var progressIndicator: some View {
        HStack {
            Text("Card \(currentIndex + 1) of \(sortedWords.count)")
                .font(.subheadline.bold())
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("\(category.words.filter { $0.mastered }.count)")
                    .font(.subheadline.bold().monospacedDigit())
            }
        }
        .padding(.horizontal)
    }

    private var flashcard: some View {
        let word = sortedWords[currentIndex]
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [category.color1, category.color2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            VStack(spacing: 16) {
                Text(isFlipped ? "English" : "Francais")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(isFlipped ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    )

                Text(isFlipped ? word.english : word.french)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .scaleEffect(x: isFlipped ? -1 : 1)

                if showPronunciation && !isFlipped {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                        Text(word.phonetic)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                if word.mastered {
                    Label("Mastered", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            .padding(32)
        }
        .frame(height: 260)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
                    if value.translation.width < -80 {
                        goToNext()
                    } else if value.translation.width > 80 {
                        goToPrevious()
                    }
                    dragOffset = 0
                }
            }
    }

    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button {
                toggleMastered()
            } label: {
                let word = sortedWords[currentIndex]
                Label(
                    word.mastered ? "Unmaster" : "Mark Mastered",
                    systemImage: word.mastered ? "xmark.seal" : "checkmark.seal.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(word.mastered ? .red : .green)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Button {
                showPronunciation.toggle()
            } label: {
                Image(systemName: showPronunciation ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 30) {
            Button {
                withAnimation(.spring(response: 0.3)) { goToPrevious() }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(category.color1)
            }
            .disabled(currentIndex == 0)
            .opacity(currentIndex == 0 ? 0.3 : 1)

            Text("\(currentIndex + 1)")
                .font(.title2.bold().monospacedDigit())
                .frame(width: 40)

            Button {
                withAnimation(.spring(response: 0.3)) { goToNext() }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(category.color2)
            }
            .disabled(currentIndex >= sortedWords.count - 1)
            .opacity(currentIndex >= sortedWords.count - 1 ? 0.3 : 1)
        }
        .padding(.bottom, 8)
    }

    private func goToNext() {
        if currentIndex < sortedWords.count - 1 {
            currentIndex += 1
            isFlipped = false
        }
    }

    private func goToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            isFlipped = false
        }
    }

    private func toggleMastered() {
        let word = sortedWords[currentIndex]
        if let idx = category.words.firstIndex(where: { $0.id == word.id }) {
            category.words[idx].mastered.toggle()
        }
    }
}

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
        var pool = category.words
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

// MARK: - Vocabulary Data

struct FrenchVocabData {
    static let allCategories: [VocabCategory] =
        [
            VocabCategory(name: "Greetings", icon: "hand.wave.fill", color1: .blue, color2: .cyan, words: greetings),
            VocabCategory(name: "Family", icon: "figure.2.and.child.holdinghands", color1: .pink, color2: .red, words: family),
            VocabCategory(name: "Food", icon: "fork.knife", color1: .orange, color2: .yellow, words: food),
            VocabCategory(name: "School", icon: "graduationcap.fill", color1: .purple, color2: .indigo, words: school),
            VocabCategory(name: "Animals", icon: "pawprint.fill", color1: .green, color2: .mint, words: animals),
            VocabCategory(name: "Body Parts", icon: "figure.stand", color1: .red, color2: .pink, words: bodyParts),
            VocabCategory(name: "Colours", icon: "paintpalette.fill", color1: .indigo, color2: .purple, words: colours),
            VocabCategory(name: "Numbers", icon: "number", color1: .teal, color2: .blue, words: numbers),
            VocabCategory(name: "Weather", icon: "cloud.sun.fill", color1: .cyan, color2: .blue, words: weather),
            VocabCategory(name: "Clothing", icon: "tshirt.fill", color1: .brown, color2: .orange, words: clothing),
        ]

    static let greetings: [FrenchWord] =
        [
            FrenchWord(french: "Bonjour", english: "Hello / Good morning", phonetic: "bohn-ZHOOR"),
            FrenchWord(french: "Bonsoir", english: "Good evening", phonetic: "bohn-SWAHR"),
            FrenchWord(french: "Salut", english: "Hi / Bye (informal)", phonetic: "sah-LOO"),
            FrenchWord(french: "Au revoir", english: "Goodbye", phonetic: "oh ruh-VWAHR"),
            FrenchWord(french: "Merci", english: "Thank you", phonetic: "mehr-SEE"),
            FrenchWord(french: "Merci beaucoup", english: "Thank you very much", phonetic: "mehr-SEE boh-KOO"),
            FrenchWord(french: "S'il vous plait", english: "Please (formal)", phonetic: "seel voo PLEH"),
            FrenchWord(french: "S'il te plait", english: "Please (informal)", phonetic: "seel tuh PLEH"),
            FrenchWord(french: "De rien", english: "You're welcome", phonetic: "duh RYEHN"),
            FrenchWord(french: "Excusez-moi", english: "Excuse me", phonetic: "ek-skew-ZAY mwah"),
            FrenchWord(french: "Pardon", english: "Sorry / Pardon", phonetic: "par-DOHN"),
            FrenchWord(french: "Comment allez-vous?", english: "How are you? (formal)", phonetic: "koh-MOHN tah-LAY voo"),
            FrenchWord(french: "Comment ca va?", english: "How are you? (informal)", phonetic: "koh-MOHN sah VAH"),
            FrenchWord(french: "Ca va bien", english: "I'm doing well", phonetic: "sah vah BYEHN"),
            FrenchWord(french: "Bonne nuit", english: "Good night", phonetic: "bohn NWEE"),
            FrenchWord(french: "Bienvenue", english: "Welcome", phonetic: "byehn-vuh-NOO"),
            FrenchWord(french: "A bientot", english: "See you soon", phonetic: "ah byehn-TOH"),
            FrenchWord(french: "A demain", english: "See you tomorrow", phonetic: "ah duh-MEHN"),
            FrenchWord(french: "Enchanté", english: "Nice to meet you", phonetic: "ohn-shahn-TAY"),
            FrenchWord(french: "Bonne journée", english: "Have a good day", phonetic: "bohn zhoor-NAY"),
            FrenchWord(french: "Oui", english: "Yes", phonetic: "WEE"),
            FrenchWord(french: "Non", english: "No", phonetic: "NOHN"),
        ]

    static let family: [FrenchWord] =
        [
            FrenchWord(french: "La mère", english: "Mother", phonetic: "lah MEHR"),
            FrenchWord(french: "Le père", english: "Father", phonetic: "luh PEHR"),
            FrenchWord(french: "La soeur", english: "Sister", phonetic: "lah SUHR"),
            FrenchWord(french: "Le frère", english: "Brother", phonetic: "luh FREHR"),
            FrenchWord(french: "La grand-mère", english: "Grandmother", phonetic: "lah grahn-MEHR"),
            FrenchWord(french: "Le grand-père", english: "Grandfather", phonetic: "luh grahn-PEHR"),
            FrenchWord(french: "La tante", english: "Aunt", phonetic: "lah TAHNT"),
            FrenchWord(french: "L'oncle", english: "Uncle", phonetic: "LOHNKL"),
            FrenchWord(french: "Le cousin", english: "Cousin (male)", phonetic: "luh koo-ZEHN"),
            FrenchWord(french: "La cousine", english: "Cousin (female)", phonetic: "lah koo-ZEEN"),
            FrenchWord(french: "Le fils", english: "Son", phonetic: "luh FEES"),
            FrenchWord(french: "La fille", english: "Daughter", phonetic: "lah FEE-yuh"),
            FrenchWord(french: "Le bébé", english: "Baby", phonetic: "luh bay-BAY"),
            FrenchWord(french: "La famille", english: "Family", phonetic: "lah fah-MEE-yuh"),
            FrenchWord(french: "Les parents", english: "Parents", phonetic: "lay pah-RAHN"),
            FrenchWord(french: "Les enfants", english: "Children", phonetic: "layz ahn-FAHN"),
            FrenchWord(french: "Le mari", english: "Husband", phonetic: "luh mah-REE"),
            FrenchWord(french: "La femme", english: "Wife / Woman", phonetic: "lah FAHM"),
            FrenchWord(french: "Le neveu", english: "Nephew", phonetic: "luh nuh-VUH"),
            FrenchWord(french: "La nièce", english: "Niece", phonetic: "lah NYEHS"),
        ]

    static let food: [FrenchWord] =
        [
            FrenchWord(french: "Le pain", english: "Bread", phonetic: "luh PEHN"),
            FrenchWord(french: "Le fromage", english: "Cheese", phonetic: "luh froh-MAHZH"),
            FrenchWord(french: "La pomme", english: "Apple", phonetic: "lah POHM"),
            FrenchWord(french: "Le lait", english: "Milk", phonetic: "luh LEH"),
            FrenchWord(french: "L'eau", english: "Water", phonetic: "LOH"),
            FrenchWord(french: "Le poulet", english: "Chicken", phonetic: "luh poo-LEH"),
            FrenchWord(french: "Le poisson", english: "Fish", phonetic: "luh pwah-SOHN"),
            FrenchWord(french: "La soupe", english: "Soup", phonetic: "lah SOOP"),
            FrenchWord(french: "Le riz", english: "Rice", phonetic: "luh REE"),
            FrenchWord(french: "Les légumes", english: "Vegetables", phonetic: "lay lay-GOOM"),
            FrenchWord(french: "Les fruits", english: "Fruits", phonetic: "lay FRWEE"),
            FrenchWord(french: "Le gâteau", english: "Cake", phonetic: "luh gah-TOH"),
            FrenchWord(french: "La glace", english: "Ice cream", phonetic: "lah GLAHS"),
            FrenchWord(french: "Le beurre", english: "Butter", phonetic: "luh BUHR"),
            FrenchWord(french: "L'oeuf", english: "Egg", phonetic: "LUHF"),
            FrenchWord(french: "La carotte", english: "Carrot", phonetic: "lah kah-ROHT"),
            FrenchWord(french: "La tomate", english: "Tomato", phonetic: "lah toh-MAHT"),
            FrenchWord(french: "Le chocolat", english: "Chocolate", phonetic: "luh shoh-koh-LAH"),
            FrenchWord(french: "La poutine", english: "Poutine", phonetic: "lah poo-TEEN"),
            FrenchWord(french: "Le sirop d'érable", english: "Maple syrup", phonetic: "luh see-ROH day-RAHBL"),
            FrenchWord(french: "La crêpe", english: "Crepe / Pancake", phonetic: "lah KREHP"),
        ]

    static let school: [FrenchWord] =
        [
            FrenchWord(french: "L'école", english: "School", phonetic: "lay-KOHL"),
            FrenchWord(french: "Le professeur", english: "Teacher", phonetic: "luh proh-feh-SUHR"),
            FrenchWord(french: "L'élève", english: "Student", phonetic: "lay-LEHV"),
            FrenchWord(french: "Le livre", english: "Book", phonetic: "luh LEEVR"),
            FrenchWord(french: "Le cahier", english: "Notebook", phonetic: "luh kah-YAY"),
            FrenchWord(french: "Le crayon", english: "Pencil", phonetic: "luh kray-OHN"),
            FrenchWord(french: "Le stylo", english: "Pen", phonetic: "luh stee-LOH"),
            FrenchWord(french: "La classe", english: "Classroom", phonetic: "lah KLAHS"),
            FrenchWord(french: "Le bureau", english: "Desk / Office", phonetic: "luh bew-ROH"),
            FrenchWord(french: "La chaise", english: "Chair", phonetic: "lah SHEHZ"),
            FrenchWord(french: "Le tableau", english: "Board / Painting", phonetic: "luh tah-BLOH"),
            FrenchWord(french: "Les devoirs", english: "Homework", phonetic: "lay duh-VWAHR"),
            FrenchWord(french: "L'examen", english: "Exam", phonetic: "leg-zah-MEHN"),
            FrenchWord(french: "La récréation", english: "Recess", phonetic: "lah ray-kray-ah-SYOHN"),
            FrenchWord(french: "Le sac à dos", english: "Backpack", phonetic: "luh sahk ah DOH"),
            FrenchWord(french: "La règle", english: "Ruler", phonetic: "lah REHGL"),
            FrenchWord(french: "La gomme", english: "Eraser", phonetic: "lah GOHM"),
            FrenchWord(french: "Les ciseaux", english: "Scissors", phonetic: "lay see-ZOH"),
            FrenchWord(french: "L'ordinateur", english: "Computer", phonetic: "lor-dee-nah-TUHR"),
            FrenchWord(french: "La bibliothèque", english: "Library", phonetic: "lah bee-blee-oh-TEHK"),
        ]

    static let animals: [FrenchWord] =
        [
            FrenchWord(french: "Le chat", english: "Cat", phonetic: "luh SHAH"),
            FrenchWord(french: "Le chien", english: "Dog", phonetic: "luh SHYEHN"),
            FrenchWord(french: "L'oiseau", english: "Bird", phonetic: "lwah-ZOH"),
            FrenchWord(french: "Le poisson", english: "Fish", phonetic: "luh pwah-SOHN"),
            FrenchWord(french: "Le cheval", english: "Horse", phonetic: "luh shuh-VAHL"),
            FrenchWord(french: "La vache", english: "Cow", phonetic: "lah VAHSH"),
            FrenchWord(french: "Le cochon", english: "Pig", phonetic: "luh koh-SHOHN"),
            FrenchWord(french: "Le mouton", english: "Sheep", phonetic: "luh moo-TOHN"),
            FrenchWord(french: "Le lapin", english: "Rabbit", phonetic: "luh lah-PEHN"),
            FrenchWord(french: "La souris", english: "Mouse", phonetic: "lah soo-REE"),
            FrenchWord(french: "Le loup", english: "Wolf", phonetic: "luh LOO"),
            FrenchWord(french: "L'ours", english: "Bear", phonetic: "LOORS"),
            FrenchWord(french: "Le renard", english: "Fox", phonetic: "luh ruh-NAHR"),
            FrenchWord(french: "La baleine", english: "Whale", phonetic: "lah bah-LEHN"),
            FrenchWord(french: "Le dauphin", english: "Dolphin", phonetic: "luh doh-FEHN"),
            FrenchWord(french: "La tortue", english: "Turtle", phonetic: "lah tohr-TOO"),
            FrenchWord(french: "Le papillon", english: "Butterfly", phonetic: "luh pah-pee-YOHN"),
            FrenchWord(french: "L'éléphant", english: "Elephant", phonetic: "lay-lay-FAHN"),
            FrenchWord(french: "Le singe", english: "Monkey", phonetic: "luh SEHNZH"),
            FrenchWord(french: "L'orignal", english: "Moose", phonetic: "loh-ree-NYAHL"),
            FrenchWord(french: "Le castor", english: "Beaver", phonetic: "luh kahs-TOHR"),
        ]

    static let bodyParts: [FrenchWord] =
        [
            FrenchWord(french: "La tête", english: "Head", phonetic: "lah TEHT"),
            FrenchWord(french: "Les yeux", english: "Eyes", phonetic: "layz YUH"),
            FrenchWord(french: "Le nez", english: "Nose", phonetic: "luh NAY"),
            FrenchWord(french: "La bouche", english: "Mouth", phonetic: "lah BOOSH"),
            FrenchWord(french: "Les oreilles", english: "Ears", phonetic: "layz oh-RAY"),
            FrenchWord(french: "Le bras", english: "Arm", phonetic: "luh BRAH"),
            FrenchWord(french: "La main", english: "Hand", phonetic: "lah MEHN"),
            FrenchWord(french: "Le doigt", english: "Finger", phonetic: "luh DWAH"),
            FrenchWord(french: "La jambe", english: "Leg", phonetic: "lah ZHAHMB"),
            FrenchWord(french: "Le pied", english: "Foot", phonetic: "luh PYAY"),
            FrenchWord(french: "Le coeur", english: "Heart", phonetic: "luh KUHR"),
            FrenchWord(french: "Le dos", english: "Back", phonetic: "luh DOH"),
            FrenchWord(french: "Le ventre", english: "Stomach / Belly", phonetic: "luh VAHNTR"),
            FrenchWord(french: "Les cheveux", english: "Hair", phonetic: "lay shuh-VUH"),
            FrenchWord(french: "Le genou", english: "Knee", phonetic: "luh zhuh-NOO"),
            FrenchWord(french: "L'épaule", english: "Shoulder", phonetic: "lay-POHL"),
            FrenchWord(french: "Le cou", english: "Neck", phonetic: "luh KOO"),
            FrenchWord(french: "Les dents", english: "Teeth", phonetic: "lay DAHN"),
            FrenchWord(french: "La langue", english: "Tongue", phonetic: "lah LAHNGH"),
            FrenchWord(french: "Le visage", english: "Face", phonetic: "luh vee-ZAHZH"),
        ]

    static let colours: [FrenchWord] =
        [
            FrenchWord(french: "Rouge", english: "Red", phonetic: "ROOZH"),
            FrenchWord(french: "Bleu", english: "Blue", phonetic: "BLUH"),
            FrenchWord(french: "Vert", english: "Green", phonetic: "VEHR"),
            FrenchWord(french: "Jaune", english: "Yellow", phonetic: "ZHOHN"),
            FrenchWord(french: "Orange", english: "Orange", phonetic: "oh-RAHNZH"),
            FrenchWord(french: "Violet", english: "Purple", phonetic: "vyoh-LEH"),
            FrenchWord(french: "Rose", english: "Pink", phonetic: "ROHZ"),
            FrenchWord(french: "Blanc", english: "White", phonetic: "BLAHN"),
            FrenchWord(french: "Noir", english: "Black", phonetic: "NWAHR"),
            FrenchWord(french: "Gris", english: "Grey", phonetic: "GREE"),
            FrenchWord(french: "Brun", english: "Brown", phonetic: "BRUHN"),
            FrenchWord(french: "Doré", english: "Gold", phonetic: "doh-RAY"),
            FrenchWord(french: "Argenté", english: "Silver", phonetic: "ahr-zhahn-TAY"),
            FrenchWord(french: "Turquoise", english: "Turquoise", phonetic: "toor-KWAHZ"),
            FrenchWord(french: "Beige", english: "Beige", phonetic: "BEHZH"),
            FrenchWord(french: "Marron", english: "Chestnut brown", phonetic: "mah-ROHN"),
            FrenchWord(french: "Mauve", english: "Mauve", phonetic: "MOHV"),
            FrenchWord(french: "Indigo", english: "Indigo", phonetic: "ehn-dee-GOH"),
            FrenchWord(french: "Clair", english: "Light (colour)", phonetic: "KLEHR"),
            FrenchWord(french: "Foncé", english: "Dark (colour)", phonetic: "fohn-SAY"),
        ]

    static let numbers: [FrenchWord] =
        [
            FrenchWord(french: "Un", english: "One (1)", phonetic: "UHN"),
            FrenchWord(french: "Deux", english: "Two (2)", phonetic: "DUH"),
            FrenchWord(french: "Trois", english: "Three (3)", phonetic: "TRWAH"),
            FrenchWord(french: "Quatre", english: "Four (4)", phonetic: "KAHTR"),
            FrenchWord(french: "Cinq", english: "Five (5)", phonetic: "SEHNK"),
            FrenchWord(french: "Six", english: "Six (6)", phonetic: "SEES"),
            FrenchWord(french: "Sept", english: "Seven (7)", phonetic: "SEHT"),
            FrenchWord(french: "Huit", english: "Eight (8)", phonetic: "WEET"),
            FrenchWord(french: "Neuf", english: "Nine (9)", phonetic: "NUHF"),
            FrenchWord(french: "Dix", english: "Ten (10)", phonetic: "DEES"),
            FrenchWord(french: "Onze", english: "Eleven (11)", phonetic: "OHNZ"),
            FrenchWord(french: "Douze", english: "Twelve (12)", phonetic: "DOOZ"),
            FrenchWord(french: "Treize", english: "Thirteen (13)", phonetic: "TREHZ"),
            FrenchWord(french: "Quatorze", english: "Fourteen (14)", phonetic: "kah-TOHRZ"),
            FrenchWord(french: "Quinze", english: "Fifteen (15)", phonetic: "KAHNZ"),
            FrenchWord(french: "Vingt", english: "Twenty (20)", phonetic: "VEHN"),
            FrenchWord(french: "Trente", english: "Thirty (30)", phonetic: "TRAHNT"),
            FrenchWord(french: "Cinquante", english: "Fifty (50)", phonetic: "sehn-KAHNT"),
            FrenchWord(french: "Cent", english: "One hundred (100)", phonetic: "SAHN"),
            FrenchWord(french: "Mille", english: "One thousand (1000)", phonetic: "MEEL"),
        ]

    static let weather: [FrenchWord] =
        [
            FrenchWord(french: "Il fait soleil", english: "It's sunny", phonetic: "eel feh soh-LAY"),
            FrenchWord(french: "Il pleut", english: "It's raining", phonetic: "eel PLUH"),
            FrenchWord(french: "Il neige", english: "It's snowing", phonetic: "eel NEHZH"),
            FrenchWord(french: "Il fait chaud", english: "It's hot", phonetic: "eel feh SHOH"),
            FrenchWord(french: "Il fait froid", english: "It's cold", phonetic: "eel feh FRWAH"),
            FrenchWord(french: "Il fait beau", english: "It's nice out", phonetic: "eel feh BOH"),
            FrenchWord(french: "Il fait mauvais", english: "The weather is bad", phonetic: "eel feh moh-VEH"),
            FrenchWord(french: "Le vent", english: "Wind", phonetic: "luh VAHN"),
            FrenchWord(french: "Il fait du vent", english: "It's windy", phonetic: "eel feh doo VAHN"),
            FrenchWord(french: "Le nuage", english: "Cloud", phonetic: "luh new-AHZH"),
            FrenchWord(french: "L'orage", english: "Storm", phonetic: "loh-RAHZH"),
            FrenchWord(french: "La tempête", english: "Tempest / Blizzard", phonetic: "lah tahm-PEHT"),
            FrenchWord(french: "Le tonnerre", english: "Thunder", phonetic: "luh toh-NEHR"),
            FrenchWord(french: "L'éclair", english: "Lightning", phonetic: "lay-KLEHR"),
            FrenchWord(french: "L'arc-en-ciel", english: "Rainbow", phonetic: "lahrk-ahn-SYEHL"),
            FrenchWord(french: "La pluie", english: "Rain", phonetic: "lah PLOO-ee"),
            FrenchWord(french: "La neige", english: "Snow", phonetic: "lah NEHZH"),
            FrenchWord(french: "Le brouillard", english: "Fog", phonetic: "luh broo-YAHR"),
            FrenchWord(french: "La glace", english: "Ice", phonetic: "lah GLAHS"),
            FrenchWord(french: "Le verglas", english: "Black ice", phonetic: "luh vehr-GLAH"),
        ]

    static let clothing: [FrenchWord] =
        [
            FrenchWord(french: "Le chandail", english: "Sweater", phonetic: "luh shahn-DAH-yuh"),
            FrenchWord(french: "Le pantalon", english: "Pants", phonetic: "luh pahn-tah-LOHN"),
            FrenchWord(french: "La chemise", english: "Shirt", phonetic: "lah shuh-MEEZ"),
            FrenchWord(french: "La robe", english: "Dress", phonetic: "lah ROHB"),
            FrenchWord(french: "La jupe", english: "Skirt", phonetic: "lah ZHOOP"),
            FrenchWord(french: "Les chaussures", english: "Shoes", phonetic: "lay shoh-SOOR"),
            FrenchWord(french: "Les bottes", english: "Boots", phonetic: "lay BOHT"),
            FrenchWord(french: "Le manteau", english: "Coat", phonetic: "luh mahn-TOH"),
            FrenchWord(french: "La tuque", english: "Winter hat (toque)", phonetic: "lah TOOK"),
            FrenchWord(french: "Les mitaines", english: "Mittens", phonetic: "lay mee-TEHN"),
            FrenchWord(french: "L'écharpe", english: "Scarf", phonetic: "lay-SHAHRP"),
            FrenchWord(french: "Les chaussettes", english: "Socks", phonetic: "lay shoh-SEHT"),
            FrenchWord(french: "Le chapeau", english: "Hat", phonetic: "luh shah-POH"),
            FrenchWord(french: "Les lunettes", english: "Glasses", phonetic: "lay loo-NEHT"),
            FrenchWord(french: "La ceinture", english: "Belt", phonetic: "lah sehn-TOOR"),
            FrenchWord(french: "Le pyjama", english: "Pajamas", phonetic: "luh pee-zhah-MAH"),
            FrenchWord(french: "Le maillot de bain", english: "Swimsuit", phonetic: "luh my-OH duh BEHN"),
            FrenchWord(french: "Les gants", english: "Gloves", phonetic: "lay GAHN"),
            FrenchWord(french: "La veste", english: "Jacket", phonetic: "lah VEHST"),
            FrenchWord(french: "Le costume de neige", english: "Snowsuit", phonetic: "luh kohs-TOOM duh NEHZH"),
        ]
}

#Preview {
    NavigationStack {
        FrenchVocabView()
    }
}
