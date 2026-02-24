import SwiftUI

struct QuizView: View {
    let quiz: Quiz
    let viewModel: AppViewModel
    @State private var currentQuestion = 0
    @State private var selectedAnswers: [Int] = []           // MC / T-F index per question
    @State private var fillInAnswers: [String] = []          // fill-in-blank text per question
    @State private var matchingSelections: [[String]] = []   // per question: array of selected answers for each prompt
    @State private var essayTexts: [String] = []             // essay text per question
    @State private var isSubmitted = false
    @State private var score: Double = 0
    @State private var pendingManualReview = false
    @State private var timeRemaining: Int
    @State private var timerActive = true
    @Environment(\.dismiss) private var dismiss

    init(quiz: Quiz, viewModel: AppViewModel) {
        self.quiz = quiz
        self.viewModel = viewModel
        _timeRemaining = State(initialValue: quiz.timeLimit * 60)
        _selectedAnswers = State(initialValue: Array(repeating: -1, count: quiz.questions.count))
        _fillInAnswers = State(initialValue: Array(repeating: "", count: quiz.questions.count))
        _essayTexts = State(initialValue: Array(repeating: "", count: quiz.questions.count))

        // Build matching selections: for each question, an array sized to matching pairs count
        let matchSel = quiz.questions.map { q -> [String] in
            Array(repeating: "", count: q.matchingPairs.count)
        }
        _matchingSelections = State(initialValue: matchSel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if quiz.questions.isEmpty {
                ContentUnavailableView(
                    "No Questions",
                    systemImage: "questionmark.circle",
                    description: Text("This quiz has no questions yet.")
                )
            } else if isSubmitted {
                resultsView
            } else {
                quizContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isSubmitted {
                    timerBadge
                }
            }
        }
        .task {
            while timerActive && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if timerActive { timeRemaining -= 1 }
                if timeRemaining <= 0 { submitQuiz() }
            }
        }
        .alert("Quiz Submission Failed", isPresented: Binding(
            get: { viewModel.submissionError != nil },
            set: { if !$0 { viewModel.submissionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.submissionError ?? "Your quiz answers were not saved to the server. Please contact your teacher.")
        }
    }

    private var timerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .symbolEffect(.variableColor.iterative, isActive: timeRemaining < 60)
            Text(timeString)
        }
        .font(.caption.bold().monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(timeRemaining < 60 ? .red.opacity(0.2) : .blue.opacity(0.15), in: Capsule())
        .foregroundStyle(timeRemaining < 60 ? .red : .blue)
        .accessibilityLabel("Time remaining: \(timeRemaining / 60) minutes and \(timeRemaining % 60) seconds")
    }

    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Quiz Content

    private var quizContent: some View {
        VStack(spacing: 20) {
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    questionCard
                    answerSection
                }
                .padding()
            }

