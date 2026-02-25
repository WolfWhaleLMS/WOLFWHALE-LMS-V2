import SwiftUI

// MARK: - Classic Study View

struct FlashcardCreatorClassicStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var offset: CGFloat = 0
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var isComplete = false
    @State private var hapticTrigger = false

    private var studyCards: [Flashcard] {
        // Spaced repetition: prioritise cards that are due and struggling
        deck.cards.sorted { a, b in
            if a.mastery != b.mastery {
                if a.mastery == .new { return true }
                if b.mastery == .new { return false }
                if a.mastery == .learning { return true }
                return false
            }
            return a.nextReviewDate < b.nextReviewDate
        }
    }

    private var currentCard: Flashcard? {
        guard currentIndex < studyCards.count else { return nil }
        return studyCards[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(currentIndex + 1) / \(studyCards.count)")
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
                // Balance spacer
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0)
            }
            .padding()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: studyCards.isEmpty ? 0 : geo.size.width * CGFloat(currentIndex) / CGFloat(studyCards.count), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            Spacer()

            if isComplete {
                completeView
            } else if let card = currentCard {
                // Card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                    VStack(spacing: 16) {
                        Text(isFlipped ? "Answer" : "Question")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(isFlipped ? card.back : card.front)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if !isFlipped {
                            Text("Tap to reveal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(30)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .padding(.horizontal, 30)
                .offset(x: offset)
                .rotationEffect(.degrees(Double(offset / 30)))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            if value.translation.width > 100 {
                                markCorrect()
                            } else if value.translation.width < -100 {
                                markIncorrect()
                            } else {
                                withAnimation(.spring()) { offset = 0 }
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) {
                        isFlipped.toggle()
                    }
                }

                Spacer()

                if isFlipped {
                    HStack(spacing: 40) {
                        Button {
                            markIncorrect()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.red)
                                Text("Wrong")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            markCorrect()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.green)
                                Text("Correct")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 40)
                } else {
                    HStack(spacing: 20) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(.red.opacity(0.5))
                        Text("Swipe left = wrong, right = correct")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.green.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    }

    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Session Complete!")
                .font(.title.bold())

            HStack(spacing: 30) {
                VStack {
                    Text("\(correctCount)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Correct")
                        .font(.caption)
                }
                VStack {
                    Text("\(incorrectCount)")
                        .font(.title.bold())
                        .foregroundStyle(.red)
                    Text("Incorrect")
                        .font(.caption)
                }
            }

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
    }

    private func markCorrect() {
        guard let card = currentCard,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        correctCount += 1
        deck.cards[idx].correctCount += 1
        deck.cards[idx].lastReviewed = Date()

        if deck.cards[idx].correctCount >= 3 {
            deck.cards[idx].mastery = .mastered
            deck.cards[idx].nextReviewDate = Date().addingTimeInterval(7 * 86400)
        } else {
            deck.cards[idx].mastery = .learning
            deck.cards[idx].nextReviewDate = Date().addingTimeInterval(86400)
        }

        onSave()
        hapticTrigger.toggle()
        advance()
    }

    private func markIncorrect() {
        guard let card = currentCard,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        incorrectCount += 1
        deck.cards[idx].incorrectCount += 1
        deck.cards[idx].lastReviewed = Date()
        deck.cards[idx].mastery = .learning
        deck.cards[idx].nextReviewDate = Date().addingTimeInterval(600)
        onSave()
        hapticTrigger.toggle()
        advance()
    }

    private func advance() {
        withAnimation(.spring()) {
            offset = 0
            isFlipped = false
        }
        if currentIndex + 1 >= studyCards.count {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }
}
