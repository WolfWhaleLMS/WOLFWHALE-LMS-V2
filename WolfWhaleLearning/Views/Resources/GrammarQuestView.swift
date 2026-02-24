import SwiftUI

// MARK: - Grammar Quest View

struct GrammarQuestView: View {
    @State private var activityType: GrammarActivityType = .fixSentence
    @State private var currentChallengeIndex = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showExplanation = false
    @State private var isCorrect: Bool? = nil
    @State private var score = 0
    @State private var streak = 0
    @State private var totalAnswered = 0
    @State private var difficultyLevel = 1
    @State private var usedIndices: Set<Int> = []
    @State private var shakeOffset: CGFloat = 0
    @State private var streakFireScale: CGFloat = 1.0

    @AppStorage("grammarQuestHighScore") private var highScore = 0
    @AppStorage("grammarQuestBestStreak") private var bestStreak = 0

    @Environment(\.dismiss) private var dismiss

    private var challenges: [GrammarChallenge] {
        activityType.challenges
    }

    private var currentChallenge: GrammarChallenge? {
        guard currentChallengeIndex < challenges.count else { return nil }
        return challenges[currentChallengeIndex]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsHeader
                activityPicker
                difficultyIndicator

                if let challenge = currentChallenge {
                    challengeCard(challenge)
                    optionsSection(challenge)

                    if showExplanation {
                        explanationCard(challenge)
                    }

                    actionButton
                } else {
                    noMoreChallenges
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grammar Quest")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pickChallenge() }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            questStat(icon: "star.fill", value: "\(score)", label: "Score", color: .orange)
            questDivider
            questStat(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .red)
            questDivider
            questStat(icon: "checkmark.circle.fill", value: "\(totalAnswered)", label: "Done", color: .green)
            questDivider
            questStat(icon: "trophy.fill", value: "\(highScore)", label: "Best", color: .yellow)
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func questStat(icon: String, value: String, label: String, color: Color) -> some View {
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

    private var questDivider: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 36)
    }

    // MARK: - Activity Picker

    private var activityPicker: some View {
        Picker("Activity", selection: $activityType) {
            ForEach(GrammarActivityType.allCases) { activity in
                Text(activity.rawValue).tag(activity)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: activityType) { _, _ in
            resetActivity()
        }
    }

    // MARK: - Difficulty Indicator

    private var difficultyIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .foregroundStyle(.indigo)

            Text("Difficulty:")
                .font(.subheadline.bold())

            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= difficultyLevel ? Color.indigo : Color.gray.opacity(0.2))
                    .frame(width: 10, height: 10)
            }

            Spacer()