            navigationButtons
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(currentQuestion + 1) of \(quiz.questions.count)")
                    .font(.subheadline.bold())
                Spacer()
                let answered = countAnswered()
                Text("\(answered) answered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.purple.gradient)
                        .frame(width: geo.size.width * (quiz.questions.isEmpty ? 0 : Double(currentQuestion + 1) / Double(quiz.questions.count)))
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var questionCard: some View {
        let question = quiz.questions[currentQuestion]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: question.questionType.iconName)
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text(question.questionType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !question.questionType.isAutoGradable {
                    Text("Manual Review")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            Text(question.text)
                .font(.title3.bold())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Answer Section (dispatches by type)

    @ViewBuilder
    private var answerSection: some View {
        let question = quiz.questions[currentQuestion]
        switch question.questionType {
        case .multipleChoice:
            multipleChoiceSection(question)
        case .trueFalse:
            trueFalseSection(question)
        case .fillInBlank:
            fillInBlankSection(question)
        case .matching:
            matchingSection(question)
        case .essay:
            essaySection(question)
        }
    }

    // MARK: - Multiple Choice

    private func multipleChoiceSection(_ question: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button {
                    withAnimation(.snappy) {
                        selectedAnswers[currentQuestion] = index
                    }
                } label: {
                    HStack(spacing: 14) {
                        Circle()
                            .strokeBorder(selectedAnswers[currentQuestion] == index ? .purple : .secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if selectedAnswers[currentQuestion] == index {
                                    Circle().fill(.purple).padding(4)
                                }
                            }
                        Text(option)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        selectedAnswers[currentQuestion] == index
                        ? Color.purple.opacity(0.1) : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selectedAnswers[currentQuestion] == index ? .purple : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selectedAnswers[currentQuestion])
                .accessibilityLabel("Option \(index + 1): \(option)")
                .accessibilityAddTraits(selectedAnswers[currentQuestion] == index ? .isSelected : [])
            }
        }
    }

    // MARK: - True / False

    private func trueFalseSection(_ question: QuizQuestion) -> some View {
        HStack(spacing: 16) {
            trueFalseButton(label: "True", systemImage: "checkmark.circle.fill", index: 0, color: .green)
            trueFalseButton(label: "False", systemImage: "xmark.circle.fill", index: 1, color: .red)
        }
    }

    private func trueFalseButton(label: String, systemImage: String, index: Int, color: Color) -> some View {
        let isSelected = selectedAnswers[currentQuestion] == index
        return Button {
            withAnimation(.snappy) {
                selectedAnswers[currentQuestion] = index
            }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(isSelected ? color : .secondary.opacity(0.4))

                Text(label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                isSelected ? color.opacity(0.12) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedAnswers[currentQuestion])
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Fill in the Blank

    private func fillInBlankSection(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show the sentence with a visual blank
            let parts = question.text.components(separatedBy: "___")
            if parts.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fill in the blank:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Render text with blanks indicated
                    HStack(spacing: 0) {
                        ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                            Text(part)
                                .font(.body)
                            if idx < parts.count - 1 {
                                Text(" _______ ")
                                    .font(.body.bold())
                                    .foregroundStyle(.purple)
                                    .underline()
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            TextField("Type your answer here...", text: $fillInAnswers[currentQuestion])
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .padding(.vertical, 4)
                .autocorrectionDisabled()
                .accessibilityLabel("Answer for fill in the blank")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Matching

    private func matchingSection(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match each item on the left with the correct item on the right.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let availableAnswers = question.matchingPairs.map(\.answer).sorted()

            ForEach(Array(question.matchingPairs.enumerated()), id: \.element.id) { index, pair in
                HStack(spacing: 12) {
                    // Left side: prompt
                    Text(pair.prompt)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Right side: picker
                    Menu {
                        Button("-- Select --") {
                            if currentQuestion < matchingSelections.count && index < matchingSelections[currentQuestion].count {
                                matchingSelections[currentQuestion][index] = ""
                            }
                        }
                        ForEach(availableAnswers, id: \.self) { ans in
                            Button(ans) {
                                if currentQuestion < matchingSelections.count && index < matchingSelections[currentQuestion].count {
                                    matchingSelections[currentQuestion][index] = ans
                                }
                            }
                        }
                    } label: {
                        let selected = (currentQuestion < matchingSelections.count && index < matchingSelections[currentQuestion].count)
                            ? matchingSelections[currentQuestion][index]
                            : ""
                        HStack {
                            Text(selected.isEmpty ? "Select..." : selected)
                                .font(.subheadline)
                                .foregroundStyle(selected.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selected.isEmpty ? Color.clear : Color.purple.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Essay

    private func essaySection(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !question.essayPrompt.isEmpty {
                Text(question.essayPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }

            Text("Write your response below:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $essayTexts[currentQuestion])
                .frame(minHeight: 180)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            // Word count
            HStack {
                let wordCount = essayWordCount(currentQuestion)
                let minWords = question.essayMinWords
                let meetsMin = minWords <= 0 || wordCount >= minWords

                Image(systemName: meetsMin ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(meetsMin ? .green : .orange)

                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if minWords > 0 {
                    Text("/ \(minWords) minimum")
                        .font(.caption)
                        .foregroundStyle(meetsMin ? Color(UIColor.secondaryLabel) : Color.orange)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("This question will be reviewed by your teacher.")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentQuestion > 0 {
                Button {
                    withAnimation(.snappy) { currentQuestion -= 1 }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
            }

            if currentQuestion < quiz.questions.count - 1 {
                Button {
                    withAnimation(.snappy) { currentQuestion += 1 }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            } else {
                Button {
                    submitQuiz()
                } label: {
                    Text("Submit Quiz")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!allAutoGradableAnswered())
            }
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 12)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(
                            score >= 70 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(Int(score))%")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(score >= 90 ? "Excellent!" : score >= 70 ? "Good Job!" : "Keep Trying")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 20) {
                    resultStat(label: "Correct", value: "\(autoGradedCorrectCount)/\(autoGradableCount)", color: .green)
                    resultStat(label: "Time", value: timeString, color: .blue)
                }

                if pendingManualReview {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.body)
                            .symbolEffect(.pulse)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pending Manual Review")
                                .font(.subheadline.bold())
                            Text("Essay and matching questions will be graded by your teacher. Your final score may change.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.horizontal)
            }
            .padding()
        }
        .sensoryFeedback(.success, trigger: isSubmitted)
    }

    private func resultStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Helpers

    private func essayWordCount(_ index: Int) -> Int {
        guard index < essayTexts.count else { return 0 }
        let text = essayTexts[index].trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 0 }
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func countAnswered() -> Int {
        var count = 0
        for (i, q) in quiz.questions.enumerated() {
            switch q.questionType {
            case .multipleChoice, .trueFalse:
                if selectedAnswers[i] >= 0 { count += 1 }
            case .fillInBlank:
                if !fillInAnswers[i].trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
            case .matching:
                if i < matchingSelections.count && matchingSelections[i].allSatisfy({ !$0.isEmpty }) && !matchingSelections[i].isEmpty {
                    count += 1
                }
            case .essay:
                if !essayTexts[i].trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
            }
        }
        return count
    }

    private func allAutoGradableAnswered() -> Bool {
        for (i, q) in quiz.questions.enumerated() {
            switch q.questionType {
            case .multipleChoice, .trueFalse:
                if selectedAnswers[i] < 0 { return false }
            case .fillInBlank:
                if fillInAnswers[i].trimmingCharacters(in: .whitespaces).isEmpty { return false }
            case .matching:
                // Matching not strictly required for submit but we check completeness
                if i < matchingSelections.count {
                    if matchingSelections[i].contains(where: { $0.isEmpty }) { return false }
                }
            case .essay:
                // Essay is never blocking (min words is just guidance)
                break
            }
        }
        return true
    }

    private var autoGradableCount: Int {
        quiz.questions.filter { $0.questionType.isAutoGradable }.count
    }

    private var autoGradedCorrectCount: Int {
        var correct = 0
        for (i, q) in quiz.questions.enumerated() {
            switch q.questionType {
            case .multipleChoice, .trueFalse:
                if selectedAnswers[i] == q.correctIndex { correct += 1 }
            case .fillInBlank:
                let answer = fillInAnswers[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if q.acceptedAnswers.contains(where: { $0.lowercased() == answer }) {
                    correct += 1
                }
            case .matching, .essay:
                break
            }
        }
        return correct
    }

    private func submitQuiz() {
        timerActive = false

        // Build combined answers for the view model
        let result = viewModel.submitAdvancedQuiz(
            quiz,
            selectedAnswers: selectedAnswers,
            fillInAnswers: fillInAnswers,
            matchingSelections: matchingSelections,
            essayTexts: essayTexts
        )
        score = result.score
        pendingManualReview = result.hasPendingReview

        withAnimation(.spring) { isSubmitted = true }
    }
}
