import SwiftUI

// MARK: - Passage Data

struct TypingPassage: Identifiable {
    let id = UUID()
    let text: String
    let subject: TypingSubject
    let title: String
}

enum TypingSubject: String, CaseIterable, Identifiable {
    case science = "Science"
    case history = "History"
    case literature = "Literature"
    case geography = "Geography"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .science: return "atom"
        case .history: return "scroll.fill"
        case .literature: return "book.closed.fill"
        case .geography: return "globe.americas.fill"
        }
    }

    var color: Color {
        switch self {
        case .science: return .green
        case .history: return .orange
        case .literature: return .purple
        case .geography: return .blue
        }
    }
}

let typingPassages: [TypingPassage] = [
    // Science
    TypingPassage(
        text: "Water is made up of two hydrogen atoms and one oxygen atom. This simple molecule is essential for all known forms of life on Earth.",
        subject: .science,
        title: "Water Molecule"
    ),
    TypingPassage(
        text: "The speed of light in a vacuum is approximately 299,792 kilometers per second. Nothing in the universe can travel faster than light.",
        subject: .science,
        title: "Speed of Light"
    ),
    TypingPassage(
        text: "Photosynthesis is the process by which green plants convert sunlight into chemical energy. They absorb carbon dioxide and release oxygen.",
        subject: .science,
        title: "Photosynthesis"
    ),
    TypingPassage(
        text: "The human brain contains approximately 86 billion neurons. Each neuron can form thousands of connections with other neurons, creating an incredibly complex network.",
        subject: .science,
        title: "The Human Brain"
    ),

    // History
    TypingPassage(
        text: "The ancient Egyptians built the Great Pyramid of Giza around 2560 BC. It stood as the tallest structure in the world for over 3,800 years.",
        subject: .history,
        title: "Great Pyramid"
    ),
    TypingPassage(
        text: "The printing press was invented by Johannes Gutenberg around 1440. This invention revolutionized the way information was shared across the world.",
        subject: .history,
        title: "Printing Press"
    ),
    TypingPassage(
        text: "In 1969, Neil Armstrong became the first person to walk on the Moon. He famously said: That is one small step for man, one giant leap for mankind.",
        subject: .history,
        title: "Moon Landing"
    ),
    TypingPassage(
        text: "The Roman Empire lasted for over a thousand years, shaping law, language, architecture, and governance across Europe and the Mediterranean region.",
        subject: .history,
        title: "Roman Empire"
    ),

    // Literature
    TypingPassage(
        text: "To be or not to be, that is the question. Whether it is nobler in the mind to suffer the slings and arrows of outrageous fortune.",
        subject: .literature,
        title: "Hamlet"
    ),
    TypingPassage(
        text: "It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness. So begins the famous tale.",
        subject: .literature,
        title: "A Tale of Two Cities"
    ),
    TypingPassage(
        text: "All animals are equal, but some animals are more equal than others. This powerful statement reveals the corruption of ideals in the story.",
        subject: .literature,
        title: "Animal Farm"
    ),
    TypingPassage(
        text: "In a hole in the ground there lived a hobbit. Not a nasty, dirty, wet hole filled with worms, but a comfortable hobbit hole with a round door.",
        subject: .literature,
        title: "The Hobbit"
    ),

    // Geography
    TypingPassage(
        text: "The Amazon River is the largest river by volume of water in the world. It flows through South America for over 6,400 kilometers.",
        subject: .geography,
        title: "Amazon River"
    ),
    TypingPassage(
        text: "Mount Everest stands at 8,849 meters above sea level, making it the highest mountain on Earth. It sits on the border of Nepal and Tibet.",
        subject: .geography,
        title: "Mount Everest"
    ),
    TypingPassage(
        text: "The Sahara Desert is the largest hot desert in the world, covering most of North Africa. It is roughly the same size as the United States.",
        subject: .geography,
        title: "Sahara Desert"
    ),
    TypingPassage(
        text: "The Pacific Ocean is the largest and deepest ocean on Earth. It covers more area than all the land on the planet combined.",
        subject: .geography,
        title: "Pacific Ocean"
    ),
]

// MARK: - Character Status

enum CharacterStatus {
    case pending
    case correct
    case incorrect
    case current
}

// MARK: - Typing Game View Model

@Observable
@MainActor
class TypingSpeedViewModel {
    var currentPassage: TypingPassage?
    var typedText: String = ""
    var isStarted: Bool = false
    var isFinished: Bool = false
    var startTime: Date?
    var endTime: Date?
    var elapsedTime: TimeInterval = 0
    var isGameStarted: Bool = false
    var selectedSubject: TypingSubject?

    private var timer: Timer?

    var passageText: String {
        currentPassage?.text ?? ""
    }

