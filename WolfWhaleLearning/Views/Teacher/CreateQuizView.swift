import SwiftUI

struct CreateQuizView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var quizTitle = ""
    @State private var timeLimit = 15
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var questions: [DraftQuestion] = [DraftQuestion()]
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        let titleOK = !quizTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let questionsOK = questions.allSatisfy { $0.isValid }
        return titleOK && questionsOK && !questions.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                quizDetailsSection
                questionsSection
                addQuestionButton
                createButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Create Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Quiz Details

    private var quizDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quiz Details", systemImage: "questionmark.circle.fill")
                .font(.headline)

            TextField("Quiz Title", text: $quizTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Time Limit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper("\(timeLimit) min", value: $timeLimit, in: 5...120, step: 5)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Due Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "Due Date",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Questions", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Text("\(questions.count) question\(questions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(questions.indices, id: \.self) { index in
                questionCard(index: index)
            }
        }
    }

    private func questionCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                Spacer()
                if questions.count > 1 {
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) {
                            _ = questions.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                }
            }

            // Question type picker
            Menu {
                ForEach(QuizQuestionType.allCases, id: \.self) { type in
                    Button {
                        hapticTrigger.toggle()
                        switchQuestionType(index: index, to: type)
                    } label: {
                        Label(type.displayName, systemImage: type.iconName)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: questions[index].type.iconName)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(questions[index].type.displayName)
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            }

            TextField("Question text", text: $questions[index].text, axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)

            // Type-specific answer input
            switch questions[index].type {
            case .multipleChoice:
                multipleChoiceInput(index: index)
            case .trueFalse:
                trueFalseInput(index: index)
            case .fillInBlank:
                fillInBlankInput(index: index)
            case .matching:
                matchingInput(index: index)
            case .essay:
                essayInput(index: index)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Multiple Choice Input

    private func multipleChoiceInput(index: Int) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<questions[index].options.count, id: \.self) { optionIndex in
                HStack(spacing: 8) {
                    Button {
                        hapticTrigger.toggle()
                        questions[index].correctIndex = optionIndex
                    } label: {
                        Image(systemName: questions[index].correctIndex == optionIndex
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(questions[index].correctIndex == optionIndex
                                             ? .green : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    TextField("Option \(optionIndex + 1)", text: $questions[index].options[optionIndex])
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                }
            }

            Text("Tap the circle to mark the correct answer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - True/False Input

    private func trueFalseInput(index: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { optIdx in
                let label = optIdx == 0 ? "True" : "False"
                let isSelected = questions[index].correctIndex == optIdx
                Button {
                    hapticTrigger.toggle()
                    questions[index].correctIndex = optIdx
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .green : .secondary)
                        Text(label)
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        isSelected ? Color.green.opacity(0.1) : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.green.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    // MARK: - Fill in Blank Input

    private func fillInBlankInput(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use ___ in the question text to mark blanks.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(questions[index].acceptedAnswers.indices, id: \.self) { ansIdx in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.diamond.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    TextField("Accepted answer \(ansIdx + 1)", text: $questions[index].acceptedAnswers[ansIdx])
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    if questions[index].acceptedAnswers.count > 1 {
                        Button {
                            hapticTrigger.toggle()
                            _ = questions[index].acceptedAnswers.remove(at: ansIdx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                hapticTrigger.toggle()
                questions[index].acceptedAnswers.append("")
            } label: {
                Label("Add Accepted Answer", systemImage: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Matching Input

    private func matchingInput(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create prompt-answer pairs for students to match.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(questions[index].matchingPairs.indices, id: \.self) { pairIdx in
                HStack(spacing: 6) {
                    TextField("Prompt", text: $questions[index].matchingPairs[pairIdx].prompt)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Answer", text: $questions[index].matchingPairs[pairIdx].answer)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    if questions[index].matchingPairs.count > 2 {
                        Button {
                            hapticTrigger.toggle()
                            _ = questions[index].matchingPairs.remove(at: pairIdx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                hapticTrigger.toggle()
                questions[index].matchingPairs.append(SimplePair())
            } label: {
                Label("Add Pair", systemImage: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Matching is flagged for manual review.")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Essay Input

    private func essayInput(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Essay Prompt (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Additional instructions...", text: $questions[index].essayPrompt, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum Word Count")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper("\(questions[index].essayMinWords) words", value: $questions[index].essayMinWords, in: 0...500, step: 25)
                    .font(.subheadline)
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Essays are always flagged for manual teacher review.")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Add Question

    private var addQuestionButton: some View {
        Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                questions.append(DraftQuestion())
            }
        } label: {
            Label("Add Question", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                hapticTrigger.toggle()
                createQuiz()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Create Quiz", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isLoading || !isValid)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(.top, 4)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Quiz Created")
                    .font(.title3.bold())
                Text("\(quizTitle) with \(questions.count) questions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
            dismiss()
        }
    }

    // MARK: - Helpers

    private func switchQuestionType(index: Int, to type: QuizQuestionType) {
        guard index < questions.count else { return }
        questions[index].type = type
        // Reset type-specific fields
        switch type {
        case .multipleChoice:
            questions[index].options = ["", "", "", ""]
            questions[index].correctIndex = 0
        case .trueFalse:
            questions[index].options = ["True", "False"]
            questions[index].correctIndex = 0
        case .fillInBlank:
            questions[index].options = []
            if questions[index].acceptedAnswers.isEmpty {
                questions[index].acceptedAnswers = [""]
            }
        case .matching:
            questions[index].options = []
            if questions[index].matchingPairs.count < 2 {
                questions[index].matchingPairs = [SimplePair(), SimplePair(), SimplePair()]
            }
        case .essay:
            questions[index].options = []
        }
    }

    // MARK: - Actions

    private func createQuiz() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = quizTitle.trimmingCharacters(in: .whitespaces)
        let quizQuestions = questions.map { draft -> QuizQuestion in
            let trimmedText = draft.text.trimmingCharacters(in: .whitespaces)
            switch draft.type {
            case .multipleChoice:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .multipleChoice,
                    options: draft.options.map { $0.trimmingCharacters(in: .whitespaces) },
                    correctIndex: draft.correctIndex
                )
            case .trueFalse:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .trueFalse,
                    options: ["True", "False"],
                    correctIndex: draft.correctIndex
                )
            case .fillInBlank:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .fillInBlank,
                    acceptedAnswers: draft.acceptedAnswers.map { $0.trimmingCharacters(in: .whitespaces) }
                )
            case .matching:
                let pairs = draft.matchingPairs.map {
                    MatchingPair(prompt: $0.prompt, answer: $0.answer)
                }
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .matching,
                    matchingPairs: pairs,
                    needsManualReview: true
                )
            case .essay:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .essay,
                    essayPrompt: draft.essayPrompt,
                    essayMinWords: draft.essayMinWords,
                    needsManualReview: true
                )
            }
        }

        Task {
            do {
                try await viewModel.createQuiz(
                    courseId: course.id,
                    title: trimmedTitle,
                    questions: quizQuestions,
                    timeLimit: timeLimit,
                    dueDate: dueDate,
                    xpReward: 0
                )
                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to create quiz. Please try again."
                isLoading = false
            }
        }
    }
}

// MARK: - Draft Question Model

private struct SimplePair {
    var prompt = ""
    var answer = ""
}

private struct DraftQuestion {
    var text = ""
    var type: QuizQuestionType = .multipleChoice
    var options = ["", "", "", ""]
    var correctIndex = 0
    var acceptedAnswers: [String] = [""]
    var matchingPairs: [SimplePair] = []
    var essayPrompt = ""
    var essayMinWords = 50

    var isValid: Bool {
        let textOK = !text.trimmingCharacters(in: .whitespaces).isEmpty
        switch type {
        case .multipleChoice:
            return textOK && options.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .trueFalse:
            return textOK
        case .fillInBlank:
            return textOK && !acceptedAnswers.isEmpty
                && acceptedAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .matching:
            return textOK && matchingPairs.count >= 2
                && matchingPairs.allSatisfy {
                    !$0.prompt.trimmingCharacters(in: .whitespaces).isEmpty
                    && !$0.answer.trimmingCharacters(in: .whitespaces).isEmpty
                }
        case .essay:
            return textOK
        }
    }
}
