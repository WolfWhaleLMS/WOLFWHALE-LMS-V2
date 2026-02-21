import SwiftUI

// MARK: - Models

struct TypingAttempt: Codable, Identifiable {
    let id: UUID
    let date: Date
    let wpm: Double
    let accuracy: Double
    let errors: Int
    let difficulty: String
}

struct TypingPrompt: Identifiable {
    let id = UUID()
    let text: String
    let difficulty: TypingDifficulty
}

enum TypingDifficulty: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "tortoise.fill"
        case .intermediate: return "hare.fill"
        case .advanced: return "bolt.fill"
        }
    }
}

// MARK: - Prompt Library (30+ prompts)

struct TypingPromptLibrary {
    static let beginnerPrompts: [String] = [
        "the quick brown fox",
        "maple leaf red gold",
        "snow falls on mountains",
        "hockey puck ice rink",
        "blue lake calm water",
        "wild moose tall trees",
        "cold winter warm fire",
        "bright stars dark night",
        "fresh bread warm soup",
        "green grass soft rain",
        "good morning sunshine"
    ]

    static let intermediatePrompts: [String] = [
        "Canada is the second largest country in the world by total area.",
        "The Rocky Mountains stretch across western Canada with stunning beauty.",
        "Ottawa is the capital city of Canada and is located in Ontario.",
        "The Canadian flag features a red maple leaf on a white background.",
        "Hockey is considered the national winter sport of Canada by many citizens.",
        "Niagara Falls is one of the most famous waterfalls in the entire world.",
        "The Trans-Canada Highway is one of the longest national highways on Earth.",
        "Poutine is a popular Canadian dish made with fries, cheese curds, and gravy.",
        "The Northern Lights can be seen from many places across northern Canada.",
        "Banff National Park was established in 1885 as Canada's first national park.",
        "The St. Lawrence River connects the Great Lakes to the Atlantic Ocean."
    ]

    static let advancedPrompts: [String] = [
        "In Anne of Green Gables, L.M. Montgomery wrote: \"Isn't it nice to think that tomorrow is a new day with no mistakes in it yet?\" This beloved Canadian novel has inspired readers worldwide since 1908.",
        "The Canadian Charter of Rights and Freedoms, enacted in 1982, guarantees fundamental rights including freedom of expression, the right to equality, and the protection of official language rights for English and French speakers.",
        "Margaret Atwood, one of Canada's most celebrated authors, once observed: \"A word after a word after a word is power.\" Her works, including 'The Handmaid's Tale' and 'Alias Grace,' have won numerous international literary prizes.",
        "Robertson Davies wrote in 'Fifth Business': \"The world is full of obvious things which nobody by any chance ever observes.\" His Deptford Trilogy remains a cornerstone of Canadian literary fiction, exploring myth and identity.",
        "Canada's boreal forest, stretching from Yukon to Newfoundland and Labrador, represents about 30% of the world's boreal zone. This vast ecosystem stores approximately 208 billion tonnes of carbon, making it crucial for global climate regulation.",
        "Pierre Elliott Trudeau, Canada's fifteenth Prime Minister, famously stated: \"The essential ingredient of politics is timing.\" His leadership from 1968 to 1984 (with a brief interruption) shaped modern Canadian identity and constitutional law.",
        "The Group of Seven, formed in 1920, revolutionized Canadian art by painting the rugged northern Ontario landscape in bold, vibrant colours. Tom Thomson, though he died before the group's formal establishment, was a key artistic influence.",
        "Lucy Maud Montgomery captured the spirit of Prince Edward Island when she wrote: \"You never know what peace is until you walk on the shores or in the fields or along the winding red roads of Prince Edward Island in a summer twilight.\"",
        "The construction of the Canadian Pacific Railway, completed on November 7, 1885, was a monumental engineering achievement. It connected eastern Canada to British Columbia, fulfilling a promise made when B.C. joined Confederation in 1871.",
        "Farley Mowat's 'Never Cry Wolf' challenged common misconceptions about Arctic wolves: \"We have doomed the wolf not for what it is, but for what we deliberately and mistakenly perceive it to be — the mythologized epitome of a savage, ruthless killer.\""
    ]

    static func prompts(for difficulty: TypingDifficulty) -> [TypingPrompt] {
        let texts: [String]
        switch difficulty {
        case .beginner: texts = beginnerPrompts
        case .intermediate: texts = intermediatePrompts
        case .advanced: texts = advancedPrompts
        }
        return texts.map { TypingPrompt(text: $0, difficulty: difficulty) }
    }
}

