import SwiftUI

struct QuizPreviewView: View {
    let draft: QuizDraft
    @Environment(\.dismiss) private var dismiss

    @State private var currentQuestionIndex = 0
    @State private var selectedOptions: [UUID: Set<UUID>] = [:]      // questionId -> set of optionIds
    @State private var textAnswers: [UUID: String] = [:]             // questionId -> answer text
    @State private var matchingAnswers: [String: String] = [:]       // "questionId_match_index" -> selected answer
    @State private var showResults = false
    @State private var hapticTrigger = false
    @State private var timerSeconds: Int = 0
    @State private var timerActive = true

    private var currentQuestion: QuestionDraft? {
        guard draft.questions.indices.contains(currentQuestionIndex) else { return nil }
        return draft.questions[currentQuestionIndex]
    }

    private var totalQuestions: Int { draft.questions.count }

    private var score: PreviewScore {
        var correct = 0
        var total = 0
        for question in draft.questions {
            total += question.points
            switch question.type {
            case .multipleChoice, .trueFalse:
                let selected = selectedOptions[question.id] ?? []
                let correctOptionIds = Set(question.options.filter(\.isCorrect).map(\.id))
                if selected == correctOptionIds {
                    correct += question.points
                }
            case .shortAnswer:
                let answer = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
                let isCorrect = question.correctAnswers.contains { acceptable in
                    if question.caseInsensitive {
                        return answer.lowercased() == acceptable.lowercased()
                    }
                    return answer == acceptable
                }
                if isCorrect { correct += question.points }
            case .fillInBlank:
                let answer = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
                let isCorrect = question.correctAnswers.contains { acceptable in
                    if question.caseInsensitive {
                        return answer.lowercased() == acceptable.lowercased()
                    }
                    return answer == acceptable
                }
                if isCorrect { correct += question.points }
            case .matching:
                // Matching is manual review in preview; skip auto-grading
                break
            case .essay:
                // Essay is manual review in preview; skip auto-grading
                break
            }
        }
        let percentage = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
        let passed = percentage >= draft.passingScorePercent
        return PreviewScore(earned: correct, total: total, percentage: percentage, passed: passed)
    }

