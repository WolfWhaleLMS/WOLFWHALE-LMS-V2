import SwiftUI

// MARK: - Category Detail View

struct CategoryDetailView: View {
    @Binding var category: VocabCategory
    @Binding var allCategories: [VocabCategory]
    @State private var mode: VocabMode = .flashcard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                    .tag(VocabMode.flashcard)
                Label("Quiz", systemImage: "questionmark.circle.fill")
                    .tag(VocabMode.quiz)
            }
            .pickerStyle(.segmented)
            .padding()

            switch mode {
            case .flashcard:
                FlashcardModeView(category: $category)
            case .quiz:
                VocabQuizModeView(category: $category)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Flashcard Mode

struct FlashcardModeView: View {
    @Binding var category: VocabCategory
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0
    @State private var showPronunciation = true

    private var sortedWords: [FrenchWord] {
        category.words.sorted { a, b in
            if a.mastered != b.mastered { return !a.mastered }
            return a.wrongCount > b.wrongCount
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            progressIndicator

            Spacer()

            if !sortedWords.isEmpty {
                flashcard
                    .offset(x: dragOffset)
                    .gesture(swipeGesture)
            }

            Spacer()

            controlButtons

            navigationButtons
        }
        .padding()
    }

    private var progressIndicator: some View {
        HStack {
            Text("Card \(currentIndex + 1) of \(sortedWords.count)")
                .font(.subheadline.bold())
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("\(category.words.filter { $0.mastered }.count)")
                    .font(.subheadline.bold().monospacedDigit())
            }
        }
        .padding(.horizontal)
    }

    private var flashcard: some View {
        let word = sortedWords[currentIndex]
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [category.color1, category.color2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            VStack(spacing: 16) {
                Text(isFlipped ? "English" : "Francais")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(isFlipped ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    )

                Text(isFlipped ? word.english : word.french)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .scaleEffect(x: isFlipped ? -1 : 1)

                if showPronunciation && !isFlipped {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                        Text(word.phonetic)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                if word.mastered {
                    Label("Mastered", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            .padding(32)
        }
        .frame(height: 260)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
                    if value.translation.width < -80 {
                        goToNext()
                    } else if value.translation.width > 80 {
                        goToPrevious()
                    }
                    dragOffset = 0
                }
            }
    }

    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button {
                toggleMastered()
            } label: {
                let word = sortedWords[currentIndex]
                Label(
                    word.mastered ? "Unmaster" : "Mark Mastered",
                    systemImage: word.mastered ? "xmark.seal" : "checkmark.seal.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(word.mastered ? .red : .green)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Button {
                showPronunciation.toggle()
            } label: {
                Image(systemName: showPronunciation ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 30) {
            Button {
                withAnimation(.spring(response: 0.3)) { goToPrevious() }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(category.color1)
            }
            .disabled(currentIndex == 0)
            .opacity(currentIndex == 0 ? 0.3 : 1)

            Text("\(currentIndex + 1)")
                .font(.title2.bold().monospacedDigit())
                .frame(width: 40)

            Button {
                withAnimation(.spring(response: 0.3)) { goToNext() }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(category.color2)
            }
            .disabled(currentIndex >= sortedWords.count - 1)
            .opacity(currentIndex >= sortedWords.count - 1 ? 0.3 : 1)
        }
        .padding(.bottom, 8)
    }

    private func goToNext() {
        if currentIndex < sortedWords.count - 1 {
            currentIndex += 1
            isFlipped = false
        }
    }

    private func goToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            isFlipped = false
        }
    }

    private func toggleMastered() {
        let word = sortedWords[currentIndex]
        if let idx = category.words.firstIndex(where: { $0.id == word.id }) {
            category.words[idx].mastered.toggle()
        }
    }
}
