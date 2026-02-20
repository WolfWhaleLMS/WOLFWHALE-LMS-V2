import SwiftUI

// MARK: - Word Data

struct WordEntry: Identifiable {
    let id = UUID()
    let word: String
    let definition: String
    let category: WordCategory
}

enum WordCategory: String, CaseIterable, Identifiable {
    case science = "Science"
    case history = "History"
    case math = "Math"
    case english = "English"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .science: return "flask.fill"
        case .history: return "clock.fill"
        case .math: return "function"
        case .english: return "book.fill"
        }
    }

    var color: Color {
        switch self {
        case .science: return .green
        case .history: return .orange
        case .math: return .blue
        case .english: return .purple
        }
    }

    var words: [WordEntry] {
        switch self {
        case .science:
            return [
                WordEntry(word: "ATOM", definition: "The smallest unit of matter that retains the properties of an element.", category: .science),
                WordEntry(word: "CELL", definition: "The basic structural and functional unit of all living organisms.", category: .science),
                WordEntry(word: "FORCE", definition: "A push or pull on an object that can cause it to accelerate.", category: .science),
                WordEntry(word: "ENERGY", definition: "The capacity to do work or cause physical change.", category: .science),
                WordEntry(word: "PHOTON", definition: "A quantum of electromagnetic radiation, a particle of light.", category: .science),
                WordEntry(word: "ENZYME", definition: "A biological catalyst that speeds up chemical reactions in cells.", category: .science),
                WordEntry(word: "GENOME", definition: "The complete set of genetic material in an organism.", category: .science),
                WordEntry(word: "PLASMA", definition: "The fourth state of matter, consisting of ionized gas.", category: .science),
                WordEntry(word: "PRISM", definition: "A transparent optical element that refracts light into a spectrum.", category: .science),
                WordEntry(word: "ORBIT", definition: "The curved path of a celestial object around a star or planet.", category: .science),
            ]
        case .history:
            return [
                WordEntry(word: "EMPIRE", definition: "A group of nations or territories ruled by a single authority.", category: .history),
                WordEntry(word: "TREATY", definition: "A formal agreement between nations to establish peace or trade.", category: .history),
                WordEntry(word: "COLONY", definition: "A territory under the political control of a distant country.", category: .history),
                WordEntry(word: "REVOLT", definition: "An attempt to overthrow the authority of a state or ruler.", category: .history),
                WordEntry(word: "SENATE", definition: "A governing body, originally from ancient Rome.", category: .history),
                WordEntry(word: "FEUDAL", definition: "Relating to the medieval system of land ownership and obligations.", category: .history),
                WordEntry(word: "BRONZE", definition: "An alloy that gave its name to an early period of human civilization.", category: .history),
                WordEntry(word: "PHARAOH", definition: "A ruler of ancient Egypt, considered both king and god.", category: .history),
                WordEntry(word: "VIKING", definition: "Norse seafarers who explored, raided, and traded across Europe.", category: .history),
                WordEntry(word: "KNIGHT", definition: "A mounted warrior serving a medieval lord or king.", category: .history),
            ]
        case .math:
            return [
                WordEntry(word: "PRIME", definition: "A number greater than 1 divisible only by 1 and itself.", category: .math),
                WordEntry(word: "RATIO", definition: "A comparison of two quantities expressed as a fraction.", category: .math),
                WordEntry(word: "ANGLE", definition: "The space between two intersecting lines measured in degrees.", category: .math),
                WordEntry(word: "GRAPH", definition: "A visual representation of data or mathematical functions.", category: .math),
                WordEntry(word: "MEDIAN", definition: "The middle value in an ordered set of numbers.", category: .math),
                WordEntry(word: "VERTEX", definition: "A point where two or more lines or edges meet.", category: .math),
                WordEntry(word: "FACTOR", definition: "A number that divides evenly into another number.", category: .math),
                WordEntry(word: "SLOPE", definition: "The steepness or incline of a line, rise over run.", category: .math),
                WordEntry(word: "MATRIX", definition: "A rectangular array of numbers arranged in rows and columns.", category: .math),
                WordEntry(word: "SCALAR", definition: "A quantity with magnitude but no direction.", category: .math),
            ]
        case .english:
            return [
                WordEntry(word: "PROSE", definition: "Written or spoken language in its ordinary form, without meter.", category: .english),
                WordEntry(word: "IRONY", definition: "Expression of meaning using language that normally signifies the opposite.", category: .english),
                WordEntry(word: "THEME", definition: "The central idea or underlying meaning of a literary work.", category: .english),
                WordEntry(word: "STANZA", definition: "A group of lines in a poem, separated from others by a blank line.", category: .english),
                WordEntry(word: "SIMILE", definition: "A figure of speech comparing two things using 'like' or 'as'.", category: .english),
                WordEntry(word: "SYNTAX", definition: "The arrangement of words and phrases to create sentences.", category: .english),
                WordEntry(word: "FABLE", definition: "A short story conveying a moral, often with animal characters.", category: .english),
                WordEntry(word: "GENRE", definition: "A category of artistic composition characterized by style or form.", category: .english),
                WordEntry(word: "MEMOIR", definition: "A written account of personal experiences and memories.", category: .english),
                WordEntry(word: "SATIRE", definition: "The use of humor or exaggeration to criticize and expose flaws.", category: .english),
            ]
        }
    }
}

