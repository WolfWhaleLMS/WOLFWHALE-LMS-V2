import SwiftUI

// MARK: - Data Models

enum VerbGroup: String, CaseIterable {
    case er = "-er (Regular)"
    case ir = "-ir (Regular)"
    case re = "-re (Regular)"
    case irregular = "Irregular"

    var color: Color {
        switch self {
        case .er: return .blue
        case .ir: return .green
        case .re: return .orange
        case .irregular: return .purple
        }
    }
}

enum FrenchTense: String, CaseIterable, Identifiable {
    case present = "Présent"
    case passeCompose = "Passé Composé"
    case imparfait = "Imparfait"
    case futurSimple = "Futur Simple"
    case conditionnel = "Conditionnel"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .present: return .blue
        case .passeCompose: return .purple
        case .imparfait: return .orange
        case .futurSimple: return .green
        case .conditionnel: return .teal
        }
    }

    var icon: String {
        switch self {
        case .present: return "clock.fill"
        case .passeCompose: return "clock.arrow.circlepath"
        case .imparfait: return "memories"
        case .futurSimple: return "forward.fill"
        case .conditionnel: return "questionmark.diamond.fill"
        }
    }
}

struct FrenchVerb: Identifiable {
    let id = UUID()
    let infinitive: String
    let englishMeaning: String
    let group: VerbGroup
    let conjugations: [FrenchTense: [String]]  // 6 forms: je, tu, il/elle, nous, vous, ils/elles

    static let pronouns = ["je", "tu", "il/elle", "nous", "vous", "ils/elles"]
}

enum VerbViewMode {
    case reference
    case practice
    case quiz
}

// MARK: - Main View

struct FrenchVerbView: View {
    @State private var verbs: [FrenchVerb] = FrenchVerbData.allVerbs
    @State private var selectedVerb: FrenchVerb?
    @State private var selectedTense: FrenchTense = .present
    @State private var viewMode: VerbViewMode = .reference
    @State private var filterGroup: VerbGroup?
    @State private var showRulesSheet = false

    var body: some View {
        VStack(spacing: 0) {
            modePicker

            switch viewMode {
            case .reference:
                referenceMode
            case .practice:
                if let verb = selectedVerb {
                    PracticeModeView(verb: verb, tense: selectedTense)
                } else {
                    verbSelectionPrompt
                }
            case .quiz:
                VerbQuizModeView(verbs: verbs)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("French Verb Conjugator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRulesSheet = true
                } label: {
                    Image(systemName: "book.fill")
                }
            }
        }
        .sheet(isPresented: $showRulesSheet) {
            NavigationStack {
                ConjugationRulesView()
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Mode", selection: $viewMode) {
            Label("Reference", systemImage: "book.fill").tag(VerbViewMode.reference)
            Label("Practice", systemImage: "pencil.and.outline").tag(VerbViewMode.practice)
            Label("Quiz", systemImage: "questionmark.circle.fill").tag(VerbViewMode.quiz)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Reference Mode

    private var referenceMode: some View {
        ScrollView {
            VStack(spacing: 16) {
                tensePicker
                groupFilter

                ForEach(filteredVerbs) { verb in
                    verbConjugationCard(verb: verb)
                }
            }
            .padding()
        }
    }

    private var filteredVerbs: [FrenchVerb] {
        if let group = filterGroup {
            return verbs.filter { $0.group == group }
        }
        return verbs
    }

    private var tensePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FrenchTense.allCases) { tense in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTense = tense
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tense.icon)
                                .font(.caption)
                            Text(tense.rawValue)
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedTense == tense
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [tense.color, tense.color.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedTense == tense ? .white : .primary)
                    }
                    .background {
                        if selectedTense != tense {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                }
            }
        }
    }

    private var groupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", group: nil)
                ForEach(VerbGroup.allCases, id: \.self) { group in
                    filterChip(label: group.rawValue, group: group)
                }
            }
        }
    }

    private func filterChip(label: String, group: VerbGroup?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                filterGroup = group
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    filterGroup == group
                        ? AnyShapeStyle((group?.color ?? Color.indigo).opacity(0.8))
                        : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
                .foregroundStyle(filterGroup == group ? .white : .primary)
        }
        .background {
            if filterGroup != group {
                Capsule().fill(.ultraThinMaterial)
            }
        }
    }

    private func verbConjugationCard(verb: FrenchVerb) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(verb.infinitive)
                            .font(.title3.bold())
                        Text("(\(verb.englishMeaning))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(verb.group.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(verb.group.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(verb.group.color.opacity(0.15), in: Capsule())
                }
                Spacer()
                Button {
                    selectedVerb = verb
                    viewMode = .practice
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(selectedTense.color)
                }
            }

            if let forms = verb.conjugations[selectedTense] {
                conjugationTable(forms: forms, tense: selectedTense, group: verb.group)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func conjugationTable(forms: [String], tense: FrenchTense, group: VerbGroup) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(FrenchVerb.pronouns.enumerated()), id: \.offset) { index, pronoun in
                HStack {
                    Text(pronoun)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)

                    if index < forms.count {
                        Text(forms[index])
                            .font(.subheadline.bold())
                            .foregroundStyle(tense.color)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    index % 2 == 0 ? tense.color.opacity(0.05) : Color.clear,
                    in: .rect(cornerRadius: 6)
                )
            }
        }
    }

    private var verbSelectionPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Select a verb from Reference mode")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the pencil icon on any verb card to practice its conjugations")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Go to Reference") {
                viewMode = .reference
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Practice Mode