    var characterStatuses: [(Character, CharacterStatus)] {
        let passageChars = Array(passageText)
        let typedChars = Array(typedText)

        return passageChars.enumerated().map { index, char in
            if index < typedChars.count {
                if typedChars[index] == char {
                    return (char, .correct)
                } else {
                    return (char, .incorrect)
                }
            } else if index == typedChars.count {
                return (char, .current)
            } else {
                return (char, .pending)
            }
        }
    }

    var correctCharacters: Int {
        let passageChars = Array(passageText)
        let typedChars = Array(typedText)
        var correct = 0
        for i in 0..<min(passageChars.count, typedChars.count) {
            if passageChars[i] == typedChars[i] {
                correct += 1
            }
        }
        return correct
    }

    var totalTypedCharacters: Int {
        typedText.count
    }

    var accuracy: Double {
        guard totalTypedCharacters > 0 else { return 0 }
        return Double(correctCharacters) / Double(totalTypedCharacters) * 100
    }

    var wordsPerMinute: Double {
        guard elapsedTime > 0 else { return 0 }
        let minutes = elapsedTime / 60.0
        let wordCount = Double(correctCharacters) / 5.0
        return wordCount / minutes
    }

    var progress: Double {
        guard !passageText.isEmpty else { return 0 }
        return Double(typedText.count) / Double(passageText.count)
    }

    func selectPassage(subject: TypingSubject?) {
        selectedSubject = subject
        let available: [TypingPassage]
        if let subject = subject {
            available = typingPassages.filter { $0.subject == subject }
        } else {
            available = typingPassages
        }
        currentPassage = available.randomElement()
        typedText = ""
        isStarted = false
        isFinished = false
        startTime = nil
        endTime = nil
        elapsedTime = 0
        isGameStarted = true
        stopTimer()
    }

    func handleInput(_ newText: String) {
        guard !isFinished else { return }

        // Limit input to passage length
        let limitedText = String(newText.prefix(passageText.count))
        typedText = limitedText

        if !isStarted && !limitedText.isEmpty {
            isStarted = true
            startTime = Date()
            startTimerLoop()
        }

        if limitedText.count >= passageText.count {
            finishTest()
        }
    }

    func startTimerLoop() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.startTime, !self.isFinished else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func finishTest() {
        isFinished = true
        endTime = Date()
        if let start = startTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
        stopTimer()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func restart() {
        selectPassage(subject: selectedSubject)
    }
}

// MARK: - Main View

struct TypingSpeedGame: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TypingSpeedViewModel()
    @State private var hapticTrigger = false
    @FocusState private var isTextFieldFocused: Bool
    @AppStorage("typingSpeedHighWPM") private var highWPM: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isGameStarted {
                subjectSelectionView
            } else if viewModel.isFinished {
                resultsView
            } else {
                typingView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Typing Speed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    hapticTrigger.toggle()
                    viewModel.stopTimer()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    // MARK: - Subject Selection

    private var subjectSelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)

                Text("Typing Speed Test")
                    .font(.title.bold())

                Text("Type educational passages as quickly and accurately as possible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a Subject")
                        .font(.headline)
                        .padding(.horizontal)

                    // Random option
                    Button {
                        hapticTrigger.toggle()
                        viewModel.selectPassage(subject: nil)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "shuffle")
                                .font(.title2)
                                .foregroundStyle(.pink)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Random")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("A surprise passage from any subject")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .padding(.horizontal)

                    ForEach(TypingSubject.allCases) { subject in
                        Button {
                            hapticTrigger.toggle()
                            viewModel.selectPassage(subject: subject)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: subject.icon)
                                    .font(.title2)
                                    .foregroundStyle(subject.color)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("\(typingPassages.filter { $0.subject == subject }.count) passages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                        .padding(.horizontal)
                    }
                }

                if highWPM > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Best: \(highWPM) WPM")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Typing View