            if streak >= 3 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .scaleEffect(streakFireScale)
                    Text("\(streak) streak!")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.12), in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Challenge Card

    private func challengeCard(_ challenge: GrammarChallenge) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: challenge.icon)
                    .foregroundStyle(.purple)
                    .font(.title3)
                Text(challenge.category)
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                Spacer()
                Text(activityType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(.purple)
            }

            Text(challenge.prompt)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(challenge.sentence)
                .font(.title3)
                .fontWeight(.medium)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.08), .purple.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                )
                .offset(x: shakeOffset)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Options Section

    private func optionsSection(_ challenge: GrammarChallenge) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(challenge.options.enumerated()), id: \.offset) { index, option in
                Button {
                    guard selectedAnswer == nil else { return }
                    withAnimation(.snappy) {
                        selectedAnswer = index
                        checkAnswer(challenge: challenge, selected: index)
                    }
                } label: {
                    HStack(spacing: 14) {
                        optionIndicator(index: index, correctIndex: challenge.correctAnswer)

                        Text(option)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedAnswer != nil && index == challenge.correctAnswer {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .transition(.scale)
                        } else if selectedAnswer == index && index != challenge.correctAnswer {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .transition(.scale)
                        }
                    }
                    .padding(14)
                    .background(optionBackground(index: index, correctIndex: challenge.correctAnswer), in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(optionBorder(index: index, correctIndex: challenge.correctAnswer), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedAnswer != nil)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedAnswer)
    }

    private func optionIndicator(index: Int, correctIndex: Int) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    selectedAnswer == index
                        ? (index == correctIndex ? Color.green : Color.red)
                        : .secondary.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if selectedAnswer == index {
                Circle()
                    .fill(index == correctIndex ? Color.green : Color.red)
                    .frame(width: 14, height: 14)
                    .transition(.scale)
            }
        }
    }

    private func optionBackground(index: Int, correctIndex: Int) -> some ShapeStyle {
        if selectedAnswer == nil {
            return AnyShapeStyle(Color(.tertiarySystemFill))
        }
        if index == correctIndex {
            return AnyShapeStyle(Color.green.opacity(0.1))
        }
        if selectedAnswer == index {
            return AnyShapeStyle(Color.red.opacity(0.1))
        }
        return AnyShapeStyle(Color(.tertiarySystemFill))
    }

    private func optionBorder(index: Int, correctIndex: Int) -> some ShapeStyle {
        if selectedAnswer == nil {
            return AnyShapeStyle(Color.clear)
        }
        if index == correctIndex {
            return AnyShapeStyle(Color.green)
        }
        if selectedAnswer == index {
            return AnyShapeStyle(Color.red)
        }
        return AnyShapeStyle(Color.clear)
    }

    // MARK: - Explanation Card

    private func explanationCard(_ challenge: GrammarChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Explanation")
                    .font(.headline)
            }

            Text(challenge.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isCorrect == true {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    let points = 10 + (streak * 2) + (difficultyLevel * 3)
                    Text("+\(points) points")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isCorrect == true ? Color.green : Color.orange).opacity(0.08),
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    (isCorrect == true ? Color.green : Color.orange).opacity(0.3),
                    lineWidth: 1
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if showExplanation {
                Button {
                    withAnimation(.snappy) { loadNextChallenge() }
                } label: {
                    Label("Next Challenge", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
    }

    // MARK: - No More Challenges

    private var noMoreChallenges: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text("All Done!")
                .font(.largeTitle.bold())

            Text("You have completed all \(activityType.rawValue) challenges.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
                    Text("\(totalAnswered)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Answered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                resetActivity()
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
    }

    // MARK: - Logic

    private func pickChallenge() {
        let all = challenges
        if usedIndices.count >= all.count {
            usedIndices.removeAll()
        }
        var idx: Int
        repeat {
            idx = Int.random(in: 0..<all.count)
        } while usedIndices.contains(idx)
        usedIndices.insert(idx)
        currentChallengeIndex = idx
        selectedAnswer = nil
        showExplanation = false
        isCorrect = nil
    }

    private func checkAnswer(challenge: GrammarChallenge, selected: Int) {
        let correct = selected == challenge.correctAnswer
        isCorrect = correct

        if correct {
            streak += 1
            let points = 10 + (streak * 2) + (difficultyLevel * 3)
            score += points
            if streak > bestStreak { bestStreak = streak }
            if score > highScore { highScore = score }

            if streak % 3 == 0 {
                difficultyLevel = min(5, difficultyLevel + 1)
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                streakFireScale = 1.4
            }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring) { streakFireScale = 1.0 }
            }
        } else {
            streak = 0
            difficultyLevel = max(1, difficultyLevel - 1)

            withAnimation(.default.repeatCount(4, autoreverses: true).speed(6)) {
                shakeOffset = 10
            }
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                shakeOffset = 0
            }
        }

        totalAnswered += 1

        withAnimation(.spring.delay(0.3)) {
            showExplanation = true
        }
    }

    private func loadNextChallenge() {
        pickChallenge()
    }

    private func resetActivity() {
        score = 0
        streak = 0
        totalAnswered = 0
        difficultyLevel = 1
        usedIndices.removeAll()
        pickChallenge()
    }
}

// MARK: - Supporting Types

enum GrammarActivityType: String, CaseIterable, Identifiable {
    case fixSentence = "Fix It"
    case partsOfSpeech = "Parts"
    case punctuation = "Punctuate"

    var id: String { rawValue }

    var challenges: [GrammarChallenge] {
        switch self {
        case .fixSentence: return GrammarActivityType.fixSentenceChallenges
        case .partsOfSpeech: return GrammarActivityType.partsOfSpeechChallenges
        case .punctuation: return GrammarActivityType.punctuationChallenges
        }
    }

    // MARK: - Fix the Sentence Challenges