// MARK: - Scramble Letter Model

struct ScrambleLetter: Identifiable, Equatable {
    let id = UUID()
    let character: Character
    var isPlaced: Bool = false
}

// MARK: - Game View Model

@Observable
@MainActor
class WordScrambleViewModel {
    var currentWord: WordEntry?
    var scrambledLetters: [ScrambleLetter] = []
    var placedLetters: [ScrambleLetter?] = []
    var selectedCategory: WordCategory = .science
    var score: Int = 0
    var streak: Int = 0
    var multiplier: Int = 1
    var timeRemaining: Double = 30.0
    var isTimerRunning: Bool = false
    var roundsPlayed: Int = 0
    var totalRounds: Int = 10
    var hintsUsed: Int = 0
    var maxHints: Int = 3
    var showDefinition: Bool = false
    var isCorrect: Bool = false
    var isGameOver: Bool = false
    var isGameStarted: Bool = false
    var usedWords: Set<String> = []

    private var timer: Timer?

    var currentGuess: String {
        placedLetters.compactMap { $0?.character }.map(String.init).joined()
    }

    var isWordComplete: Bool {
        placedLetters.allSatisfy { $0 != nil }
    }

    func startGame() {
        score = 0
        streak = 0
        multiplier = 1
        roundsPlayed = 0
        hintsUsed = 0
        isGameOver = false
        isGameStarted = true
        usedWords.removeAll()
        nextWord()
    }

    func nextWord() {
        guard roundsPlayed < totalRounds else {
            endGame()
            return
        }

        showDefinition = false
        isCorrect = false
        timeRemaining = 30.0

        let available = selectedCategory.words.filter { !usedWords.contains($0.word) }
        guard let word = available.randomElement() else {
            // Reset used words if we run out
            usedWords.removeAll()
            guard let fallback = selectedCategory.words.randomElement() else { return }
            currentWord = fallback
            usedWords.insert(fallback.word)
            setupLetters(for: fallback.word)
            startTimer()
            return
        }

        currentWord = word
        usedWords.insert(word.word)
        setupLetters(for: word.word)
        startTimer()
    }

    private func setupLetters(for word: String) {
        var letters = word.map { ScrambleLetter(character: $0) }

        // Ensure the scrambled version is different from the original
        var shuffled = letters.shuffled()
        var attempts = 0
        while shuffled.map(\.character) == letters.map(\.character) && attempts < 10 {
            shuffled = letters.shuffled()
            attempts += 1
        }

        scrambledLetters = shuffled
        placedLetters = Array(repeating: nil, count: word.count)
    }

    func placeLetter(_ letter: ScrambleLetter) {
        guard let emptyIndex = placedLetters.firstIndex(where: { $0 == nil }) else { return }
        guard let sourceIndex = scrambledLetters.firstIndex(where: { $0.id == letter.id && !$0.isPlaced }) else { return }

        scrambledLetters[sourceIndex].isPlaced = true
        placedLetters[emptyIndex] = letter

        if isWordComplete {
            checkAnswer()
        }
    }

    func removePlacedLetter(at index: Int) {
        guard let letter = placedLetters[index] else { return }
        placedLetters[index] = nil

        if let sourceIndex = scrambledLetters.firstIndex(where: { $0.id == letter.id }) {
            scrambledLetters[sourceIndex].isPlaced = false
        }
    }

    func checkAnswer() {
        guard let word = currentWord else { return }

        if currentGuess == word.word {
            // Correct
            isCorrect = true
            showDefinition = true
            streak += 1
            multiplier = min(5, 1 + streak / 2)
            let timeBonus = Int(timeRemaining)
            let points = (10 + timeBonus) * multiplier
            score += points
            roundsPlayed += 1
            stopTimer()
        } else {
            // Wrong - clear all placed letters
            streak = 0
            multiplier = 1
            for i in placedLetters.indices {
                if let letter = placedLetters[i] {
                    if let sourceIndex = scrambledLetters.firstIndex(where: { $0.id == letter.id }) {
                        scrambledLetters[sourceIndex].isPlaced = false
                    }
                    placedLetters[i] = nil
                }
            }
        }
    }