    var body: some View {
        VStack(spacing: 0) {
            previewBanner
            if showResults {
                resultsView
            } else if let question = currentQuestion {
                ScrollView {
                    VStack(spacing: 16) {
                        if draft.timeLimitMinutes != nil {
                            timerDisplay
                        }
                        progressBar
                        questionView(question)
                        navigationButtons
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            } else {
                emptyState
            }
        }
        #if canImport(UIKit)
        .background(Color(UIColor.systemGroupedBackground))
        #endif
        .navigationTitle("Quiz Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .task {
            guard draft.timeLimitMinutes != nil else { return }
            while timerActive && !showResults {
                try? await Task.sleep(for: .seconds(1))
                if timerActive && !showResults {
                    timerSeconds += 1
                }
            }
        }
    }

    // MARK: - Preview Banner

    private var previewBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.caption)
            Text("Preview Mode")
                .font(.caption.bold())
            Text("--- This is how students will see the quiz")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.indigo.gradient)
    }

    // MARK: - Timer

    private var timerDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundStyle(.indigo)

            if let limit = draft.timeLimitMinutes {
                let totalSeconds = limit * 60
                let remaining = max(0, totalSeconds - timerSeconds)
                let minutes = remaining / 60
                let seconds = remaining % 60
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(remaining < 60 ? .red : .primary)
            }

            Spacer()

            Text("Question \(currentQuestionIndex + 1) of \(totalQuestions)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.indigo.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(.indigo.gradient)
                        .frame(
                            width: geometry.size.width * (Double(currentQuestionIndex + 1) / Double(max(totalQuestions, 1))),
                            height: 6
                        )
                        .animation(.snappy, value: currentQuestionIndex)
                }
            }
            .frame(height: 6)

            // Question dots
            HStack(spacing: 4) {
                ForEach(0..<totalQuestions, id: \.self) { index in
                    Circle()
                        .fill(index == currentQuestionIndex ? .indigo : .indigo.opacity(0.2))
                        .frame(width: index == currentQuestionIndex ? 8 : 6, height: index == currentQuestionIndex ? 8 : 6)
                        .animation(.snappy, value: currentQuestionIndex)
                        .onTapGesture {
                            hapticTrigger.toggle()
                            withAnimation(.snappy) {
                                currentQuestionIndex = index
                            }
                        }
                }
            }
        }
    }

    // MARK: - Question View

    private func questionView(_ question: QuestionDraft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question Header
            HStack {
                Image(systemName: question.type.iconName)
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Text(question.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(question.points) pts")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.indigo.opacity(0.12), in: .capsule)
                    .foregroundStyle(.indigo)
            }

            // Question Text
            Text(question.text.isEmpty ? "Question text will appear here" : question.text)
                .font(.body.bold())
                .foregroundStyle(question.text.isEmpty ? .secondary : .primary)

            // Answer Area
            switch question.type {
            case .multipleChoice:
                multipleChoiceAnswerView(question)
            case .trueFalse:
                trueFalseAnswerView(question)
            case .shortAnswer:
                shortAnswerView(question)
            case .fillInBlank:
                fillInBlankAnswerView(question)
            case .matching:
                matchingAnswerView(question)
            case .essay:
                essayAnswerView(question)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func multipleChoiceAnswerView(_ question: QuestionDraft) -> some View {
        VStack(spacing: 8) {
            ForEach(question.options) { option in
                let isSelected = selectedOptions[question.id]?.contains(option.id) ?? false
                Button {
                    hapticTrigger.toggle()
                    toggleOption(questionId: question.id, optionId: option.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .indigo : .secondary)

                        Text(option.text.isEmpty ? "Option" : option.text)
                            .font(.subheadline)
                            .foregroundStyle(option.text.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    #if canImport(UIKit)
                    .background(
                        isSelected
                            ? Color.indigo.opacity(0.08)
                            : Color(UIColor.systemBackground),
                        in: .rect(cornerRadius: 10)
                    )
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.indigo.opacity(0.4) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    private func trueFalseAnswerView(_ question: QuestionDraft) -> some View {
        VStack(spacing: 8) {
            ForEach(question.options) { option in
                let isSelected = selectedOptions[question.id]?.contains(option.id) ?? false
                Button {
                    hapticTrigger.toggle()
                    selectSingleOption(questionId: question.id, optionId: option.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .indigo : .secondary)

                        Text(option.text)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(14)
                    #if canImport(UIKit)
                    .background(
                        isSelected
                            ? Color.indigo.opacity(0.08)
                            : Color(UIColor.systemBackground),
                        in: .rect(cornerRadius: 12)
                    )
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.indigo.opacity(0.4) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    private func shortAnswerView(_ question: QuestionDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Answer")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Type your answer here...", text: Binding(
                get: { textAnswers[question.id] ?? "" },
                set: { textAnswers[question.id] = $0 }
            ), axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)
        }
    }

    private func fillInBlankAnswerView(_ question: QuestionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show question text with blank fields inline
            let parts = question.text.components(separatedBy: "___")
            let blankCount = max(parts.count - 1, 0)

            if blankCount > 0 {
                Text("Fill in the blank\(blankCount == 1 ? "" : "s"):")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(0..<blankCount, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text("Blank \(index + 1):")
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                            .frame(width: 60, alignment: .leading)

                        TextField("Answer", text: Binding(
                            get: {
                                let key = question.id
                                let answers = (textAnswers[key] ?? "").components(separatedBy: "|||")
                                return index < answers.count ? answers[index] : ""
                            },
                            set: { newValue in
                                let key = question.id
                                var answers = (textAnswers[key] ?? "").components(separatedBy: "|||")
                                while answers.count <= index { answers.append("") }
                                answers[index] = newValue
                                textAnswers[key] = answers.joined(separator: "|||")
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    }
                }
            } else {
                Text("Add ___ in the question text to create blanks")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Matching Answer View

    private func matchingAnswerView(_ question: QuestionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match each item on the left with the correct answer on the right.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let answers = question.matchingPairs.map(\.answer).sorted()

            ForEach(Array(question.matchingPairs.enumerated()), id: \.element.id) { index, pair in
                HStack(spacing: 10) {
                    Text(pair.prompt)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(answers, id: \.self) { ans in
                            Button(ans) {
                                let key = "\(question.id.uuidString)_match_\(index)"
                                matchingAnswers[key] = ans
                            }
                        }
                    } label: {
                        let key = "\(question.id.uuidString)_match_\(index)"
                        let selected = matchingAnswers[key] ?? ""
                        HStack {
                            Text(selected.isEmpty ? "Select..." : selected)
                                .font(.subheadline)
                                .foregroundStyle(selected.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Matching questions are flagged for manual review.")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Essay Answer View

    private func essayAnswerView(_ question: QuestionDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !question.essayPrompt.isEmpty {
                Text(question.essayPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            Text("Write your response below:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: Binding(
                get: { textAnswers[question.id] ?? "" },
                set: { textAnswers[question.id] = $0 }
            ))
            .frame(minHeight: 120)
            .padding(8)
            #if canImport(UIKit)
            .background(Color(UIColor.systemBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Word count
            HStack {
                let text = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let wordCount = text.isEmpty ? 0 : text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                let meetsMin = question.essayMinWords <= 0 || wordCount >= question.essayMinWords

                Image(systemName: meetsMin ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(meetsMin ? .green : .orange)

                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if question.essayMinWords > 0 {
                    Text("/ \(question.essayMinWords) minimum")
                        .font(.caption)
                        .foregroundStyle(meetsMin ? Color(UIColor.secondaryLabel) : Color.orange)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Essay questions are flagged for manual teacher review.")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            // Previous
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    currentQuestionIndex = max(0, currentQuestionIndex - 1)
                }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            .disabled(currentQuestionIndex == 0)
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)

            if currentQuestionIndex < totalQuestions - 1 {
                // Next
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        currentQuestionIndex = min(totalQuestions - 1, currentQuestionIndex + 1)
                    }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            } else {
                // Submit
                Button {
                    hapticTrigger.toggle()
                    timerActive = false
                    withAnimation(.snappy) {
                        showResults = true
                    }
                } label: {
                    Label("Submit Quiz", systemImage: "paperplane.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Score Card
                VStack(spacing: 16) {
                    Image(systemName: score.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(score.passed ? .green : .red)

                    Text(score.passed ? "Passed" : "Not Passed")
                        .font(.title2.bold())
                        .foregroundStyle(score.passed ? .green : .red)

                    Text("\(score.percentage)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("\(score.earned)")
                                .font(.title3.bold())
                                .foregroundStyle(.indigo)
                            Text("Points Earned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider().frame(height: 40)

                        VStack(spacing: 4) {
                            Text("\(score.total)")
                                .font(.title3.bold())
                                .foregroundStyle(.purple)
                            Text("Total Points")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider().frame(height: 40)

                        VStack(spacing: 4) {
                            Text("\(draft.passingScorePercent)%")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                            Text("Passing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let limit = draft.timeLimitMinutes {
                        let minutes = timerSeconds / 60
                        let seconds = timerSeconds % 60
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text("Time: \(String(format: "%d:%02d", minutes, seconds)) / \(limit):00")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))

                // Question Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Label("Question Breakdown", systemImage: "list.clipboard.fill")
                        .font(.headline)
                        .foregroundStyle(.indigo)

                    ForEach(Array(draft.questions.enumerated()), id: \.element.id) { index, question in
                        questionResultRow(index: index, question: question)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                // Retake Button
                Button {
                    hapticTrigger.toggle()
                    resetQuiz()
                } label: {
                    Label("Retake Quiz", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }

    private func questionResultRow(index: Int, question: QuestionDraft) -> some View {
        let isManualReview = question.type == .matching || question.type == .essay
        let isCorrect = questionIsCorrect(question)
        return HStack(spacing: 10) {
            if isManualReview {
                Image(systemName: "clock.badge.questionmark")
                    .font(.body)
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(isCorrect ? .green : .red)
            }

            Text("Q\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(question.text)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if isManualReview {
                Text("Review")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            } else {
                Text(isCorrect ? "+\(question.points)" : "0")
                    .font(.caption.bold())
                    .foregroundStyle(isCorrect ? .green : .red)
            }

            Text("/ \(question.points)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        #if canImport(UIKit)
        .background(
            isManualReview
                ? Color.orange.opacity(0.05)
                : (isCorrect ? Color.green.opacity(0.05) : Color.red.opacity(0.05)),
            in: .rect(cornerRadius: 8)
        )
        #endif
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.indigo.opacity(0.4))
            Text("No Questions")
                .font(.headline)
            Text("Add questions to preview the quiz")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func toggleOption(questionId: UUID, optionId: UUID) {
        var current = selectedOptions[questionId] ?? []
        // For MC, check if the question allows multiple correct
        let question = draft.questions.first(where: { $0.id == questionId })
        let multipleCorrect = (question?.options.filter(\.isCorrect).count ?? 0) > 1

        if multipleCorrect {
            if current.contains(optionId) {
                current.remove(optionId)
            } else {
                current.insert(optionId)
            }
        } else {
            current = [optionId]
        }
        selectedOptions[questionId] = current
    }

    private func selectSingleOption(questionId: UUID, optionId: UUID) {
        selectedOptions[questionId] = [optionId]
    }

    private func questionIsCorrect(_ question: QuestionDraft) -> Bool {
        switch question.type {
        case .multipleChoice, .trueFalse:
            let selected = selectedOptions[question.id] ?? []
            let correctOptionIds = Set(question.options.filter(\.isCorrect).map(\.id))
            return selected == correctOptionIds
        case .shortAnswer:
            let answer = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
            return question.correctAnswers.contains { acceptable in
                if question.caseInsensitive {
                    return answer.lowercased() == acceptable.lowercased()
                }
                return answer == acceptable
            }
        case .fillInBlank:
            let answer = (textAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
            return question.correctAnswers.contains { acceptable in
                if question.caseInsensitive {
                    return answer.lowercased() == acceptable.lowercased()
                }
                return answer == acceptable
            }
        case .matching:
            // Matching is manual review; always show as "pending" (not correct/incorrect)
            return false
        case .essay:
            // Essay is manual review; always show as "pending"
            return false
        }
    }

    private func resetQuiz() {
        withAnimation(.snappy) {
            currentQuestionIndex = 0
            selectedOptions = [:]
            textAnswers = [:]
            matchingAnswers = [:]
            showResults = false
            timerSeconds = 0
            timerActive = true
        }
    }
}

// MARK: - Preview Score

private struct PreviewScore {
    let earned: Int
    let total: Int
    let percentage: Int
    let passed: Bool
}