    static let fixSentenceChallenges: [GrammarChallenge] = [
        GrammarChallenge(
            sentence: "The group of students are going to the library.",
            prompt: "Find and fix the grammar error:",
            options: ["The group of students is going to the library.", "The group of student are going to the library.", "The groups of students are going to the library.", "No change needed."],
            correctAnswer: 0,
            explanation: "Subject-verb agreement: 'group' is singular, so the verb should be 'is' not 'are'. The prepositional phrase 'of students' does not change the subject.",
            category: "Subject-Verb Agreement",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Him and me went to the store yesterday.",
            prompt: "Find and fix the grammar error:",
            options: ["Him and I went to the store yesterday.", "He and me went to the store yesterday.", "He and I went to the store yesterday.", "No change needed."],
            correctAnswer: 2,
            explanation: "Use subject pronouns (He, I) when they are the subject of the sentence. 'Him' and 'me' are object pronouns.",
            category: "Pronoun Usage",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Their going to there house over they're.",
            prompt: "Find and fix the grammar error:",
            options: ["They're going to their house over there.", "There going to their house over they're.", "Their going to they're house over there.", "No change needed."],
            correctAnswer: 0,
            explanation: "'They're' = they are. 'Their' = possessive (belonging to them). 'There' = a place. The correct version is: They're going to their house over there.",
            category: "Homophones",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Its important to know it's meaning.",
            prompt: "Find and fix the grammar error:",
            options: ["It's important to know its meaning.", "Its important to know its meaning.", "It's important to know it's meaning.", "No change needed."],
            correctAnswer: 0,
            explanation: "'It's' is a contraction of 'it is'. 'Its' is the possessive form. So: It's (it is) important to know its (possessive) meaning.",
            category: "Homophones",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "The dog wagged it's tail happily.",
            prompt: "Find and fix the grammar error:",
            options: ["The dog wagged its tail happily.", "The dog wagged its' tail happily.", "The dogs wagged it's tail happily.", "No change needed."],
            correctAnswer: 0,
            explanation: "'Its' (no apostrophe) is the possessive pronoun. 'It's' means 'it is'. The dog possesses the tail, so use 'its'.",
            category: "Apostrophes",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Your the best friend I ever had.",
            prompt: "Find and fix the grammar error:",
            options: ["You're the best friend I ever had.", "Your the best friend I ever have.", "You're the best friend I ever have.", "No change needed."],
            correctAnswer: 0,
            explanation: "'You're' is a contraction of 'you are'. 'Your' is possessive. 'You're (you are) the best friend' is correct.",
            category: "Homophones",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Each of the players have their own locker.",
            prompt: "Find and fix the grammar error:",
            options: ["Each of the players has their own locker.", "Each of the player have their own locker.", "Each of the players have his own locker.", "No change needed."],
            correctAnswer: 0,
            explanation: "'Each' is singular and takes a singular verb. 'Each has' is correct. Using 'their' with singular 'each' is accepted in modern Canadian English.",
            category: "Subject-Verb Agreement",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "I should of studied harder for the test.",
            prompt: "Find and fix the grammar error:",
            options: ["I should have studied harder for the test.", "I should of studied more harder for the test.", "I should of study harder for the test.", "No change needed."],
            correctAnswer: 0,
            explanation: "'Should have' (not 'should of') is the correct form. The confusion comes from the contraction 'should've' which sounds like 'should of'.",
            category: "Common Mistakes",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "The teacher learned the students about grammar.",
            prompt: "Find and fix the grammar error:",
            options: ["The teacher taught the students about grammar.", "The teacher learned the students grammar.", "The teacher learns the students about grammar.", "No change needed."],
            correctAnswer: 0,
            explanation: "'Teach' means to instruct others. 'Learn' means to gain knowledge yourself. The teacher taught (not learned) the students.",
            category: "Word Choice",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Me and Sarah is going to the concert tonight.",
            prompt: "Find and fix the grammar error:",
            options: ["Sarah and I are going to the concert tonight.", "Me and Sarah are going to the concert tonight.", "Sarah and me is going to the concert tonight.", "No change needed."],
            correctAnswer: 0,
            explanation: "Two fixes: (1) Use 'I' not 'me' as the subject. (2) Compound subjects use plural verb 'are'. Also, it is polite to put yourself last.",
            category: "Subject-Verb Agreement",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "I could care less about the outcome.",
            prompt: "Find and fix the grammar error:",
            options: ["I couldn't care less about the outcome.", "I could care fewer about the outcome.", "I could care least about the outcome.", "No change needed."],
            correctAnswer: 0,
            explanation: "The correct phrase is 'couldn't care less' meaning you care so little it's impossible to care any less. 'Could care less' implies you still do care somewhat.",
            category: "Common Mistakes",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "The amount of students in the class were large.",
            prompt: "Find and fix the grammar error:",
            options: ["The number of students in the class was large.", "The amount of students in the class was large.", "The amounts of students in the class were large.", "No change needed."],
            correctAnswer: 0,
            explanation: "Use 'number' for countable nouns (students) and 'amount' for uncountable nouns (water, sand). Also, 'number' is singular so use 'was'.",
            category: "Word Choice",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Running through the park the dog chased a squirrel.",
            prompt: "Fix the sentence structure:",
            options: ["Running through the park, the dog chased a squirrel.", "Running through the park the dog, chased a squirrel.", "Running, through the park the dog chased a squirrel.", "No change needed."],
            correctAnswer: 0,
            explanation: "An introductory phrase needs to be followed by a comma. 'Running through the park' is an introductory participial phrase.",
            category: "Comma Usage",
            icon: "pencil.and.outline"
        ),
        GrammarChallenge(
            sentence: "Everybody need to bring their textbook to class.",
            prompt: "Find and fix the grammar error:",
            options: ["Everybody needs to bring their textbook to class.", "Everybody need to bring his textbook to class.", "Everybody need to bring our textbooks to class.", "No change needed."],
            correctAnswer: 0,
            explanation: "'Everybody' is an indefinite pronoun that takes a singular verb: 'needs' not 'need'. Using 'their' with singular indefinite pronouns is accepted in modern Canadian English.",
            category: "Subject-Verb Agreement",
            icon: "pencil.and.outline"
        ),
    ]