// MARK: - Main View

struct TypingTutorView: View {
    @State private var difficulty: TypingDifficulty = .beginner
    @State private var currentPrompt: TypingPrompt?
    @State private var userInput: String = ""
    @State private var isTyping = false
    @State private var isFinished = false
    @State private var startTime: Date?
    @State private var elapsedSeconds: Double = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var errorCount = 0
    @State private var showHistory = false
    @State private var hapticTrigger = false

    @AppStorage("typingHighScoreWPM") private var highScoreWPM: Double = 0
    @AppStorage("typingHighScoreAccuracy") private var highScoreAccuracy: Double = 0
    @AppStorage("typingAttempts") private var attemptsData: Data = Data()

    private var attempts: [TypingAttempt] {
        (try? JSONDecoder().decode([TypingAttempt].self, from: attemptsData)) ?? []
    }

    private var promptText: String {
        currentPrompt?.text ?? ""
    }

    private var currentWPM: Double {
        guard elapsedSeconds > 0 else { return 0 }
        let wordCount = Double(userInput.split(separator: " ").count)
        return (wordCount / elapsedSeconds) * 60
    }

    private var currentAccuracy: Double {
        guard !userInput.isEmpty else { return 100 }
        let promptChars = Array(promptText)
        let inputChars = Array(userInput)
        var correct = 0
        for i in 0..<min(inputChars.count, promptChars.count) {
            if inputChars[i] == promptChars[i] { correct += 1 }
        }
        return (Double(correct) / Double(inputChars.count)) * 100
    }