    private var typingView: some View {
        VStack(spacing: 16) {
            // Stats bar
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.wordsPerMinute))")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    Text("WPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(Int(viewModel.accuracy))%")
                        .font(.title3.bold())
                        .foregroundStyle(viewModel.accuracy >= 90 ? .green : viewModel.accuracy >= 70 ? .orange : .red)
                    Text("Accuracy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(formatTime(viewModel.elapsedTime))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let passage = viewModel.currentPassage {
                    HStack(spacing: 4) {
                        Image(systemName: passage.subject.icon)
                            .font(.caption2)
                        Text(passage.subject.rawValue)
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(passage.subject.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(passage.subject.color.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progress, height: 6)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            // Title
            if let passage = viewModel.currentPassage {
                Text(passage.title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            // Passage display
            ScrollView {
                PassageTextView(characterStatuses: viewModel.characterStatuses)
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
            }
            .frame(maxHeight: 200)

            // Hidden text field for input
            TextField("Start typing...", text: Binding(
                get: { viewModel.typedText },
                set: { viewModel.handleInput($0) }
            ))
            .focused($isTextFieldFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body)
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .padding(.horizontal)
            .onAppear {
                isTextFieldFocused = true
            }

            if !viewModel.isStarted {
                Text("Start typing the passage above to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }

            Spacer()
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Performance icon
                Image(systemName: performanceIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(performanceColor)
                    .padding(.top, 40)

                Text(performanceTitle)
                    .font(.title.bold())

                Text(performanceMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Results card
                VStack(spacing: 16) {
                    HStack(spacing: 30) {
                        resultStat(
                            value: "\(Int(viewModel.wordsPerMinute))",
                            label: "WPM",
                            icon: "gauge.with.needle.fill",
                            color: .blue
                        )
                        resultStat(
                            value: "\(Int(viewModel.accuracy))%",
                            label: "Accuracy",
                            icon: "target",
                            color: viewModel.accuracy >= 90 ? .green : .orange
                        )
                        resultStat(
                            value: formatTime(viewModel.elapsedTime),
                            label: "Time",
                            icon: "timer",
                            color: .purple
                        )
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Characters Typed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.totalTypedCharacters)")
                                .font(.subheadline.bold())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Correct Characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.correctCharacters)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

                if let passage = viewModel.currentPassage {
                    HStack(spacing: 6) {
                        Image(systemName: passage.subject.icon)
                            .font(.caption)
                        Text("Passage: \(passage.title)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if Int(viewModel.wordsPerMinute) > highWPM {
                    Text("New Personal Best!")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                } else if highWPM > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Personal Best: \(highWPM) WPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        hapticTrigger.toggle()
                        saveHighScore()
                        viewModel.restart()
                        isTextFieldFocused = true
                    } label: {
                        Text("Try Again")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: .rect(cornerRadius: 16)
                            )
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        saveHighScore()
                        viewModel.isGameStarted = false
                        viewModel.stopTimer()
                    } label: {
                        Text("Choose New Passage")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue.opacity(0.1), in: .rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        saveHighScore()
                        dismiss()
                    } label: {
                        Text("Exit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            saveHighScore()
        }
    }

    // MARK: - Helpers

    private func resultStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func saveHighScore() {
        let wpm = Int(viewModel.wordsPerMinute)
        if wpm > highWPM {
            highWPM = wpm
        }
    }

    private var performanceIcon: String {
        let wpm = viewModel.wordsPerMinute
        if wpm >= 60 { return "bolt.fill" }
        if wpm >= 40 { return "hare.fill" }
        if wpm >= 20 { return "figure.walk" }
        return "tortoise.fill"
    }

    private var performanceColor: Color {
        let wpm = viewModel.wordsPerMinute
        if wpm >= 60 { return .yellow }
        if wpm >= 40 { return .green }
        if wpm >= 20 { return .blue }
        return .orange
    }

    private var performanceTitle: String {
        let wpm = viewModel.wordsPerMinute
        if wpm >= 60 { return "Lightning Fast!" }
        if wpm >= 40 { return "Great Speed!" }
        if wpm >= 20 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    private var performanceMessage: String {
        let wpm = viewModel.wordsPerMinute
        let acc = viewModel.accuracy
        if wpm >= 60 && acc >= 95 {
            return "Outstanding typing skills! You're among the fastest and most accurate."
        }
        if wpm >= 40 {
            return "You're typing well above average. Keep up the great work!"
        }
        if wpm >= 20 {
            return "You're making solid progress. Practice regularly to increase your speed."
        }
        return "Practice makes perfect. Try focusing on accuracy first, then speed will follow."
    }
}

// MARK: - Passage Text View

struct PassageTextView: View {
    let characterStatuses: [(Character, CharacterStatus)]

    var body: some View {
        let attributedChunks = buildChunks()

        WrappingHStack(chunks: attributedChunks)
    }

    private func buildChunks() -> [(String, CharacterStatus)] {
        guard !characterStatuses.isEmpty else { return [] }

        var chunks: [(String, CharacterStatus)] = []
        var currentChunk = String(characterStatuses[0].0)
        var currentStatus = characterStatuses[0].1

        for i in 1..<characterStatuses.count {
            let (char, status) = characterStatuses[i]
            if status == currentStatus {
                currentChunk.append(char)
            } else {
                chunks.append((currentChunk, currentStatus))
                currentChunk = String(char)
                currentStatus = status
            }
        }
        chunks.append((currentChunk, currentStatus))

        return chunks
    }
}

struct WrappingHStack: View {
    let chunks: [(String, CharacterStatus)]

    var body: some View {
        // Use a simple Text concatenation approach
        chunks.reduce(Text("")) { result, chunk in
            result + Text(chunk.0)
                .foregroundColor(colorForStatus(chunk.1))
                .font(.system(.body, design: .monospaced))
                .underline(chunk.1 == .current, color: .blue)
                .bold(chunk.1 == .current)
        }
        .lineSpacing(8)
    }

    private func colorForStatus(_ status: CharacterStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .correct: return .green
        case .incorrect: return .red
        case .current: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        TypingSpeedGame()
    }
}