    // MARK: - Parts of Speech Challenges

    static let partsOfSpeechChallenges: [GrammarChallenge] = [
        GrammarChallenge(
            sentence: "The brilliant scientist carefully examined the ancient fossil.",
            prompt: "Which word is an ADVERB?",
            options: ["brilliant", "carefully", "ancient", "fossil"],
            correctAnswer: 1,
            explanation: "'Carefully' is an adverb because it describes HOW the scientist examined. Adverbs often modify verbs and frequently end in '-ly'.",
            category: "Adverbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The playful puppy quickly chased the colourful butterfly.",
            prompt: "Which word is an ADJECTIVE?",
            options: ["quickly", "chased", "playful", "butterfly"],
            correctAnswer: 2,
            explanation: "'Playful' is an adjective because it describes the noun 'puppy'. Adjectives modify nouns and tell us what kind, which one, or how many.",
            category: "Adjectives",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "She nervously presented her research to the committee.",
            prompt: "Which word is the VERB?",
            options: ["nervously", "presented", "research", "committee"],
            correctAnswer: 1,
            explanation: "'Presented' is the verb because it shows the action. The subject 'she' presented something. Verbs express actions or states of being.",
            category: "Verbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The enormous whale swam gracefully through the deep ocean.",
            prompt: "Which word is a NOUN?",
            options: ["enormous", "swam", "gracefully", "ocean"],
            correctAnswer: 3,
            explanation: "'Ocean' is a noun because it names a place. Nouns are words that name people, places, things, or ideas.",
            category: "Nouns",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "My grandmother always bakes delicious cookies for us.",
            prompt: "Which word is an ADVERB?",
            options: ["delicious", "bakes", "always", "cookies"],
            correctAnswer: 2,
            explanation: "'Always' is an adverb of frequency. It tells us WHEN or HOW OFTEN grandmother bakes. Not all adverbs end in '-ly'.",
            category: "Adverbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The talented musician performed a beautiful melody yesterday.",
            prompt: "Which word is an ADJECTIVE?",
            options: ["performed", "yesterday", "beautiful", "musician"],
            correctAnswer: 2,
            explanation: "'Beautiful' is an adjective modifying the noun 'melody'. It describes what kind of melody was performed.",
            category: "Adjectives",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "Several curious students eagerly raised their hands.",
            prompt: "Which word is a VERB?",
            options: ["Several", "curious", "eagerly", "raised"],
            correctAnswer: 3,
            explanation: "'Raised' is the verb showing the action the students performed. They raised their hands.",
            category: "Verbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "Happiness spread quickly throughout the entire neighbourhood.",
            prompt: "Which word is a NOUN?",
            options: ["Happiness", "spread", "quickly", "entire"],
            correctAnswer: 0,
            explanation: "'Happiness' is an abstract noun. It names an idea or feeling. Not all nouns are physical things you can touch.",
            category: "Nouns",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The clever fox silently crept beneath the wooden fence.",
            prompt: "Which word is an ADVERB?",
            options: ["clever", "silently", "wooden", "beneath"],
            correctAnswer: 1,
            explanation: "'Silently' is an adverb describing HOW the fox crept. It modifies the verb 'crept'.",
            category: "Adverbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "We absolutely must finish this important project today.",
            prompt: "Which word is an ADJECTIVE?",
            options: ["absolutely", "must", "important", "today"],
            correctAnswer: 2,
            explanation: "'Important' is an adjective modifying the noun 'project'. It describes what kind of project needs finishing.",
            category: "Adjectives",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The children laughed joyfully at the hilarious clown.",
            prompt: "Which word is the main VERB?",
            options: ["children", "laughed", "joyfully", "hilarious"],
            correctAnswer: 1,
            explanation: "'Laughed' is the main verb showing the action performed by the children.",
            category: "Verbs",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "Courage is necessary when facing difficult challenges.",
            prompt: "Which word is an ABSTRACT NOUN?",
            options: ["necessary", "facing", "difficult", "Courage"],
            correctAnswer: 3,
            explanation: "'Courage' is an abstract noun because it names a quality or idea that cannot be physically touched or seen.",
            category: "Nouns",
            icon: "tag.fill"
        ),
        GrammarChallenge(
            sentence: "The extremely tall building towered over the tiny village.",
            prompt: "Which word is an ADVERB modifying an adjective?",
            options: ["extremely", "tall", "towered", "tiny"],
            correctAnswer: 0,
            explanation: "'Extremely' is an adverb that modifies the adjective 'tall'. Adverbs can modify verbs, adjectives, or other adverbs.",
            category: "Adverbs",
            icon: "tag.fill"
        ),
    ]