    private var currentErrors: Int {
        let promptChars = Array(promptText)
        let inputChars = Array(userInput)
        var errors = 0
        for i in 0..<min(inputChars.count, promptChars.count) {
            if inputChars[i] != promptChars[i] { errors += 1 }
        }
        return errors
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    difficultyPicker
                    highScoreCard
                    promptCard
                    if isTyping || isFinished {
                        statsBar
                    }
                    inputSection
                    if isFinished {
                        resultsCard
                    }
                    if !attempts.isEmpty {
                        historyButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Typing Tutor")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showHistory) {
                historySheet
            }
            .onAppear {
                pickNewPrompt()
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        }
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        HStack(spacing: 10) {
            ForEach(TypingDifficulty.allCases, id: \.self) { level in
                Button {
                    difficulty = level
                    resetSession()
                    pickNewPrompt()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: level.icon)
                            .font(.caption)
                        Text(level.rawValue)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        difficulty == level
                        ? AnyShapeStyle(level.color.opacity(0.2))
                        : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .foregroundStyle(difficulty == level ? level.color : .secondary)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(difficulty == level ? level.color.opacity(0.5) : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - High Score Card

    private var highScoreCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Best WPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f", highScoreWPM))
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Best Accuracy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", highScoreAccuracy))
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Attempts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(attempts.count)")
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Prompt Card

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundStyle(difficulty.color)
                Text("Type this:")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    resetSession()
                    pickNewPrompt()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            characterHighlightedText
                .padding()
                .background(
                    LinearGradient(
                        colors: [difficulty.color.opacity(0.05), difficulty.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 12)
                )
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var characterHighlightedText: some View {
        let promptChars = Array(promptText)
        let inputChars = Array(userInput)

        WrappingHStack(promptChars: promptChars, inputChars: inputChars)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(icon: "speedometer", label: "WPM", value: String(format: "%.0f", currentWPM), color: .blue)
            statItem(icon: "target", label: "Accuracy", value: String(format: "%.1f%%", currentAccuracy), color: .green)
            statItem(icon: "xmark.circle", label: "Errors", value: "\(currentErrors)", color: .red)
            statItem(icon: "timer", label: "Time", value: formatTime(elapsedSeconds), color: .orange)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("Start typing here...", text: $userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isTyping ? difficulty.color.opacity(0.5) : .clear,
                            lineWidth: 2
                        )
                )
                .disabled(isFinished)
                .onChange(of: userInput) { _, newValue in
                    handleInputChange(newValue)
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack(spacing: 12) {
                Button {
                    resetSession()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    resetSession()
                    pickNewPrompt()
                } label: {
                    Label("New Prompt", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [difficulty.color, difficulty.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 12)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title2.bold())

            HStack(spacing: 20) {
                resultBadge(title: "WPM", value: String(format: "%.0f", currentWPM), color: .blue)
                resultBadge(title: "Accuracy", value: String(format: "%.1f%%", currentAccuracy), color: .green)
                resultBadge(title: "Errors", value: "\(currentErrors)", color: .red)
            }

            if currentWPM > highScoreWPM {
                Text("New WPM Record!")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.yellow.opacity(0.15), in: Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.green.opacity(0.1), .blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 16)
        )
    }

    private func resultBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History Button

    private var historyButton: some View {
        Button {
            showHistory = true
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("View History & Progress")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - History Sheet

    private var historySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !attempts.isEmpty {
                        barChart
                    }
                    recentAttemptsList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showHistory = false }
                }
            }
        }
    }

    private var barChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WPM Over Time")
                .font(.headline)

            let recentAttempts = Array(attempts.suffix(10))
            let maxWPM = max(recentAttempts.map(\.wpm).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(recentAttempts.enumerated()), id: \.element.id) { index, attempt in
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", attempt.wpm))
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [colorForAccuracy(attempt.accuracy), colorForAccuracy(attempt.accuracy).opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(CGFloat(attempt.wpm / maxWPM) * 120, 8))

                        Text("\(index + 1)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var recentAttemptsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Attempts")
                .font(.headline)

            ForEach(attempts.suffix(20).reversed()) { attempt in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attempt.difficulty)
                            .font(.caption.bold())
                            .foregroundStyle(TypingDifficulty(rawValue: attempt.difficulty)?.color ?? .gray)
                        Text(attempt.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f WPM", attempt.wpm))
                            .font(.subheadline.bold().monospacedDigit())
                        Text(String(format: "%.1f%% accuracy", attempt.accuracy))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private func pickNewPrompt() {
        let prompts = TypingPromptLibrary.prompts(for: difficulty)
        currentPrompt = prompts.randomElement()
    }

    private func resetSession() {
        userInput = ""
        isTyping = false
        isFinished = false
        startTime = nil
        elapsedSeconds = 0
        timerTask?.cancel()
        timerTask = nil
    }

    private func handleInputChange(_ newValue: String) {
        if !isTyping && !newValue.isEmpty {
            isTyping = true
            startTime = Date()
            startTimer()
        }

        if newValue.count >= promptText.count && !promptText.isEmpty {
            finishSession()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && isTyping {
                try? await Task.sleep(for: .milliseconds(100))
                if let start = startTime {
                    elapsedSeconds = Date().timeIntervalSince(start)
                }
            }
        }
    }

    private func finishSession() {
        isTyping = false
        isFinished = true
        timerTask?.cancel()
        hapticTrigger.toggle()

        let attempt = TypingAttempt(
            id: UUID(),
            date: Date(),
            wpm: currentWPM,
            accuracy: currentAccuracy,
            errors: currentErrors,
            difficulty: difficulty.rawValue
        )

        var currentAttempts = attempts
        currentAttempts.append(attempt)
        if let data = try? JSONEncoder().encode(currentAttempts) {
            attemptsData = data
        }

        if currentWPM > highScoreWPM { highScoreWPM = currentWPM }
        if currentAccuracy > highScoreAccuracy { highScoreAccuracy = currentAccuracy }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func colorForAccuracy(_ accuracy: Double) -> Color {
        if accuracy >= 95 { return .green }
        if accuracy >= 80 { return .orange }
        return .red
    }
}

// MARK: - Wrapping HStack for Character Highlighting

private struct WrappingHStack: View {
    let promptChars: [Character]
    let inputChars: [Character]

    var body: some View {
        let attributed = buildAttributedString()
        Text(attributed)
            .font(.body.monospaced())
            .lineSpacing(6)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for (index, char) in promptChars.enumerated() {
            var attrChar = AttributedString(String(char))

            if index < inputChars.count {
                if inputChars[index] == char {
                    attrChar.foregroundColor = .green
                    attrChar.backgroundColor = Color.green.opacity(0.1)
                } else {
                    attrChar.foregroundColor = .red
                    attrChar.backgroundColor = Color.red.opacity(0.15)
                    attrChar.underlineStyle = .single
                }
            } else if index == inputChars.count {
                attrChar.backgroundColor = Color.blue.opacity(0.2)
                attrChar.foregroundColor = .primary
            } else {
                attrChar.foregroundColor = .secondary
            }

            result.append(attrChar)
        }

        return result
    }
}

// MARK: - Preview

#Preview {
    TypingTutorView()
}