struct PracticeModeView: View {
    let verb: FrenchVerb
    let tense: FrenchTense
    @State private var answers: [String] = Array(repeating: "", count: 6)
    @State private var results: [Bool?] = Array(repeating: nil, count: 6)
    @State private var showAnswers = false
    @State private var score = 0
    @FocusState private var focusedField: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(verb.infinitive)
                        .font(.largeTitle.bold())
                    Text(verb.englishMeaning)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(tense.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(tense.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(tense.color.opacity(0.15), in: Capsule())
                }
                .padding(.top)

                VStack(spacing: 12) {
                    ForEach(Array(FrenchVerb.pronouns.enumerated()), id: \.offset) { index, pronoun in
                        conjugationInputRow(pronoun: pronoun, index: index)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                HStack(spacing: 16) {
                    Button {
                        checkAnswers()
                    } label: {
                        Label("Check", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }

                    Button {
                        showAnswers.toggle()
                    } label: {
                        Label(
                            showAnswers ? "Hide" : "Show Answers",
                            systemImage: showAnswers ? "eye.slash.fill" : "eye.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [tense.color, tense.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                    }
                }

                if results.contains(where: { $0 != nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Score: \(score)/6")
                            .font(.headline.bold())
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    resetPractice()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
        }
    }

    private func conjugationInputRow(pronoun: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(pronoun)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            TextField("conjugation...", text: $answers[index])
                .font(.body)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: index)
                .onSubmit {
                    if index < 5 {
                        focusedField = index + 1
                    } else {
                        focusedField = nil
                    }
                }
                .overlay(alignment: .trailing) {
                    if let result = results[index] {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red)
                            .padding(.trailing, 8)
                    }
                }

            if showAnswers, let forms = verb.conjugations[tense], index < forms.count {
                Text(forms[index])
                    .font(.caption.bold())
                    .foregroundStyle(tense.color)
                    .frame(width: 80, alignment: .leading)
            }
        }
    }

    private func checkAnswers() {
        guard let forms = verb.conjugations[tense] else { return }
        score = 0
        for i in 0..<min(6, forms.count) {
            let userAnswer = answers[i]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let correct = forms[i].lowercased()
            results[i] = userAnswer == correct
            if userAnswer == correct { score += 1 }
        }
    }

    private func resetPractice() {
        answers = Array(repeating: "", count: 6)
        results = Array(repeating: nil, count: 6)
        score = 0
        showAnswers = false
    }
}

// MARK: - Quiz Mode

struct VerbQuizModeView: View {
    let verbs: [FrenchVerb]
    @State private var currentQuestion = 0
    @State private var totalQuestions = 10
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var userAnswer = ""
    @State private var isCorrect: Bool?
    @State private var quizItems: [(verb: FrenchVerb, tense: FrenchTense, pronounIndex: Int)] = []
    @State private var showResults = false
    @State private var quizStarted = false
    @FocusState private var answerFocused: Bool

    var body: some View {
        if showResults {
            quizResults
        } else if !quizStarted {
            quizStartView
        } else {
            quizPlayView
        }
    }

    private var quizStartView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Conjugation Quiz")
                .font(.title.bold())

            Text("Type the correct conjugation for random verb + tense + pronoun combinations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                startQuiz()
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
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
                    Text("\(streak)")
                        .font(.subheadline.bold().monospacedDigit())
                }
                Spacer()
                Text("Q\(currentQuestion + 1)/\(totalQuestions)")
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(score)")
                        .font(.subheadline.bold().monospacedDigit())
                }
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * Double(currentQuestion + 1) / Double(totalQuestions), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            if currentQuestion < quizItems.count {
                let item = quizItems[currentQuestion]
                Spacer()

                VStack(spacing: 16) {
                    Text(item.tense.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(item.tense.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(item.tense.color.opacity(0.15), in: Capsule())

                    Text(item.verb.infinitive)
                        .font(.system(size: 32, weight: .bold))

                    Text("(\(item.verb.englishMeaning))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(FrenchVerb.pronouns[item.pronounIndex])
                            .font(.title2.bold())
                            .foregroundStyle(item.tense.color)
                        Text("___________")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    TextField("Type conjugation...", text: $userAnswer)
                        .font(.title3)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .focused($answerFocused)
                        .onSubmit { submitAnswer() }
                        .padding(.horizontal, 32)

                    if let correct = isCorrect {
                        HStack(spacing: 8) {
                            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(correct ? .green : .red)
                            if !correct, let forms = item.verb.conjugations[item.tense] {
                                Text("Correct: \(forms[item.pronounIndex])")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            } else {
                                Text("Correct!")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())

                        Button {
                            nextQuestion()
                        } label: {
                            Text(currentQuestion < totalQuestions - 1 ? "Next" : "See Results")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                        }
                    } else {
                        Button {
                            submitAnswer()
                        } label: {
                            Label("Submit", systemImage: "paperplane.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                        }
                        .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Spacer(minLength: 16)
            }
        }
    }

    private var quizResults: some View {
        VStack(spacing: 24) {
            Spacer()

            let pct = totalQuestions > 0 ? Double(score) / Double(totalQuestions) : 0

            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 36, weight: .bold))
                    Text("\(score)/\(totalQuestions)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            Text(pct >= 0.9 ? "Magnifique!" : pct >= 0.7 ? "Très bien!" : pct >= 0.5 ? "Pas mal!" : "Continue!")
                .font(.title.bold())

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(bestStreak)").font(.title3.bold())
                    Text("Best Streak").font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("\(score)").font(.title3.bold())
                    Text("Correct").font(.caption).foregroundStyle(.secondary)
                }
            }

            Button {
                quizStarted = false
                showResults = false
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }

            Spacer()
        }
        .padding()
    }

    private func startQuiz() {
        quizItems = []
        guard !verbs.isEmpty, !FrenchTense.allCases.isEmpty else { return }
        for _ in 0..<totalQuestions {
            guard let verb = verbs.randomElement(),
                  let tense = FrenchTense.allCases.randomElement() else { continue }
            let pronoun = Int.random(in: 0...5)
            quizItems.append((verb: verb, tense: tense, pronounIndex: pronoun))
        }
        currentQuestion = 0
        score = 0
        streak = 0
        bestStreak = 0
        userAnswer = ""
        isCorrect = nil
        showResults = false
        quizStarted = true
        answerFocused = true
    }

    private func submitAnswer() {
        guard currentQuestion < quizItems.count else { return }
        let item = quizItems[currentQuestion]
        guard let forms = item.verb.conjugations[item.tense] else { return }
        let correct = forms[item.pronounIndex].lowercased()
        let answer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if answer == correct {
            isCorrect = true
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            isCorrect = false
            streak = 0
        }
    }

    private func nextQuestion() {
        if currentQuestion < totalQuestions - 1 {
            currentQuestion += 1
            userAnswer = ""
            isCorrect = nil
            answerFocused = true
        } else {
            showResults = true
        }
    }
}

// MARK: - Conjugation Rules View

struct ConjugationRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ruleSection(
                    title: "Regular -er Verbs (Présent)",
                    color: .blue,
                    example: "parler (to speak)",
                    endings: ["je: -e", "tu: -es", "il/elle: -e", "nous: -ons", "vous: -ez", "ils/elles: -ent"],
                    note: "Drop -er, add endings. Most common verb group in French."
                )

                ruleSection(
                    title: "Regular -ir Verbs (Présent)",
                    color: .green,
                    example: "finir (to finish)",
                    endings: ["je: -is", "tu: -is", "il/elle: -it", "nous: -issons", "vous: -issez", "ils/elles: -issent"],
                    note: "Drop -ir, add endings. Note the -iss- in plural forms."
                )

                ruleSection(
                    title: "Regular -re Verbs (Présent)",
                    color: .orange,
                    example: "attendre (to wait)",
                    endings: ["je: -s", "tu: -s", "il/elle: (nothing)", "nous: -ons", "vous: -ez", "ils/elles: -ent"],
                    note: "Drop -re, add endings. Third person singular has no ending."
                )

                ruleSection(
                    title: "Imparfait (All Verbs)",
                    color: .orange,
                    example: "Based on nous form of présent (minus -ons)",
                    endings: ["je: -ais", "tu: -ais", "il/elle: -ait", "nous: -ions", "vous: -iez", "ils/elles: -aient"],
                    note: "Exception: être uses ét- as stem."
                )

                ruleSection(
                    title: "Futur Simple (All Verbs)",
                    color: .green,
                    example: "Add to infinitive (or irregular stem)",
                    endings: ["je: -ai", "tu: -as", "il/elle: -a", "nous: -ons", "vous: -ez", "ils/elles: -ont"],
                    note: "For -re verbs, drop the final -e before adding endings."
                )

                ruleSection(
                    title: "Conditionnel (All Verbs)",
                    color: .teal,
                    example: "Same stem as futur + imparfait endings",
                    endings: ["je: -ais", "tu: -ais", "il/elle: -ait", "nous: -ions", "vous: -iez", "ils/elles: -aient"],
                    note: "Uses the future stem with imperfect endings."
                )

                ruleSection(
                    title: "Passé Composé",
                    color: .purple,
                    example: "avoir/être (present) + past participle",
                    endings: ["-er -> -é (parlé)", "-ir -> -i (fini)", "-re -> -u (attendu)"],
                    note: "Most verbs use avoir. Movement/reflexive verbs use être (agree in gender/number)."
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Conjugation Rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func ruleSection(title: String, color: Color, example: String, endings: [String], note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(color)

            Text(example)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(endings, id: \.self) { ending in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        Text(ending)
                            .font(.subheadline.monospaced())
                    }
                }
            }

            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Verb Data

struct FrenchVerbData {
    static var allVerbs: [FrenchVerb] {
        [
            FrenchVerb(
                infinitive: "être", englishMeaning: "to be", group: .irregular,
                conjugations: [
                    .present: ["suis", "es", "est", "sommes", "êtes", "sont"],
                    .passeCompose: ["ai été", "as été", "a été", "avons été", "avez été", "ont été"],
                    .imparfait: ["étais", "étais", "était", "étions", "étiez", "étaient"],
                    .futurSimple: ["serai", "seras", "sera", "serons", "serez", "seront"],
                    .conditionnel: ["serais", "serais", "serait", "serions", "seriez", "seraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "avoir", englishMeaning: "to have", group: .irregular,
                conjugations: [
                    .present: ["ai", "as", "a", "avons", "avez", "ont"],
                    .passeCompose: ["ai eu", "as eu", "a eu", "avons eu", "avez eu", "ont eu"],
                    .imparfait: ["avais", "avais", "avait", "avions", "aviez", "avaient"],
                    .futurSimple: ["aurai", "auras", "aura", "aurons", "aurez", "auront"],
                    .conditionnel: ["aurais", "aurais", "aurait", "aurions", "auriez", "auraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "aller", englishMeaning: "to go", group: .irregular,
                conjugations: [
                    .present: ["vais", "vas", "va", "allons", "allez", "vont"],
                    .passeCompose: ["suis allé(e)", "es allé(e)", "est allé(e)", "sommes allé(e)s", "êtes allé(e)(s)", "sont allé(e)s"],
                    .imparfait: ["allais", "allais", "allait", "allions", "alliez", "allaient"],
                    .futurSimple: ["irai", "iras", "ira", "irons", "irez", "iront"],
                    .conditionnel: ["irais", "irais", "irait", "irions", "iriez", "iraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "faire", englishMeaning: "to do/make", group: .irregular,
                conjugations: [
                    .present: ["fais", "fais", "fait", "faisons", "faites", "font"],
                    .passeCompose: ["ai fait", "as fait", "a fait", "avons fait", "avez fait", "ont fait"],
                    .imparfait: ["faisais", "faisais", "faisait", "faisions", "faisiez", "faisaient"],
                    .futurSimple: ["ferai", "feras", "fera", "ferons", "ferez", "feront"],
                    .conditionnel: ["ferais", "ferais", "ferait", "ferions", "feriez", "feraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "pouvoir", englishMeaning: "to be able to", group: .irregular,
                conjugations: [
                    .present: ["peux", "peux", "peut", "pouvons", "pouvez", "peuvent"],
                    .passeCompose: ["ai pu", "as pu", "a pu", "avons pu", "avez pu", "ont pu"],
                    .imparfait: ["pouvais", "pouvais", "pouvait", "pouvions", "pouviez", "pouvaient"],
                    .futurSimple: ["pourrai", "pourras", "pourra", "pourrons", "pourrez", "pourront"],
                    .conditionnel: ["pourrais", "pourrais", "pourrait", "pourrions", "pourriez", "pourraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "vouloir", englishMeaning: "to want", group: .irregular,
                conjugations: [
                    .present: ["veux", "veux", "veut", "voulons", "voulez", "veulent"],
                    .passeCompose: ["ai voulu", "as voulu", "a voulu", "avons voulu", "avez voulu", "ont voulu"],
                    .imparfait: ["voulais", "voulais", "voulait", "voulions", "vouliez", "voulaient"],
                    .futurSimple: ["voudrai", "voudras", "voudra", "voudrons", "voudrez", "voudront"],
                    .conditionnel: ["voudrais", "voudrais", "voudrait", "voudrions", "voudriez", "voudraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "devoir", englishMeaning: "to have to/must", group: .irregular,
                conjugations: [
                    .present: ["dois", "dois", "doit", "devons", "devez", "doivent"],
                    .passeCompose: ["ai dû", "as dû", "a dû", "avons dû", "avez dû", "ont dû"],
                    .imparfait: ["devais", "devais", "devait", "devions", "deviez", "devaient"],
                    .futurSimple: ["devrai", "devras", "devra", "devrons", "devrez", "devront"],
                    .conditionnel: ["devrais", "devrais", "devrait", "devrions", "devriez", "devraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "savoir", englishMeaning: "to know", group: .irregular,
                conjugations: [
                    .present: ["sais", "sais", "sait", "savons", "savez", "savent"],
                    .passeCompose: ["ai su", "as su", "a su", "avons su", "avez su", "ont su"],
                    .imparfait: ["savais", "savais", "savait", "savions", "saviez", "savaient"],
                    .futurSimple: ["saurai", "sauras", "saura", "saurons", "saurez", "sauront"],
                    .conditionnel: ["saurais", "saurais", "saurait", "saurions", "sauriez", "sauraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "venir", englishMeaning: "to come", group: .irregular,
                conjugations: [
                    .present: ["viens", "viens", "vient", "venons", "venez", "viennent"],
                    .passeCompose: ["suis venu(e)", "es venu(e)", "est venu(e)", "sommes venu(e)s", "êtes venu(e)(s)", "sont venu(e)s"],
                    .imparfait: ["venais", "venais", "venait", "venions", "veniez", "venaient"],
                    .futurSimple: ["viendrai", "viendras", "viendra", "viendrons", "viendrez", "viendront"],
                    .conditionnel: ["viendrais", "viendrais", "viendrait", "viendrions", "viendriez", "viendraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "prendre", englishMeaning: "to take", group: .irregular,
                conjugations: [
                    .present: ["prends", "prends", "prend", "prenons", "prenez", "prennent"],
                    .passeCompose: ["ai pris", "as pris", "a pris", "avons pris", "avez pris", "ont pris"],
                    .imparfait: ["prenais", "prenais", "prenait", "prenions", "preniez", "prenaient"],
                    .futurSimple: ["prendrai", "prendras", "prendra", "prendrons", "prendrez", "prendront"],
                    .conditionnel: ["prendrais", "prendrais", "prendrait", "prendrions", "prendriez", "prendraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "mettre", englishMeaning: "to put/place", group: .irregular,
                conjugations: [
                    .present: ["mets", "mets", "met", "mettons", "mettez", "mettent"],
                    .passeCompose: ["ai mis", "as mis", "a mis", "avons mis", "avez mis", "ont mis"],
                    .imparfait: ["mettais", "mettais", "mettait", "mettions", "mettiez", "mettaient"],
                    .futurSimple: ["mettrai", "mettras", "mettra", "mettrons", "mettrez", "mettront"],
                    .conditionnel: ["mettrais", "mettrais", "mettrait", "mettrions", "mettriez", "mettraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "dire", englishMeaning: "to say/tell", group: .irregular,
                conjugations: [
                    .present: ["dis", "dis", "dit", "disons", "dites", "disent"],
                    .passeCompose: ["ai dit", "as dit", "a dit", "avons dit", "avez dit", "ont dit"],
                    .imparfait: ["disais", "disais", "disait", "disions", "disiez", "disaient"],
                    .futurSimple: ["dirai", "diras", "dira", "dirons", "direz", "diront"],
                    .conditionnel: ["dirais", "dirais", "dirait", "dirions", "diriez", "diraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "voir", englishMeaning: "to see", group: .irregular,
                conjugations: [
                    .present: ["vois", "vois", "voit", "voyons", "voyez", "voient"],
                    .passeCompose: ["ai vu", "as vu", "a vu", "avons vu", "avez vu", "ont vu"],
                    .imparfait: ["voyais", "voyais", "voyait", "voyions", "voyiez", "voyaient"],
                    .futurSimple: ["verrai", "verras", "verra", "verrons", "verrez", "verront"],
                    .conditionnel: ["verrais", "verrais", "verrait", "verrions", "verriez", "verraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "donner", englishMeaning: "to give", group: .er,
                conjugations: [
                    .present: ["donne", "donnes", "donne", "donnons", "donnez", "donnent"],
                    .passeCompose: ["ai donné", "as donné", "a donné", "avons donné", "avez donné", "ont donné"],
                    .imparfait: ["donnais", "donnais", "donnait", "donnions", "donniez", "donnaient"],
                    .futurSimple: ["donnerai", "donneras", "donnera", "donnerons", "donnerez", "donneront"],
                    .conditionnel: ["donnerais", "donnerais", "donnerait", "donnerions", "donneriez", "donneraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "parler", englishMeaning: "to speak", group: .er,
                conjugations: [
                    .present: ["parle", "parles", "parle", "parlons", "parlez", "parlent"],
                    .passeCompose: ["ai parlé", "as parlé", "a parlé", "avons parlé", "avez parlé", "ont parlé"],
                    .imparfait: ["parlais", "parlais", "parlait", "parlions", "parliez", "parlaient"],
                    .futurSimple: ["parlerai", "parleras", "parlera", "parlerons", "parlerez", "parleront"],
                    .conditionnel: ["parlerais", "parlerais", "parlerait", "parlerions", "parleriez", "parleraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "manger", englishMeaning: "to eat", group: .er,
                conjugations: [
                    .present: ["mange", "manges", "mange", "mangeons", "mangez", "mangent"],
                    .passeCompose: ["ai mangé", "as mangé", "a mangé", "avons mangé", "avez mangé", "ont mangé"],
                    .imparfait: ["mangeais", "mangeais", "mangeait", "mangions", "mangiez", "mangeaient"],
                    .futurSimple: ["mangerai", "mangeras", "mangera", "mangerons", "mangerez", "mangeront"],
                    .conditionnel: ["mangerais", "mangerais", "mangerait", "mangerions", "mangeriez", "mangeraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "finir", englishMeaning: "to finish", group: .ir,
                conjugations: [
                    .present: ["finis", "finis", "finit", "finissons", "finissez", "finissent"],
                    .passeCompose: ["ai fini", "as fini", "a fini", "avons fini", "avez fini", "ont fini"],
                    .imparfait: ["finissais", "finissais", "finissait", "finissions", "finissiez", "finissaient"],
                    .futurSimple: ["finirai", "finiras", "finira", "finirons", "finirez", "finiront"],
                    .conditionnel: ["finirais", "finirais", "finirait", "finirions", "finiriez", "finiraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "attendre", englishMeaning: "to wait", group: .re,
                conjugations: [
                    .present: ["attends", "attends", "attend", "attendons", "attendez", "attendent"],
                    .passeCompose: ["ai attendu", "as attendu", "a attendu", "avons attendu", "avez attendu", "ont attendu"],
                    .imparfait: ["attendais", "attendais", "attendait", "attendions", "attendiez", "attendaient"],
                    .futurSimple: ["attendrai", "attendras", "attendra", "attendrons", "attendrez", "attendront"],
                    .conditionnel: ["attendrais", "attendrais", "attendrait", "attendrions", "attendriez", "attendraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "choisir", englishMeaning: "to choose", group: .ir,
                conjugations: [
                    .present: ["choisis", "choisis", "choisit", "choisissons", "choisissez", "choisissent"],
                    .passeCompose: ["ai choisi", "as choisi", "a choisi", "avons choisi", "avez choisi", "ont choisi"],
                    .imparfait: ["choisissais", "choisissais", "choisissait", "choisissions", "choisissiez", "choisissaient"],
                    .futurSimple: ["choisirai", "choisiras", "choisira", "choisirons", "choisirez", "choisiront"],
                    .conditionnel: ["choisirais", "choisirais", "choisirait", "choisirions", "choisiriez", "choisiraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "vendre", englishMeaning: "to sell", group: .re,
                conjugations: [
                    .present: ["vends", "vends", "vend", "vendons", "vendez", "vendent"],
                    .passeCompose: ["ai vendu", "as vendu", "a vendu", "avons vendu", "avez vendu", "ont vendu"],
                    .imparfait: ["vendais", "vendais", "vendait", "vendions", "vendiez", "vendaient"],
                    .futurSimple: ["vendrai", "vendras", "vendra", "vendrons", "vendrez", "vendront"],
                    .conditionnel: ["vendrais", "vendrais", "vendrait", "vendrions", "vendriez", "vendraient"],
                ]
            ),
            FrenchVerb(
                infinitive: "aimer", englishMeaning: "to love/like", group: .er,
                conjugations: [
                    .present: ["aime", "aimes", "aime", "aimons", "aimez", "aiment"],
                    .passeCompose: ["ai aimé", "as aimé", "a aimé", "avons aimé", "avez aimé", "ont aimé"],
                    .imparfait: ["aimais", "aimais", "aimait", "aimions", "aimiez", "aimaient"],
                    .futurSimple: ["aimerai", "aimeras", "aimera", "aimerons", "aimerez", "aimeront"],
                    .conditionnel: ["aimerais", "aimerais", "aimerait", "aimerions", "aimeriez", "aimeraient"],
                ]
            ),
        ]
    }
}

#Preview {
    NavigationStack {
        FrenchVerbView()
    }
}
