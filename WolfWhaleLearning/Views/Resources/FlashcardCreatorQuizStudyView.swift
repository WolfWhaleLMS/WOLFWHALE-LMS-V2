import SwiftUI

// MARK: - Quiz Study View

struct FlashcardCreatorQuizStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrectAnswer = false
    @State private var score = 0
    @State private var isComplete = false

    @State private var shuffledCards: [Flashcard] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Quiz Mode")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(score)/\(shuffledCards.count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.purple)
            }
            .padding()

            if isComplete {
                quizCompleteView
            } else if currentIndex < shuffledCards.count {
                let card = shuffledCards[currentIndex]

                Spacer()

                VStack(spacing: 20) {
                    Text(card.front)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding()

                    TextField("Type your answer...", text: $userAnswer)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                        .disabled(showResult)

                    if showResult {
                        VStack(spacing: 8) {
                            Image(systemName: isCorrectAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(isCorrectAnswer ? .green : .red)

                            if !isCorrectAnswer {
                                Text("Correct answer: \(card.back)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()

                Button {
                    if showResult {
                        nextQuestion()
                    } else {
                        checkAnswer()
                    }
                } label: {
                    Text(showResult ? "Next" : "Check Answer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                            in: .rect(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            shuffledCards = deck.cards.shuffled()
        }
    }

    private var quizCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text("Quiz Complete!")
                .font(.title.bold())
            Text("Score: \(score) / \(shuffledCards.count)")
                .font(.title2)
                .foregroundStyle(.purple)
            Text(String(format: "%.0f%%", shuffledCards.isEmpty ? 0 : Double(score) / Double(shuffledCards.count) * 100))
                .font(.largeTitle.bold())
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.purple, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private func checkAnswer() {
        let card = shuffledCards[currentIndex]
        isCorrectAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == card.back.lowercased()
        if isCorrectAnswer { score += 1 }

        if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
            if isCorrectAnswer {
                deck.cards[idx].correctCount += 1
                if deck.cards[idx].correctCount >= 3 { deck.cards[idx].mastery = .mastered }
                else { deck.cards[idx].mastery = .learning }
            } else {
                deck.cards[idx].incorrectCount += 1
                deck.cards[idx].mastery = .learning
            }
            deck.cards[idx].lastReviewed = Date()
            onSave()
        }

        showResult = true
    }

    private func nextQuestion() {
        showResult = false
        isCorrectAnswer = false
        userAnswer = ""
        if currentIndex + 1 >= shuffledCards.count {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }
}

// MARK: - Match Study View

struct FlashcardCreatorMatchStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var fronts: [(id: UUID, text: String)] = []
    @State private var backs: [(id: UUID, text: String)] = []
    @State private var selectedFront: UUID?
    @State private var selectedBack: UUID?
    @State private var matchedPairs: Set<UUID> = []
    @State private var wrongPair = false
    @State private var isComplete = false
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Match Mode")
                    .font(.subheadline.bold())
                Spacer()
                Text("Matched: \(matchedPairs.count)/\(fronts.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .padding()

            if isComplete {
                matchCompleteView
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 12) {
                        // Fronts column
                        VStack(spacing: 8) {
                            Text("Terms")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(fronts, id: \.id) { item in
                                Button {
                                    selectedFront = item.id
                                    checkMatch()
                                } label: {
                                    Text(item.text)
                                        .font(.caption.bold())
                                        .lineLimit(3)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(
                                            matchedPairs.contains(item.id)
                                            ? AnyShapeStyle(Color.green.opacity(0.2))
                                            : selectedFront == item.id
                                            ? AnyShapeStyle(Color.blue.opacity(0.3))
                                            : AnyShapeStyle(.ultraThinMaterial)
                                        )
                                        .clipShape(.rect(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedFront == item.id ? .blue : matchedPairs.contains(item.id) ? .green : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(matchedPairs.contains(item.id))
                            }
                        }

                        // Backs column
                        VStack(spacing: 8) {
                            Text("Definitions")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(backs, id: \.id) { item in
                                Button {
                                    selectedBack = item.id
                                    checkMatch()
                                } label: {
                                    Text(item.text)
                                        .font(.caption.bold())
                                        .lineLimit(3)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(
                                            matchedPairs.contains(item.id)
                                            ? AnyShapeStyle(Color.green.opacity(0.2))
                                            : selectedBack == item.id
                                            ? AnyShapeStyle(Color.orange.opacity(0.3))
                                            : AnyShapeStyle(.ultraThinMaterial)
                                        )
                                        .clipShape(.rect(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedBack == item.id ? .orange : matchedPairs.contains(item.id) ? .green : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(matchedPairs.contains(item.id))
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { setupMatch() }
    }

    private var matchCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("All Matched!")
                .font(.title.bold())
            Text("Attempts: \(attempts)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button { onDismiss() } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.orange, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private func setupMatch() {
        let cards = Array(deck.cards.prefix(8).shuffled())
        fronts = cards.map { (id: $0.id, text: $0.front) }.shuffled()
        backs = cards.map { (id: $0.id, text: $0.back) }.shuffled()
    }

    private func checkMatch() {
        guard let fID = selectedFront, let bID = selectedBack else { return }
        attempts += 1

        if fID == bID {
            matchedPairs.insert(fID)
            selectedFront = nil
            selectedBack = nil

            if matchedPairs.count == fronts.count {
                isComplete = true
            }
        } else {
            wrongPair = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                selectedFront = nil
                selectedBack = nil
                wrongPair = false
            }
        }
    }
}
