import SwiftUI

struct QuizView: View {
    let quiz: Quiz
    let viewModel: AppViewModel
    @State private var currentQuestion = 0
    @State private var selectedAnswers: [Int] = []
    @State private var isSubmitted = false
    @State private var score: Double = 0
    @State private var timeRemaining: Int
    @State private var timerActive = true
    @Environment(\.dismiss) private var dismiss

    init(quiz: Quiz, viewModel: AppViewModel) {
        self.quiz = quiz
        self.viewModel = viewModel
        _timeRemaining = State(initialValue: quiz.timeLimit * 60)
        _selectedAnswers = State(initialValue: Array(repeating: -1, count: quiz.questions.count))
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
    }

    private var timerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
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

    private var quizContent: some View {
        VStack(spacing: 20) {
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    questionCard
                    optionsSection
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
                Text("\(selectedAnswers.filter { $0 >= 0 }.count) answered")
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
        Text(quiz.questions[currentQuestion].text)
            .font(.title3.bold())
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var optionsSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(quiz.questions[currentQuestion].options.enumerated()), id: \.offset) { index, option in
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
                        in: .rect(cornerRadius: 12)
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
                .accessibilityHint(selectedAnswers[currentQuestion] == index ? "Selected" : "Double tap to select this answer")
            }
        }
    }

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
                .disabled(selectedAnswers.contains(-1))
            }
        }
        .padding()
    }

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
                    resultStat(label: "Correct", value: "\(Int(score / 100 * Double(quiz.questions.count)))/\(quiz.questions.count)", color: .green)
                    resultStat(label: "Time", value: timeString, color: .blue)
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
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func submitQuiz() {
        timerActive = false
        score = viewModel.submitQuiz(quiz, answers: selectedAnswers)
        withAnimation(.spring) { isSubmitted = true }
    }
}