    // MARK: - Punctuation Challenges

    static let punctuationChallenges: [GrammarChallenge] = [
        GrammarChallenge(
            sentence: "Lets eat Grandma",
            prompt: "Add the correct punctuation:",
            options: ["Let's eat, Grandma!", "Lets eat, Grandma!", "Let's eat Grandma!", "Lets eat Grandma."],
            correctAnswer: 0,
            explanation: "Two fixes needed: (1) 'Let's' needs an apostrophe (contraction of 'let us'). (2) A comma before 'Grandma' is crucial -- without it, the sentence means something very different!",
            category: "Apostrophes & Commas",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "I bought apples oranges bananas and grapes",
            prompt: "Add the correct punctuation:",
            options: ["I bought apples, oranges, bananas, and grapes.", "I bought apples oranges bananas, and grapes.", "I bought, apples, oranges, bananas, and grapes.", "I bought apples oranges, bananas and grapes."],
            correctAnswer: 0,
            explanation: "Items in a list (series) need commas between them. The comma before 'and' is called the Oxford comma and is recommended in Canadian English.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "However the experiment was not successful",
            prompt: "Add the correct punctuation:",
            options: ["However, the experiment was not successful.", "However the experiment, was not successful.", "However; the experiment was not successful.", "However the experiment was not successful."],
            correctAnswer: 0,
            explanation: "When 'However' starts a sentence as a conjunctive adverb, it must be followed by a comma.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "The childrens books were on the shelf",
            prompt: "Add the correct punctuation:",
            options: ["The children's books were on the shelf.", "The childrens' books were on the shelf.", "The childrens books' were on the shelf.", "The childrens book's were on the shelf."],
            correctAnswer: 0,
            explanation: "'Children' is already plural (it does not end in 's'), so the possessive is formed by adding 's: children's.",
            category: "Apostrophes",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "My sister who lives in Toronto visits every summer",
            prompt: "Add the correct punctuation:",
            options: ["My sister, who lives in Toronto, visits every summer.", "My sister who lives in Toronto, visits every summer.", "My sister, who lives in Toronto visits every summer.", "My sister who, lives in Toronto, visits every summer."],
            correctAnswer: 0,
            explanation: "'Who lives in Toronto' is a non-restrictive clause (extra information). It needs commas on both sides because removing it does not change the core meaning.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "Whose jacket is this is it yours",
            prompt: "Add the correct punctuation:",
            options: ["Whose jacket is this? Is it yours?", "Whose jacket is this, is it yours?", "Whose jacket is this is it your's?", "Whose jacket is this. Is it yours."],
            correctAnswer: 0,
            explanation: "These are two separate questions, each needing a question mark. Note: 'yours' never has an apostrophe.",
            category: "Question Marks",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "The students notebooks were left in the classroom",
            prompt: "Add the correct punctuation:",
            options: ["The students' notebooks were left in the classroom.", "The student's notebooks were left in the classroom.", "The students notebook's were left in the classroom.", "The students notebooks' were left in the classroom."],
            correctAnswer: 0,
            explanation: "Multiple students own notebooks, so the apostrophe goes after the 's': students'. If it were one student, it would be student's.",
            category: "Apostrophes",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "After we finished dinner we played board games",
            prompt: "Add the correct punctuation:",
            options: ["After we finished dinner, we played board games.", "After, we finished dinner we played board games.", "After we finished dinner we played, board games.", "After we finished dinner we, played board games."],
            correctAnswer: 0,
            explanation: "When a dependent clause (After we finished dinner) comes before the main clause, a comma is needed to separate them.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "I cant believe its already December",
            prompt: "Add the correct punctuation:",
            options: ["I can't believe it's already December.", "I cant believe its already December.", "I can't believe its already December.", "I cant believe it's already December."],
            correctAnswer: 0,
            explanation: "'Can't' needs an apostrophe (contraction of 'cannot'). 'It's' needs an apostrophe here because it means 'it is'.",
            category: "Apostrophes",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "Well I think we should leave now dont you agree",
            prompt: "Add the correct punctuation:",
            options: ["Well, I think we should leave now, don't you agree?", "Well I think, we should leave now don't you agree?", "Well, I think we should leave now don't you agree.", "Well I think we should leave now, don't you agree."],
            correctAnswer: 0,
            explanation: "'Well' as an interjection needs a comma. 'Don't' needs an apostrophe. The sentence is a question, so it needs a question mark. A comma before the tag question 'don't you agree' is also needed.",
            category: "Mixed Punctuation",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "She said I love reading Canadian literature",
            prompt: "Add the correct punctuation:",
            options: ["She said, \"I love reading Canadian literature.\"", "She said \"I love reading Canadian literature\".", "She said: I love reading Canadian literature.", "\"She said, I love reading Canadian literature.\""],
            correctAnswer: 0,
            explanation: "Direct quotes need quotation marks around the spoken words. A comma separates the speech tag from the quote. The period goes inside the quotation marks.",
            category: "Quotation Marks",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "In conclusion the experiment proved our hypothesis",
            prompt: "Add the correct punctuation:",
            options: ["In conclusion, the experiment proved our hypothesis.", "In conclusion the experiment, proved our hypothesis.", "In, conclusion the experiment proved our hypothesis.", "In conclusion the experiment proved, our hypothesis."],
            correctAnswer: 0,
            explanation: "'In conclusion' is a transitional phrase at the start of a sentence and must be followed by a comma.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
        GrammarChallenge(
            sentence: "The recipe calls for flour sugar eggs and butter",
            prompt: "Add the correct punctuation:",
            options: ["The recipe calls for flour, sugar, eggs, and butter.", "The recipe calls for flour sugar eggs, and butter.", "The recipe calls for, flour, sugar, eggs and butter.", "The recipe calls for flour, sugar eggs, and butter."],
            correctAnswer: 0,
            explanation: "Items in a series need commas between them. The Oxford comma (before 'and') is standard in Canadian English.",
            category: "Comma Usage",
            icon: "textformat.abc.dottedunderline"
        ),
    ]
}

struct GrammarChallenge: Identifiable {
    let id = UUID()
    let sentence: String
    let prompt: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String
    let category: String
    let icon: String
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GrammarQuestView()
    }
}