    func useHint() {
        guard hintsUsed < maxHints, let word = currentWord else { return }
        hintsUsed += 1

        // Find first empty slot
        guard let emptyIndex = placedLetters.firstIndex(where: { $0 == nil }) else { return }

        let correctChar = Array(word.word)[emptyIndex]

        // Find matching unplaced letter
        if let letterIndex = scrambledLetters.firstIndex(where: { $0.character == correctChar && !$0.isPlaced }) {
            scrambledLetters[letterIndex].isPlaced = true
            placedLetters[emptyIndex] = scrambledLetters[letterIndex]

            if isWordComplete {
                checkAnswer()
            }
        }
    }

    func startTimer() {
        stopTimer()
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                } else {
                    self.timeExpired()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }

    private func timeExpired() {
        stopTimer()
        streak = 0
        multiplier = 1
        roundsPlayed += 1
        showDefinition = true

        if roundsPlayed >= totalRounds {
            endGame()
        }
    }

    private func endGame() {
        stopTimer()
        isGameOver = true
    }
}

// MARK: - Main Game View

struct WordScrambleGame: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WordScrambleViewModel()
    @State private var hapticTrigger = false
    @State private var correctTrigger = false
    @State private var wrongTrigger = false
    @AppStorage("wordScrambleHighScore") private var highScore: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isGameStarted {
                categorySelectionView
            } else if viewModel.isGameOver {
                gameOverView
            } else {
                gamePlayView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Word Scramble")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    hapticTrigger.toggle()
                    viewModel.stopTimer()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    // MARK: - Category Selection

    private var categorySelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "textformat.abc")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                    .padding(.top, 40)

                Text("Word Scramble")
                    .font(.title.bold())

                Text("Unscramble the letters to form words.\nEarn bonus points for speed and streaks!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a Category")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(WordCategory.allCases) { category in
                        Button {
                            hapticTrigger.toggle()
                            viewModel.selectedCategory = category
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .foregroundStyle(category.color)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("\(category.words.count) words")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if viewModel.selectedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(category.color)
                                }
                            }
                            .padding(14)
                            .background(
                                viewModel.selectedCategory == category
                                    ? category.color.opacity(0.1)
                                    : Color(.systemGray6),
                                in: .rect(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        viewModel.selectedCategory == category ? category.color.opacity(0.5) : .clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                        .padding(.horizontal)
                    }
                }

                Button {
                    hapticTrigger.toggle()
                    viewModel.startGame()
                } label: {
                    Text("Start Game")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 16)
                        )
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Game Play

    private var gamePlayView: some View {
        VStack(spacing: 16) {
            // Stats bar
            HStack {
                Label("\(viewModel.score)", systemImage: "star.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.yellow)

                Spacer()

                if viewModel.multiplier > 1 {
                    Text("x\(viewModel.multiplier)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text("Round \(viewModel.roundsPlayed + 1)/\(viewModel.totalRounds)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    Capsule()
                        .fill(timerColor)
                        .frame(width: geometry.size.width * (viewModel.timeRemaining / 30.0), height: 8)
                        .animation(.linear(duration: 0.1), value: viewModel.timeRemaining)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)

            // Category badge
            HStack(spacing: 6) {
                Image(systemName: viewModel.selectedCategory.icon)
                    .font(.caption)
                Text(viewModel.selectedCategory.rawValue)
                    .font(.caption.bold())
            }
            .foregroundStyle(viewModel.selectedCategory.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(viewModel.selectedCategory.color.opacity(0.12), in: Capsule())

            if viewModel.streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.streak) streak")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Placed letters (answer area)
            HStack(spacing: 8) {
                ForEach(viewModel.placedLetters.indices, id: \.self) { index in
                    LetterSlotView(
                        letter: viewModel.placedLetters[index],
                        isCorrect: viewModel.isCorrect,
                        index: index
                    )
                    .onTapGesture {
                        guard !viewModel.isCorrect else { return }
                        hapticTrigger.toggle()
                        viewModel.removePlacedLetter(at: index)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .padding(.horizontal)

            // Definition (shown after solving or time expires)
            if viewModel.showDefinition, let word = viewModel.currentWord {
                VStack(spacing: 8) {
                    if viewModel.isCorrect {
                        Label("Correct!", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        VStack(spacing: 4) {
                            Text("Time's up!")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text("The word was: \(word.word)")
                                .font(.subheadline.bold())
                        }
                    }

                    Text(word.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        hapticTrigger.toggle()
                        viewModel.nextWord()
                    } label: {
                        Text(viewModel.roundsPlayed >= viewModel.totalRounds ? "See Results" : "Next Word")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(.blue, in: Capsule())
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            // Scrambled letters
            if !viewModel.showDefinition {
                HStack(spacing: 8) {
                    ForEach(viewModel.scrambledLetters) { letter in
                        LetterTileView(letter: letter)
                            .onTapGesture {
                                guard !letter.isPlaced else { return }
                                hapticTrigger.toggle()
                                viewModel.placeLetter(letter)
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
                .padding(.horizontal)

                // Hint button
                HStack(spacing: 16) {
                    Button {
                        hapticTrigger.toggle()
                        viewModel.useHint()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                            Text("Hint (\(viewModel.maxHints - viewModel.hintsUsed) left)")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.yellow.opacity(0.12), in: Capsule())
                    }
                    .disabled(viewModel.hintsUsed >= viewModel.maxHints)
                    .opacity(viewModel.hintsUsed >= viewModel.maxHints ? 0.4 : 1.0)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                .padding(.bottom, 8)
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showDefinition)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isCorrect)
    }

    // MARK: - Game Over

    private var gameOverView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                    .padding(.top, 40)

                Text("Game Complete!")
                    .font(.title.bold())

                VStack(spacing: 12) {
                    resultRow(icon: "star.fill", label: "Final Score", value: "\(viewModel.score)", color: .yellow)
                    resultRow(icon: "flame.fill", label: "Best Streak", value: "\(viewModel.streak)", color: .orange)
                    resultRow(icon: "lightbulb.fill", label: "Hints Used", value: "\(viewModel.hintsUsed)/\(viewModel.maxHints)", color: .yellow)
                    resultRow(icon: "trophy.fill", label: "High Score", value: "\(max(highScore, viewModel.score))", color: .purple)
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

                if viewModel.score > highScore {
                    Text("New High Score!")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                }

                Button {
                    hapticTrigger.toggle()
                    if viewModel.score > highScore {
                        highScore = viewModel.score
                    }
                    viewModel.startGame()
                } label: {
                    Text("Play Again")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 16)
                        )
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .padding(.horizontal)

                Button {
                    hapticTrigger.toggle()
                    if viewModel.score > highScore {
                        highScore = viewModel.score
                    }
                    dismiss()
                } label: {
                    Text("Exit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            if viewModel.score > highScore {
                highScore = viewModel.score
            }
        }
    }

    private func resultRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private var timerColor: Color {
        if viewModel.timeRemaining > 15 {
            return .green
        } else if viewModel.timeRemaining > 7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Letter Tile View

struct LetterTileView: View {
    let letter: ScrambleLetter

    var body: some View {
        Text(String(letter.character))
            .font(.title2.bold())
            .foregroundStyle(letter.isPlaced ? .clear : .primary)
            .frame(width: 44, height: 52)
            .background(
                letter.isPlaced
                    ? Color(.systemGray5)
                    : Color(.systemBackground),
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        letter.isPlaced ? Color(.systemGray4) : Color.purple.opacity(0.4),
                        lineWidth: 2
                    )
            )
            .shadow(color: letter.isPlaced ? .clear : .purple.opacity(0.15), radius: 4, y: 2)
            .scaleEffect(letter.isPlaced ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: letter.isPlaced)
    }
}

// MARK: - Letter Slot View

struct LetterSlotView: View {
    let letter: ScrambleLetter?
    let isCorrect: Bool
    let index: Int

    var body: some View {
        ZStack {
            if let letter = letter {
                Text(String(letter.character))
                    .font(.title2.bold())
                    .foregroundStyle(isCorrect ? .green : .primary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 44, height: 52)
        .background(
            slotBackground,
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(slotBorderColor, lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: letter?.id)
    }

    private var slotBackground: Color {
        if isCorrect {
            return .green.opacity(0.1)
        } else if letter != nil {
            return Color(.systemBackground)
        } else {
            return Color(.systemGray6)
        }
    }

    private var slotBorderColor: Color {
        if isCorrect {
            return .green
        } else if letter != nil {
            return .blue.opacity(0.4)
        } else {
            return Color(.systemGray4)
        }
    }
}

#Preview {
    NavigationStack {
        WordScrambleGame()
    }
}
