import SwiftUI

// MARK: - Spelling Bee View

struct SpellingBeeView: View {
    @State private var gradeRange: SpellingGradeRange = .grade4to5
    @State private var currentWordIndex = 0
    @State private var typedSpelling = ""
    @State private var lives = 3
    @State private var score = 0
    @State private var round = 1
    @State private var streak = 0
    @State private var showResult: SpellingResult? = nil
    @State private var showSentence = false
    @State private var gameOver = false
    @State private var perfectRound = true
    @State private var wordsInRound = 0
    @State private var roundSize = 5
    @State private var confettiTrigger = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var usedIndices: Set<Int> = []
    @State private var heartScale: CGFloat = 1.0
    @State private var showWordReveal = false

    @AppStorage("spellingBeeHighScore") private var highScore = 0
    @AppStorage("spellingBeeBestStreak") private var bestStreak = 0

    @Environment(\.dismiss) private var dismiss

    private var currentWords: [SpellingWord] {
        gradeRange.words
    }

    private var currentWord: SpellingWord? {
        guard currentWordIndex < currentWords.count else { return nil }
        return currentWords[currentWordIndex]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerStats
                gradeSelector

                if gameOver {
                    gameOverSection
                } else if let word = currentWord {
                    livesDisplay
                    definitionCard(word: word)
                    spellingInput
                    keyboardDisplay
                    submitButton
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Spelling Bee")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pickNewWord() }
        .overlay {
            if confettiTrigger > 0 {
                SpellingConfettiOverlay(trigger: confettiTrigger)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Header Stats

    private var headerStats: some View {
        HStack(spacing: 0) {
            statCell(icon: "star.fill", value: "\(score)", label: "Score", color: .orange)
            cellDivider
            statCell(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .red)
            cellDivider
            statCell(icon: "flag.fill", value: "Rd \(round)", label: "Round", color: .blue)
            cellDivider
            statCell(icon: "trophy.fill", value: "\(highScore)", label: "Best", color: .yellow)
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
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

    private var cellDivider: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 36)
    }

    // MARK: - Grade Selector

    private var gradeSelector: some View {
        Picker("Grade Range", selection: $gradeRange) {
            ForEach(SpellingGradeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: gradeRange) { _, _ in
            resetGame()
        }
    }

    // MARK: - Lives Display

    private var livesDisplay: some View {
        HStack(spacing: 6) {
            Text("Lives:")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(index < lives ? .red : .gray.opacity(0.3))
                    .scaleEffect(index == lives - 1 ? heartScale : 1.0)
            }

            Spacer()

            Text("Round \(round) - Word \(wordsInRound + 1)/\(roundSize)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Definition Card

    private func definitionCard(word: SpellingWord) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(.purple)
                Text("Spell This Word")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    Text(word.definition)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 12))

                if showSentence {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(.green)
                            .font(.title3)
                        Text("\"" + word.sentence + "\"")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08), in: .rect(cornerRadius: 12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Button {
                    withAnimation(.snappy) { showSentence.toggle() }
                } label: {
                    Label(
                        showSentence ? "Hide Sentence" : "Show Example Sentence",
                        systemImage: showSentence ? "eye.slash" : "eye"
                    )
                    .font(.caption.bold())
                }
                .tint(.green)
            }

            if showResult != nil {
                resultBanner
            }

            if showWordReveal, let word = currentWord {
                HStack(spacing: 8) {
                    Image(systemName: "character.textbox")
                        .foregroundStyle(.orange)
                    Text("Correct spelling: ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(word.word)
                        .font(.headline.bold())
                        .foregroundStyle(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Result Banner

    private var resultBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: showResult == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(showResult == .correct ? .green : .red)
            Text(showResult == .correct ? "Correct! Well done!" : "Incorrect!")
                .font(.headline)
                .foregroundStyle(showResult == .correct ? .green : .red)
            Spacer()
        }
        .padding(12)
        .background(
            (showResult == .correct ? Color.green : Color.red).opacity(0.1),
            in: .rect(cornerRadius: 12)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Spelling Input

    private var spellingInput: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.indigo)
                Text("Your Spelling")
                    .font(.headline)
                Spacer()
                Text("\(typedSpelling.count) letters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Type the word here...", text: $typedSpelling)
                .font(.title3.bold())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.indigo.opacity(0.3), lineWidth: 1.5)
                )
                .disabled(showResult != nil)
                .offset(x: shakeOffset)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Keyboard Display

    private var keyboardDisplay: some View {
        VStack(spacing: 6) {
            let typed = typedSpelling.lowercased()
            let letters = Array(typed)

            if !letters.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { _, char in
                        Text(String(char).uppercased())
                            .font(.caption.bold().monospaced())
                            .frame(width: 26, height: 30)
                            .background(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.2), .purple.opacity(0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                in: .rect(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.indigo.opacity(0.3), lineWidth: 1)
                            )
                            .transition(.scale)
                    }
                }
                .animation(.snappy, value: typedSpelling)
            } else {
                Text("Start typing to see your letters appear")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Group {
            if showResult == nil {
                Button {
                    checkSpelling()
                } label: {
                    Label("Check Spelling", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(typedSpelling.trimmingCharacters(in: .whitespaces).isEmpty)
                .sensoryFeedback(.impact, trigger: showResult != nil)
            } else {
                Button {
                    advanceToNext()
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

    private var gameOverSection: some View {
        VStack(spacing: 24) {
            Image(systemName: lives > 0 ? "party.popper.fill" : "heart.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(lives > 0 ? .yellow : .red)
                .symbolEffect(.bounce, value: gameOver)

            Text(lives > 0 ? "All Rounds Complete!" : "Game Over!")
                .font(.largeTitle.bold())

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("Final Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(round - 1)")
                        .font(.title.bold())
                        .foregroundStyle(.blue)
                    Text("Rounds")
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
                Label("New High Score!", systemImage: "crown.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .padding(12)
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

    private func pickNewWord() {
        let words = currentWords
        if usedIndices.count >= words.count {
            usedIndices.removeAll()
        }

        var idx: Int
        repeat {
            idx = Int.random(in: 0..<words.count)
        } while usedIndices.contains(idx)

        usedIndices.insert(idx)
        currentWordIndex = idx
        typedSpelling = ""
        showResult = nil
        showSentence = false
        showWordReveal = false
    }

    private func checkSpelling() {
        guard let word = currentWord else { return }
        let correct = typedSpelling.trimmingCharacters(in: .whitespaces).lowercased() == word.word.lowercased()

        if correct {
            withAnimation(.spring) {
                showResult = .correct
            }
            let wordPoints = word.word.count * 10 + (streak * 5)
            score += wordPoints
            streak += 1
            if streak > bestStreak { bestStreak = streak }
            if score > highScore { highScore = score }
            confettiTrigger += 1
        } else {
            withAnimation(.spring) {
                showResult = .incorrect
                showWordReveal = true
                perfectRound = false
            }
            lives -= 1
            streak = 0

            withAnimation(.default.repeatCount(4, autoreverses: true).speed(6)) {
                shakeOffset = 10
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                shakeOffset = 0
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                heartScale = 1.4
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring) { heartScale = 1.0 }
            }

            if lives <= 0 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    withAnimation(.spring) { gameOver = true }
                }
            }
        }
    }

    private func advanceToNext() {
        wordsInRound += 1
        if wordsInRound >= roundSize {
            if perfectRound {
                score += 50
                confettiTrigger += 1
            }
            round += 1
            wordsInRound = 0
            perfectRound = true
            roundSize = min(10, roundSize + 1)
        }
        pickNewWord()
    }

    private func resetGame() {
        lives = 3
        score = 0
        round = 1
        streak = 0
        wordsInRound = 0
        roundSize = 5
        perfectRound = true
        gameOver = false
        usedIndices.removeAll()
        pickNewWord()
    }
}

// MARK: - Supporting Types

enum SpellingResult {
    case correct, incorrect
}

enum SpellingGradeRange: String, CaseIterable, Identifiable {
    case grade4to5 = "Gr 4-5"
    case grade6to7 = "Gr 6-7"
    case grade8to9 = "Gr 8-9"
    case grade10to12 = "Gr 10-12"

    var id: String { rawValue }

    var words: [SpellingWord] {
        switch self {
        case .grade4to5: return SpellingGradeRange.grade4to5Words
        case .grade6to7: return SpellingGradeRange.grade6to7Words
        case .grade8to9: return SpellingGradeRange.grade8to9Words
        case .grade10to12: return SpellingGradeRange.grade10to12Words
        }
    }

    static let grade4to5Words: [SpellingWord] = [
        SpellingWord(word: "colour", definition: "The quality of an object that produces different sensations on the eye", sentence: "Her favourite colour is blue."),
        SpellingWord(word: "favourite", definition: "Preferred above all others of the same kind", sentence: "Hockey is my favourite sport."),
        SpellingWord(word: "neighbour", definition: "A person living near or next door", sentence: "Our neighbour has a friendly dog."),
        SpellingWord(word: "honour", definition: "Great respect and admiration", sentence: "It is an honour to meet you."),
        SpellingWord(word: "centre", definition: "The middle point of something", sentence: "The library is in the centre of town."),
        SpellingWord(word: "theatre", definition: "A building where plays are performed", sentence: "We watched a play at the theatre."),
        SpellingWord(word: "behaviour", definition: "The way in which one acts or conducts oneself", sentence: "Good behaviour is expected in class."),
        SpellingWord(word: "practise", definition: "To perform an activity repeatedly to improve", sentence: "You must practise piano every day."),
        SpellingWord(word: "defence", definition: "The action of protecting from attack", sentence: "The castle had a strong defence."),
        SpellingWord(word: "programme", definition: "A planned series of events or performances", sentence: "The school programme starts in September."),
        SpellingWord(word: "harbour", definition: "A sheltered area of water for ships", sentence: "The boats were safe in the harbour."),
        SpellingWord(word: "rumour", definition: "A story passed around that may not be true", sentence: "There was a rumour about a snow day."),
        SpellingWord(word: "flavour", definition: "The taste of food or drink", sentence: "Maple is a popular flavour in Canada."),
        SpellingWord(word: "fibre", definition: "A thread or strand of material", sentence: "Whole grains are high in fibre."),
        SpellingWord(word: "litre", definition: "A unit of liquid measurement", sentence: "Please buy a litre of milk."),
        SpellingWord(word: "metre", definition: "A unit of length equal to 100 centimetres", sentence: "The pool is twenty-five metres long."),
        SpellingWord(word: "catalogue", definition: "A complete list of items in a collection", sentence: "She browsed the library catalogue."),
        SpellingWord(word: "dialogue", definition: "A conversation between two or more people", sentence: "The dialogue in the play was funny."),
        SpellingWord(word: "beautiful", definition: "Pleasing to the senses or mind", sentence: "The sunset was beautiful."),
        SpellingWord(word: "different", definition: "Not the same as another", sentence: "Every snowflake is different."),
        SpellingWord(word: "important", definition: "Of great significance or value", sentence: "It is important to be kind."),
        SpellingWord(word: "beginning", definition: "The point in time when something starts", sentence: "The beginning of the story was exciting."),
        SpellingWord(word: "adventure", definition: "An exciting experience or journey", sentence: "Camping was a great adventure."),
        SpellingWord(word: "together", definition: "With each other; in company", sentence: "We worked together on the project."),
        SpellingWord(word: "calendar", definition: "A chart showing days, weeks, and months", sentence: "Mark the date on your calendar."),
        SpellingWord(word: "surprise", definition: "An unexpected event or thing", sentence: "The party was a wonderful surprise."),
        SpellingWord(word: "although", definition: "In spite of the fact that", sentence: "Although it rained, we had fun."),
        SpellingWord(word: "strength", definition: "The quality of being physically strong", sentence: "Teamwork is our greatest strength."),
        SpellingWord(word: "Canadian", definition: "Relating to or from Canada", sentence: "She is proud to be Canadian."),
        SpellingWord(word: "knowledge", definition: "Facts and information acquired through experience", sentence: "Reading builds knowledge."),
        SpellingWord(word: "exercise", definition: "Physical activity done to stay healthy", sentence: "Daily exercise is good for you."),
        SpellingWord(word: "paragraph", definition: "A section of writing with a main idea", sentence: "Start a new paragraph for each idea."),
    ]

    static let grade6to7Words: [SpellingWord] = [
        SpellingWord(word: "acknowledgement", definition: "Recognition or acceptance of something", sentence: "The author wrote an acknowledgement page."),
        SpellingWord(word: "organisation", definition: "An organised group of people with a purpose", sentence: "The organisation helps protect wildlife."),
        SpellingWord(word: "marvellous", definition: "Causing great wonder; extraordinary", sentence: "The fireworks display was marvellous."),
        SpellingWord(word: "travelling", definition: "Going from one place to another", sentence: "We are travelling across Canada this summer."),
        SpellingWord(word: "cancelled", definition: "Decided that something will not take place", sentence: "The game was cancelled due to rain."),
        SpellingWord(word: "jewellery", definition: "Decorative items worn for personal adornment", sentence: "She received jewellery for her birthday."),
        SpellingWord(word: "manoeuvre", definition: "A movement or series of moves requiring skill", sentence: "The pilot performed a difficult manoeuvre."),
        SpellingWord(word: "encyclopaedia", definition: "A comprehensive reference work", sentence: "She looked it up in the encyclopaedia."),
        SpellingWord(word: "aluminium", definition: "A lightweight silvery metal", sentence: "The can is made of aluminium."),
        SpellingWord(word: "neighbourhood", definition: "A district or community within a town or city", sentence: "Our neighbourhood has a great park."),
        SpellingWord(word: "councillor", definition: "A member of a council", sentence: "The councillor spoke at the meeting."),
        SpellingWord(word: "apologise", definition: "To express regret for something done wrong", sentence: "You should apologise for being late."),
        SpellingWord(word: "recognise", definition: "To identify someone or something previously known", sentence: "I did not recognise her at first."),
        SpellingWord(word: "specialise", definition: "To focus on a particular area or skill", sentence: "Doctors often specialise in one field."),
        SpellingWord(word: "analyse", definition: "To examine something in detail", sentence: "We need to analyse the results carefully."),
        SpellingWord(word: "emphasise", definition: "To give special importance to something", sentence: "The teacher wanted to emphasise safety."),
        SpellingWord(word: "environment", definition: "The natural world and surroundings", sentence: "We must protect the environment."),
        SpellingWord(word: "government", definition: "The group of people who govern a country", sentence: "The government announced new policies."),
        SpellingWord(word: "temperature", definition: "The degree of heat or cold measured on a scale", sentence: "The temperature dropped below zero."),
        SpellingWord(word: "opportunity", definition: "A chance for advancement or progress", sentence: "This is a great opportunity to learn."),
        SpellingWord(word: "independence", definition: "The state of being free from outside control", sentence: "Canada celebrates its independence each year."),
        SpellingWord(word: "conscience", definition: "An inner feeling about right and wrong", sentence: "Her conscience told her to be honest."),
        SpellingWord(word: "equivalent", definition: "Equal in value, amount, or function", sentence: "One kilometre is equivalent to 1000 metres."),
        SpellingWord(word: "exaggerate", definition: "To make something seem larger or more important", sentence: "Do not exaggerate the size of the fish."),
        SpellingWord(word: "guarantee", definition: "A promise that something will happen", sentence: "The product comes with a guarantee."),
        SpellingWord(word: "parliament", definition: "The legislative body of a country", sentence: "Parliament passed the new law."),
        SpellingWord(word: "privilege", definition: "A special right or advantage", sentence: "Voting is both a right and a privilege."),
        SpellingWord(word: "prejudice", definition: "An unfair opinion formed without knowledge", sentence: "We must stand against prejudice."),
        SpellingWord(word: "sufficient", definition: "Enough; adequate for the purpose", sentence: "Is there sufficient time to finish?"),
        SpellingWord(word: "technique", definition: "A particular way of doing something", sentence: "She learned a new painting technique."),
        SpellingWord(word: "thoroughly", definition: "In a complete and careful way", sentence: "Read the instructions thoroughly."),
    ]

    static let grade8to9Words: [SpellingWord] = [
        SpellingWord(word: "accommodation", definition: "A place to live or stay", sentence: "We booked accommodation near the lake."),
        SpellingWord(word: "acquaintance", definition: "A person one knows slightly", sentence: "He is an acquaintance from school."),
        SpellingWord(word: "bureaucracy", definition: "A system of government with many rules and procedures", sentence: "The bureaucracy slowed down the process."),
        SpellingWord(word: "catastrophe", definition: "A sudden disaster causing great damage", sentence: "The flood was a catastrophe for the town."),
        SpellingWord(word: "contemporary", definition: "Belonging to the same time period; modern", sentence: "The gallery features contemporary art."),
        SpellingWord(word: "correspondence", definition: "Written communication between people", sentence: "She maintained correspondence with her pen pal."),
        SpellingWord(word: "deteriorate", definition: "To become progressively worse", sentence: "The old building began to deteriorate."),
        SpellingWord(word: "entrepreneur", definition: "A person who starts and runs businesses", sentence: "The young entrepreneur launched a tech company."),
        SpellingWord(word: "extravagant", definition: "Exceeding what is reasonable; lavish", sentence: "The decorations were quite extravagant."),
        SpellingWord(word: "harassment", definition: "Aggressive behaviour that intimidates", sentence: "The school has a zero-tolerance policy for harassment."),
        SpellingWord(word: "hierarchical", definition: "Arranged in order of rank or importance", sentence: "The company has a hierarchical structure."),
        SpellingWord(word: "idiosyncrasy", definition: "A distinctive personal peculiarity", sentence: "Each writer has their own idiosyncrasy."),
        SpellingWord(word: "immediately", definition: "At once; without any delay", sentence: "Please respond immediately."),
        SpellingWord(word: "independent", definition: "Free from outside control", sentence: "She is a very independent thinker."),
        SpellingWord(word: "Mediterranean", definition: "Relating to the sea between Europe and Africa", sentence: "They vacationed on the Mediterranean coast."),
        SpellingWord(word: "miscellaneous", definition: "Of various types or from various sources", sentence: "The drawer was full of miscellaneous items."),
        SpellingWord(word: "occasionally", definition: "From time to time; sometimes", sentence: "We occasionally visit the museum."),
        SpellingWord(word: "perseverance", definition: "Continued effort despite difficulties", sentence: "Perseverance led to her success."),
        SpellingWord(word: "phenomenon", definition: "A remarkable occurrence or fact", sentence: "The northern lights are a beautiful phenomenon."),
        SpellingWord(word: "questionnaire", definition: "A set of printed questions for a survey", sentence: "Please complete the questionnaire."),
        SpellingWord(word: "reconnaissance", definition: "Military observation of a region", sentence: "The team conducted a reconnaissance of the area."),
        SpellingWord(word: "rendezvous", definition: "A meeting at an agreed time and place", sentence: "The rendezvous point was the old bridge."),
        SpellingWord(word: "surveillance", definition: "Close observation of a person or group", sentence: "The building has surveillance cameras."),
        SpellingWord(word: "symmetrical", definition: "Made up of exactly similar parts on each side", sentence: "The butterfly has symmetrical wings."),
        SpellingWord(word: "temperament", definition: "A person's nature affecting their behaviour", sentence: "The horse had a calm temperament."),
        SpellingWord(word: "unnecessary", definition: "Not needed; more than is needed", sentence: "Avoid unnecessary waste of paper."),
        SpellingWord(word: "veterinarian", definition: "A doctor who treats animals", sentence: "The veterinarian cared for the injured cat."),
        SpellingWord(word: "vulnerability", definition: "The quality of being open to harm", sentence: "The report highlighted the vulnerability of the system."),
        SpellingWord(word: "wholesome", definition: "Good for health and well-being", sentence: "A wholesome meal includes vegetables."),
        SpellingWord(word: "conscientious", definition: "Wishing to do what is right; thorough", sentence: "She is a conscientious student."),
        SpellingWord(word: "reminiscence", definition: "A memory of a past experience", sentence: "He shared a fond reminiscence of childhood."),
    ]

    static let grade10to12Words: [SpellingWord] = [
        SpellingWord(word: "anaesthesia", definition: "Insensitivity to pain induced by drugs", sentence: "The surgeon used anaesthesia before the operation."),
        SpellingWord(word: "bourgeoisie", definition: "The middle class, typically with materialistic values", sentence: "The novel critiqued the bourgeoisie."),
        SpellingWord(word: "connoisseur", definition: "An expert judge in matters of fine art or taste", sentence: "She is a connoisseur of fine art."),
        SpellingWord(word: "acquiesce", definition: "To accept something reluctantly without protest", sentence: "He decided to acquiesce to their demands."),
        SpellingWord(word: "disillusioned", definition: "Disappointed by discovering something is not as good as believed", sentence: "She became disillusioned with politics."),
        SpellingWord(word: "efficacious", definition: "Successful in producing a desired result", sentence: "The treatment proved efficacious."),
        SpellingWord(word: "haemorrhage", definition: "An escape of blood from a ruptured blood vessel", sentence: "The doctor worked to stop the haemorrhage."),
        SpellingWord(word: "idiosyncratic", definition: "Peculiar or individual in nature", sentence: "His idiosyncratic style made him famous."),
        SpellingWord(word: "juxtaposition", definition: "Placing two things close together for comparison", sentence: "The juxtaposition of old and new architecture was striking."),
        SpellingWord(word: "kaleidoscope", definition: "A constantly changing pattern or sequence", sentence: "The festival was a kaleidoscope of colour."),
        SpellingWord(word: "liaison", definition: "Communication or cooperation between groups", sentence: "She served as a liaison between the departments."),
        SpellingWord(word: "metamorphosis", definition: "A transformation or change of form", sentence: "The caterpillar underwent metamorphosis."),
        SpellingWord(word: "onomatopoeia", definition: "A word that imitates the sound it represents", sentence: "Buzz is an example of onomatopoeia."),
        SpellingWord(word: "pharmaceutical", definition: "Relating to the preparation of medicinal drugs", sentence: "She works in the pharmaceutical industry."),
        SpellingWord(word: "reconnaissance", definition: "Military observation of a region to gather information", sentence: "They conducted reconnaissance before the mission."),
        SpellingWord(word: "surreptitious", definition: "Kept secret because it would not be approved of", sentence: "He cast a surreptitious glance at the clock."),
        SpellingWord(word: "ubiquitous", definition: "Present, appearing, or found everywhere", sentence: "Smartphones have become ubiquitous."),
        SpellingWord(word: "verisimilitude", definition: "The appearance of being true or real", sentence: "The novel achieved great verisimilitude."),
        SpellingWord(word: "chrysanthemum", definition: "A colourful garden flower", sentence: "The chrysanthemum bloomed in autumn."),
        SpellingWord(word: "entrepreneurial", definition: "Relating to starting and running businesses", sentence: "She had an entrepreneurial spirit."),
        SpellingWord(word: "acknowledgeable", definition: "Able to be acknowledged or recognised", sentence: "His contributions were easily acknowledgeable."),
        SpellingWord(word: "irreconcilable", definition: "Impossible to resolve or settle", sentence: "They had irreconcilable differences."),
        SpellingWord(word: "manoeuvrability", definition: "The quality of being easy to move or direct", sentence: "The aircraft had excellent manoeuvrability."),
        SpellingWord(word: "ostentatious", definition: "Designed to impress or attract notice", sentence: "The mansion was ostentatious."),
        SpellingWord(word: "quintessential", definition: "Representing the most perfect example", sentence: "Poutine is the quintessential Canadian dish."),
        SpellingWord(word: "serendipitous", definition: "Occurring by chance in a happy way", sentence: "Their meeting was entirely serendipitous."),
        SpellingWord(word: "unequivocal", definition: "Leaving no doubt; unambiguous", sentence: "The answer was unequivocal."),
        SpellingWord(word: "vindication", definition: "The act of clearing someone of blame or suspicion", sentence: "The evidence led to her vindication."),
        SpellingWord(word: "philanthropist", definition: "A person who promotes the welfare of others", sentence: "The philanthropist donated millions to education."),
        SpellingWord(word: "totalitarianism", definition: "A system of government requiring complete subservience", sentence: "The book explored the dangers of totalitarianism."),
        SpellingWord(word: "archaeological", definition: "Relating to the study of past human activity", sentence: "The archaeological dig uncovered ancient artifacts."),
    ]
}

struct SpellingWord: Identifiable {
    let id = UUID()
    let word: String
    let definition: String
    let sentence: String
}

// MARK: - Confetti Overlay

struct SpellingConfettiOverlay: View {
    let trigger: Int
    @State private var particles: [SpellingConfettiPiece] = []
    @State private var animating = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(animating ? p.rotation : 0))
                    .offset(x: animating ? p.endX : 0, y: animating ? p.endY : -20)
                    .opacity(animating ? 0 : 1)
            }
        }
        .onAppear {
            particles = (0..<40).map { _ in
                SpellingConfettiPiece(
                    color: [.purple, .blue, .orange, .green, .pink, .yellow, .red, .indigo].randomElement() ?? .purple,
                    width: CGFloat.random(in: 4...8),
                    height: CGFloat.random(in: 8...16),
                    rotation: Double.random(in: 0...720),
                    endX: CGFloat.random(in: -200...200),
                    endY: CGFloat.random(in: -350 ... -80)
                )
            }
            withAnimation(.easeOut(duration: 2.0)) {
                animating = true
            }
        }
    }
}

struct SpellingConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let endX: CGFloat
    let endY: CGFloat
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SpellingBeeView()
    }
}
