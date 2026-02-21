import SwiftUI

// MARK: - Word Builder View

struct WordBuilderView: View {
    @State private var difficulty: WordBuilderDifficulty = .easy
    @State private var currentWord = ""
    @State private var currentDefinition = ""
    @State private var scrambledLetters: [WordBuilderLetter] = []
    @State private var placedLetters: [WordBuilderLetter] = []
    @State private var score = 0
    @State private var streak = 0
    @State private var hintUsed = false
    @State private var showDefinitionHint = false
    @State private var isCorrect: Bool? = nil
    @State private var showResult = false
    @State private var wordsCompleted = 0
    @State private var challengeMode = false
    @State private var timeRemaining = 60
    @State private var timerActive = false
    @State private var gameOver = false
    @State private var shakeOffset: CGFloat = 0
    @State private var confettiTrigger = 0
    @State private var usedWordIndices: Set<Int> = []

    @AppStorage("wordBuilderHighScore") private var highScore = 0
    @AppStorage("wordBuilderBestStreak") private var bestStreak = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsBar
                difficultyPicker
                challengeToggle

                if gameOver {
                    gameOverCard
                } else {
                    wordBoardSection
                    letterRackSection
                    hintSection
                    actionButtons
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Word Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if challengeMode && timerActive {
                    timerBadge
                }
            }
        }
        .onAppear { loadNewWord() }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                if challengeMode && timerActive && timeRemaining > 0 {
                    timeRemaining -= 1
                    if timeRemaining <= 0 {
                        withAnimation(.spring) { gameOver = true }
                        timerActive = false
                    }
                }
            }
        }
        .overlay {
            if confettiTrigger > 0 {
                WordBuilderConfettiView(trigger: confettiTrigger)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statPill(icon: "star.fill", value: "\(score)", label: "Score", color: .orange)
            statDivider
            statPill(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .red)
            statDivider
            statPill(icon: "trophy.fill", value: "\(highScore)", label: "Best", color: .yellow)
            statDivider
            statPill(icon: "checkmark.circle.fill", value: "\(wordsCompleted)", label: "Words", color: .green)
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 36)
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        Picker("Difficulty", selection: $difficulty) {
            ForEach(WordBuilderDifficulty.allCases) { level in
                Text(level.rawValue).tag(level)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: difficulty) { _, _ in
            resetGame()
        }
    }

    // MARK: - Challenge Toggle

    private var challengeToggle: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.orange)
            Text("Challenge Mode")
                .font(.subheadline.bold())
            Spacer()
            Toggle("", isOn: $challengeMode)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .onChange(of: challengeMode) { _, newValue in
            if newValue {
                timeRemaining = 60
                timerActive = true
            } else {
                timerActive = false
            }
        }
    }

    // MARK: - Timer Badge

    private var timerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
            Text("\(timeRemaining)s")
        }
        .font(.caption.bold().monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(timeRemaining < 10 ? .red.opacity(0.2) : .orange.opacity(0.15), in: Capsule())
        .foregroundStyle(timeRemaining < 10 ? .red : .orange)
    }

    // MARK: - Word Board

    private var wordBoardSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "textformat.abc")
                    .foregroundStyle(.purple)
                Text("Build the Word")
                    .font(.headline)
                Spacer()
                Text("\(currentWord.count) letters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<currentWord.count, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                index < placedLetters.count
                                    ? (showResult && isCorrect == true
                                        ? Color.green.opacity(0.2)
                                        : showResult && isCorrect == false
                                            ? Color.red.opacity(0.2)
                                            : Color.purple.opacity(0.15))
                                    : Color(.tertiarySystemFill)
                            )
                            .frame(width: tileSize, height: tileSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        index < placedLetters.count
                                            ? (showResult && isCorrect == true
                                                ? .green
                                                : showResult && isCorrect == false
                                                    ? .red
                                                    : .purple)
                                            : .secondary.opacity(0.3),
                                        lineWidth: 2
                                    )
                            )

                        if index < placedLetters.count {
                            Text(placedLetters[index].character.uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(
                                    showResult && isCorrect == true ? .green
                                    : showResult && isCorrect == false ? .red
                                    : .primary
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .onTapGesture {
                        guard index < placedLetters.count, !showResult else { return }
                        withAnimation(.snappy) {
                            let letter = placedLetters.remove(at: index)
                            scrambledLetters.append(letter)
                        }
                    }
                }
            }
            .offset(x: shakeOffset)
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: placedLetters.count)
    }

    private var tileSize: CGFloat {
        let count = CGFloat(currentWord.count)
        let available: CGFloat = UIScreen.main.bounds.width - 80
        let maxSize: CGFloat = 48
        return min(maxSize, (available - (count - 1) * 8) / count)
    }

    // MARK: - Letter Rack

    private var letterRackSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "character.textbox")
                    .foregroundStyle(.blue)
                Text("Letter Rack")
                    .font(.headline)
                Spacer()
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(scrambledLetters.count, 7))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(scrambledLetters) { letter in
                    Button {
                        guard !showResult else { return }
                        withAnimation(.snappy) {
                            if let idx = scrambledLetters.firstIndex(where: { $0.id == letter.id }) {
                                let removed = scrambledLetters.remove(at: idx)
                                placedLetters.append(removed)
                            }
                        }
                    } label: {
                        Text(letter.character.uppercased())
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: .rect(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Hint Section

    private var hintSection: some View {
        VStack(spacing: 10) {
            if showDefinitionHint {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(currentDefinition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.1), in: .rect(cornerRadius: 12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showResult {
                HStack(spacing: 10) {
                    Image(systemName: isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isCorrect == true ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCorrect == true ? "Correct!" : "Not quite!")
                            .font(.headline)
                            .foregroundStyle(isCorrect == true ? .green : .red)
                        if isCorrect != true {
                            Text("The word was: **\(currentWord.uppercased())**")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    (isCorrect == true ? Color.green : Color.red).opacity(0.1),
                    in: .rect(cornerRadius: 12)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !showResult {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) {
                            revealFirstLetter()
                        }
                    } label: {
                        Label("First Letter", systemImage: "lightbulb.min")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    .disabled(hintUsed || !placedLetters.isEmpty)

                    Button {
                        withAnimation(.snappy) {
                            showDefinitionHint = true
                            hintUsed = true
                        }
                    } label: {
                        Label("Definition", systemImage: "book")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(showDefinitionHint)
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) { shuffleRack() }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(scrambledLetters.isEmpty)

                    Button {
                        withAnimation(.snappy) { clearBoard() }
                    } label: {
                        Label("Clear", systemImage: "arrow.uturn.backward")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(placedLetters.isEmpty)
                }

                Button {
                    checkWord()
                } label: {
                    Text("Check Word")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(placedLetters.count != currentWord.count)
            } else {
                Button {
                    withAnimation(.snappy) { loadNewWord() }
                } label: {
                    Label("Next Word", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    // MARK: - Game Over

    private var gameOverCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Time's Up!")
                .font(.largeTitle.bold())

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(wordsCompleted)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(bestStreak)")
                        .font(.title.bold())
                        .foregroundStyle(.red)
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if score >= highScore && score > 0 {
                Text("New High Score!")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .padding(10)
                    .background(.yellow.opacity(0.15), in: Capsule())
            }

            Button {
                resetGame()
            } label: {
                Label("Play Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .sensoryFeedback(.success, trigger: gameOver)
    }

    // MARK: - Logic

    private func loadNewWord() {
        let wordList = difficulty.words
        var index: Int
        if usedWordIndices.count >= wordList.count {
            usedWordIndices.removeAll()
        }
        repeat {
            index = Int.random(in: 0..<wordList.count)
        } while usedWordIndices.contains(index)

        usedWordIndices.insert(index)
        let entry = wordList[index]
        currentWord = entry.word.lowercased()
        currentDefinition = entry.definition

        let letters = currentWord.map { WordBuilderLetter(character: String($0)) }
        scrambledLetters = letters.shuffled()

        // Ensure not accidentally in order
        if scrambledLetters.map(\.character) == letters.map(\.character) {
            scrambledLetters.shuffle()
        }

        placedLetters = []
        showResult = false
        isCorrect = nil
        hintUsed = false
        showDefinitionHint = false
    }

    private func checkWord() {
        let attempt = placedLetters.map(\.character).joined()
        let correct = attempt == currentWord

        withAnimation(.spring) {
            isCorrect = correct
            showResult = true
        }

        if correct {
            let basePoints = currentWord.count * 10
            let speedBonus = challengeMode ? (timeRemaining > 30 ? 20 : 10) : 0
            let hintPenalty = hintUsed ? -15 : 0
            let streakBonus = streak * 5
            let wordScore = max(5, basePoints + speedBonus + hintPenalty + streakBonus)

            score += wordScore
            streak += 1
            wordsCompleted += 1

            if streak > bestStreak { bestStreak = streak }
            if score > highScore { highScore = score }

            confettiTrigger += 1
        } else {
            streak = 0
            shakeBoard()
        }
    }

    private func revealFirstLetter() {
        guard let first = currentWord.first else { return }
        let firstChar = String(first)
        hintUsed = true

        clearBoard()

        if let idx = scrambledLetters.firstIndex(where: { $0.character == firstChar }) {
            let letter = scrambledLetters.remove(at: idx)
            placedLetters.append(letter)
        }
    }

    private func shuffleRack() {
        scrambledLetters.shuffle()
    }

    private func clearBoard() {
        scrambledLetters.append(contentsOf: placedLetters)
        placedLetters.removeAll()
        scrambledLetters.shuffle()
    }

    private func shakeBoard() {
        withAnimation(.default.repeatCount(4, autoreverses: true).speed(6)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
        }
    }

    private func resetGame() {
        score = 0
        streak = 0
        wordsCompleted = 0
        gameOver = false
        usedWordIndices.removeAll()
        if challengeMode {
            timeRemaining = 60
            timerActive = true
        }
        loadNewWord()
    }
}

// MARK: - Supporting Types

struct WordBuilderLetter: Identifiable, Equatable {
    let id = UUID()
    let character: String
}

struct WordBuilderEntry {
    let word: String
    let definition: String
}

enum WordBuilderDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }

    var words: [WordBuilderEntry] {
        switch self {
        case .easy: return WordBuilderDifficulty.easyWords
        case .medium: return WordBuilderDifficulty.mediumWords
        case .hard: return WordBuilderDifficulty.hardWords
        }
    }

    static let easyWords: [WordBuilderEntry] = [
        WordBuilderEntry(word: "bear", definition: "A large, heavy mammal with thick fur"),
        WordBuilderEntry(word: "cake", definition: "A sweet baked dessert"),
        WordBuilderEntry(word: "dark", definition: "Having little or no light"),
        WordBuilderEntry(word: "east", definition: "The direction where the sun rises"),
        WordBuilderEntry(word: "farm", definition: "Land used for growing crops or raising animals"),
        WordBuilderEntry(word: "gate", definition: "A movable barrier in a fence or wall"),
        WordBuilderEntry(word: "hare", definition: "An animal similar to a rabbit"),
        WordBuilderEntry(word: "iron", definition: "A strong, hard metal"),
        WordBuilderEntry(word: "jump", definition: "To push yourself up into the air"),
        WordBuilderEntry(word: "kite", definition: "A toy flown in the wind on a string"),
        WordBuilderEntry(word: "lake", definition: "A large body of fresh water"),
        WordBuilderEntry(word: "mist", definition: "A thin fog or water vapour"),
        WordBuilderEntry(word: "nest", definition: "A structure built by birds for eggs"),
        WordBuilderEntry(word: "open", definition: "Not closed or blocked"),
        WordBuilderEntry(word: "pine", definition: "An evergreen tree with needles"),
        WordBuilderEntry(word: "quiz", definition: "A short test of knowledge"),
        WordBuilderEntry(word: "rain", definition: "Water falling from clouds"),
        WordBuilderEntry(word: "sand", definition: "Tiny grains found on beaches"),
        WordBuilderEntry(word: "tree", definition: "A tall plant with a trunk and branches"),
        WordBuilderEntry(word: "upon", definition: "On top of; on"),
        WordBuilderEntry(word: "vine", definition: "A climbing or trailing plant"),
        WordBuilderEntry(word: "warm", definition: "Having moderate heat"),
        WordBuilderEntry(word: "yarn", definition: "Thread used for knitting"),
        WordBuilderEntry(word: "zone", definition: "An area with specific characteristics"),
        WordBuilderEntry(word: "bark", definition: "The outer covering of a tree"),
        WordBuilderEntry(word: "claw", definition: "A sharp curved nail on an animal"),
        WordBuilderEntry(word: "dawn", definition: "The first light of day"),
        WordBuilderEntry(word: "echo", definition: "A repeated sound caused by reflection"),
        WordBuilderEntry(word: "fern", definition: "A green plant with feathery leaves"),
        WordBuilderEntry(word: "glow", definition: "To give off a steady light"),
        WordBuilderEntry(word: "hill", definition: "A raised area of land, smaller than a mountain"),
        WordBuilderEntry(word: "isle", definition: "A small island"),
        WordBuilderEntry(word: "jade", definition: "A green gemstone"),
        WordBuilderEntry(word: "kelp", definition: "A large brown seaweed"),
        WordBuilderEntry(word: "loom", definition: "A device for weaving fabric"),
        WordBuilderEntry(word: "maze", definition: "A complex network of paths or passages"),
        WordBuilderEntry(word: "oath", definition: "A solemn promise"),
        WordBuilderEntry(word: "pawn", definition: "The smallest chess piece"),
        WordBuilderEntry(word: "reed", definition: "A tall grass that grows in water"),
        WordBuilderEntry(word: "sled", definition: "A vehicle on runners for travelling on snow"),
        WordBuilderEntry(word: "tusk", definition: "A long pointed tooth"),
        WordBuilderEntry(word: "vale", definition: "A valley"),
        WordBuilderEntry(word: "wren", definition: "A small brown songbird"),
        WordBuilderEntry(word: "yoke", definition: "A wooden beam for joining two oxen"),
        WordBuilderEntry(word: "bolt", definition: "A metal pin used to fasten things"),
        WordBuilderEntry(word: "cove", definition: "A small sheltered bay"),
        WordBuilderEntry(word: "dusk", definition: "The time just before nightfall"),
        WordBuilderEntry(word: "flax", definition: "A plant used to make linen"),
        WordBuilderEntry(word: "gust", definition: "A sudden strong wind"),
        WordBuilderEntry(word: "husk", definition: "The outer covering of a seed"),
        WordBuilderEntry(word: "knot", definition: "A fastening made by tying rope"),
        WordBuilderEntry(word: "lamp", definition: "A device that produces light"),
    ]

    static let mediumWords: [WordBuilderEntry] = [
        WordBuilderEntry(word: "anchor", definition: "A heavy object that holds a ship in place"),
        WordBuilderEntry(word: "branch", definition: "A part of a tree growing from the trunk"),
        WordBuilderEntry(word: "breeze", definition: "A gentle, light wind"),
        WordBuilderEntry(word: "candle", definition: "A cylinder of wax with a wick for light"),
        WordBuilderEntry(word: "castle", definition: "A large fortified building"),
        WordBuilderEntry(word: "centre", definition: "The middle point of something"),
        WordBuilderEntry(word: "colour", definition: "The property of reflecting light of a particular wavelength"),
        WordBuilderEntry(word: "crayon", definition: "A coloured wax stick for drawing"),
        WordBuilderEntry(word: "desert", definition: "A dry, barren area with little rainfall"),
        WordBuilderEntry(word: "falcon", definition: "A bird of prey known for speed"),
        WordBuilderEntry(word: "fibre", definition: "A thread or strand of natural or synthetic material"),
        WordBuilderEntry(word: "fossil", definition: "Preserved remains of an ancient organism"),
        WordBuilderEntry(word: "garden", definition: "An area where plants are cultivated"),
        WordBuilderEntry(word: "gentle", definition: "Mild, kind, or soft in nature"),
        WordBuilderEntry(word: "global", definition: "Relating to the whole world"),
        WordBuilderEntry(word: "harbor", definition: "A sheltered body of water for ships"),
        WordBuilderEntry(word: "honest", definition: "Truthful and sincere"),
        WordBuilderEntry(word: "island", definition: "A piece of land surrounded by water"),
        WordBuilderEntry(word: "jungle", definition: "A dense tropical forest"),
        WordBuilderEntry(word: "kennel", definition: "A shelter for a dog"),
        WordBuilderEntry(word: "launch", definition: "To send forth with force"),
        WordBuilderEntry(word: "marble", definition: "A hard crystalline rock or a small glass ball"),
        WordBuilderEntry(word: "nature", definition: "The natural world and its phenomena"),
        WordBuilderEntry(word: "orange", definition: "A citrus fruit or a colour"),
        WordBuilderEntry(word: "palace", definition: "The official residence of a sovereign"),
        WordBuilderEntry(word: "planet", definition: "A large celestial body orbiting a star"),
        WordBuilderEntry(word: "plough", definition: "A farm tool used to turn soil"),
        WordBuilderEntry(word: "puzzle", definition: "A problem designed for amusement"),
        WordBuilderEntry(word: "quartz", definition: "A hard mineral found in many rocks"),
        WordBuilderEntry(word: "radish", definition: "A small red root vegetable"),
        WordBuilderEntry(word: "salmon", definition: "A large fish prized as food"),
        WordBuilderEntry(word: "shadow", definition: "A dark area produced by blocking light"),
        WordBuilderEntry(word: "silver", definition: "A shiny white precious metal"),
        WordBuilderEntry(word: "stream", definition: "A small, narrow river"),
        WordBuilderEntry(word: "temple", definition: "A building devoted to worship"),
        WordBuilderEntry(word: "throne", definition: "A ceremonial chair for a monarch"),
        WordBuilderEntry(word: "travel", definition: "To go from one place to another"),
        WordBuilderEntry(word: "trophy", definition: "A prize for winning a competition"),
        WordBuilderEntry(word: "tunnel", definition: "An underground passage"),
        WordBuilderEntry(word: "valley", definition: "A low area between hills or mountains"),
        WordBuilderEntry(word: "velvet", definition: "A soft, luxurious fabric"),
        WordBuilderEntry(word: "walrus", definition: "A large Arctic marine mammal with tusks"),
        WordBuilderEntry(word: "winter", definition: "The coldest season of the year"),
        WordBuilderEntry(word: "beaver", definition: "A large rodent that builds dams"),
        WordBuilderEntry(word: "canopy", definition: "An overhanging covering or shelter"),
        WordBuilderEntry(word: "dragon", definition: "A mythical fire-breathing creature"),
        WordBuilderEntry(word: "frosty", definition: "Covered with or producing frost"),
        WordBuilderEntry(word: "glacier", definition: "A slowly moving mass of ice"),
        WordBuilderEntry(word: "honour", definition: "Great respect or high esteem"),
        WordBuilderEntry(word: "meteor", definition: "A streak of light from space debris"),
        WordBuilderEntry(word: "ribbon", definition: "A narrow strip of fabric"),
    ]

    static let hardWords: [WordBuilderEntry] = [
        WordBuilderEntry(word: "absolute", definition: "Complete and total; not limited"),
        WordBuilderEntry(word: "backbone", definition: "The spine; the main support"),
        WordBuilderEntry(word: "balcony", definition: "A platform projecting from a building"),
        WordBuilderEntry(word: "blanket", definition: "A large piece of warm fabric for bedding"),
        WordBuilderEntry(word: "borough", definition: "A town or district with local government"),
        WordBuilderEntry(word: "cabinet", definition: "A piece of furniture with shelves or drawers"),
        WordBuilderEntry(word: "captain", definition: "The leader of a team or ship"),
        WordBuilderEntry(word: "century", definition: "A period of one hundred years"),
        WordBuilderEntry(word: "chamber", definition: "A large room or enclosed space"),
        WordBuilderEntry(word: "climate", definition: "The weather conditions in a region over time"),
        WordBuilderEntry(word: "compass", definition: "An instrument showing magnetic north"),
        WordBuilderEntry(word: "courage", definition: "The ability to face danger without fear"),
        WordBuilderEntry(word: "defence", definition: "The act of protecting from attack"),
        WordBuilderEntry(word: "diamond", definition: "A precious gemstone of pure carbon"),
        WordBuilderEntry(word: "dolphin", definition: "An intelligent marine mammal"),
        WordBuilderEntry(word: "eclipse", definition: "An obscuring of light from a celestial body"),
        WordBuilderEntry(word: "economy", definition: "The system of production and trade in a region"),
        WordBuilderEntry(word: "elegant", definition: "Graceful and stylish in appearance"),
        WordBuilderEntry(word: "fantasy", definition: "An imagined situation or sequence of events"),
        WordBuilderEntry(word: "feather", definition: "A flat structure forming a bird's plumage"),
        WordBuilderEntry(word: "forward", definition: "Towards the front; in advance"),
        WordBuilderEntry(word: "freedom", definition: "The state of being free"),
        WordBuilderEntry(word: "gallery", definition: "A room or building for displaying art"),
        WordBuilderEntry(word: "gravity", definition: "The force that attracts objects to Earth"),
        WordBuilderEntry(word: "habitat", definition: "The natural home of an organism"),
        WordBuilderEntry(word: "harbour", definition: "A sheltered port for ships"),
        WordBuilderEntry(word: "horizon", definition: "The line where earth meets sky"),
        WordBuilderEntry(word: "journey", definition: "An act of travelling from one place to another"),
        WordBuilderEntry(word: "justice", definition: "Fairness and moral rightness"),
        WordBuilderEntry(word: "kingdom", definition: "A country ruled by a king or queen"),
        WordBuilderEntry(word: "lantern", definition: "A lamp with a protective case"),
        WordBuilderEntry(word: "library", definition: "A building housing a collection of books"),
        WordBuilderEntry(word: "mammoth", definition: "An extinct large hairy elephant"),
        WordBuilderEntry(word: "mystery", definition: "Something difficult to understand or explain"),
        WordBuilderEntry(word: "narwhal", definition: "An Arctic whale with a long spiral tusk"),
        WordBuilderEntry(word: "nervous", definition: "Easily agitated or anxious"),
        WordBuilderEntry(word: "observe", definition: "To watch carefully; to notice"),
        WordBuilderEntry(word: "octagon", definition: "A shape with eight sides"),
        WordBuilderEntry(word: "orchard", definition: "A piece of land with fruit trees"),
        WordBuilderEntry(word: "passage", definition: "A way through or along something"),
        WordBuilderEntry(word: "pattern", definition: "A repeated decorative design"),
        WordBuilderEntry(word: "penguin", definition: "A flightless seabird of the Southern Hemisphere"),
        WordBuilderEntry(word: "pyramid", definition: "A structure with triangular sides meeting at a point"),
        WordBuilderEntry(word: "rainbow", definition: "An arc of colours in the sky"),
        WordBuilderEntry(word: "shelter", definition: "A place giving protection from weather"),
        WordBuilderEntry(word: "silence", definition: "Complete absence of sound"),
        WordBuilderEntry(word: "surplus", definition: "An amount beyond what is needed"),
        WordBuilderEntry(word: "thunder", definition: "The loud sound following lightning"),
        WordBuilderEntry(word: "triumph", definition: "A great victory or achievement"),
        WordBuilderEntry(word: "uniform", definition: "A set of standardised clothing"),
        WordBuilderEntry(word: "veteran", definition: "A person with long experience"),
        WordBuilderEntry(word: "volcano", definition: "A mountain that erupts lava"),
        WordBuilderEntry(word: "warrior", definition: "A brave or experienced fighter"),
    ]
}

// MARK: - Confetti View

struct WordBuilderConfettiView: View {
    let trigger: Int
    @State private var particles: [WordBuilderConfettiParticle] = []
    @State private var animating = false

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: animating ? particle.endX : particle.startX,
                        y: animating ? particle.endY : particle.startY
                    )
                    .opacity(animating ? 0 : 1)
            }
        }
        .onAppear {
            particles = (0..<30).map { _ in
                WordBuilderConfettiParticle(
                    color: [Color.purple, .blue, .orange, .green, .pink, .yellow].randomElement()!,
                    size: CGFloat.random(in: 4...10),
                    startX: 0, startY: 0,
                    endX: CGFloat.random(in: -180...180),
                    endY: CGFloat.random(in: -300 ... -50)
                )
            }
            withAnimation(.easeOut(duration: 1.5)) {
                animating = true
            }
        }
    }
}

struct WordBuilderConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WordBuilderView()
    }
}
