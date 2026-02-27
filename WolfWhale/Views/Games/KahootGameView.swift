import SwiftUI

// MARK: - Kahoot Game View

struct KahootGameView: View {
    @State private var engine = KahootGameEngine()
    @Environment(\.dismiss) private var dismiss

    // Animation state
    @State private var countdownScale: CGFloat = 0.1
    @State private var countdownOpacity: Double = 0
    @State private var selectedAnswerTrigger = false
    @State private var correctAnswerTrigger = false
    @State private var wrongAnswerTrigger = false
    @State private var showPointsAnimation = false
    @State private var pointsAnimationOffset: CGFloat = 0
    @State private var pointsAnimationOpacity: Double = 1
    @State private var celebrationParticles: [CelebrationParticle] = []

    // Kahoot purple
    private let kahootPurple = Color(red: 70 / 255, green: 23 / 255, blue: 143 / 255)

    var body: some View {
        ZStack {
            backgroundLayer
            phaseContent
        }
        .sensoryFeedback(.selection, trigger: selectedAnswerTrigger)
        .sensoryFeedback(.success, trigger: correctAnswerTrigger)
        .sensoryFeedback(.error, trigger: wrongAnswerTrigger)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: engine.phase)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        switch engine.phase {
        case .lobby:
            HolographicBackground()
        case .countdown, .question, .answerReveal, .leaderboard:
            kahootPurple.ignoresSafeArea()
        case .results:
            LinearGradient(
                colors: [kahootPurple, Theme.brandPurple, Theme.brandBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Phase Router

    @ViewBuilder
    private var phaseContent: some View {
        switch engine.phase {
        case .lobby:
            lobbyPhase
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .countdown:
            countdownPhase
                .transition(.opacity)
        case .question:
            questionPhase
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .answerReveal:
            answerRevealPhase
                .transition(.opacity)
        case .leaderboard:
            leaderboardPhase
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        case .results:
            resultsPhase
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - 1. Lobby Phase

    @ViewBuilder
    private var lobbyPhase: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.brandGradient)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5))

                    Text("Quiz Game")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.brandGradient)

                    Text("Choose a quiz pack to start playing!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Quiz pack grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(KahootQuizPack.samplePacks) { pack in
                        quizPackCard(pack)
                    }
                }
                .padding(.horizontal, 16)

                // Exit button
                Button {
                    dismiss()
                } label: {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func quizPackCard(_ pack: KahootQuizPack) -> some View {
        Button {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                engine.startGame(with: pack)
            }
        } label: {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: pack.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.2))
                    )

                // Title
                Text(pack.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Description
                Text(pack.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Footer info
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(pack.category)
                        .font(.caption2.bold())

                    Spacer()

                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption2)
                    Text("\(pack.questionCount) Qs")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(pack.color.gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Countdown Phase

    @ViewBuilder
    private var countdownPhase: some View {
        let packColor = engine.quizPack?.color ?? kahootPurple

        ZStack {
            packColor.ignoresSafeArea()

            VStack(spacing: 30) {
                if let pack = engine.quizPack {
                    Text("Question \(engine.currentQuestionIndex + 1) of \(pack.questionCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(engine.countdownValue > 0 ? "\(engine.countdownValue)" : "GO!")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(countdownScale)
                    .opacity(countdownOpacity)
                    .onChange(of: engine.countdownValue) { _, newValue in
                        countdownScale = 0.1
                        countdownOpacity = 0
                        withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                            countdownScale = 1.0
                            countdownOpacity = 1.0
                        }
                        // Fade out before next number
                        if newValue > 0 {
                            withAnimation(.easeIn(duration: 0.2).delay(0.6)) {
                                countdownOpacity = 0.3
                            }
                        }
                    }
                    .onAppear {
                        countdownScale = 0.1
                        countdownOpacity = 0
                        withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                            countdownScale = 1.0
                            countdownOpacity = 1.0
                        }
                    }

                if let pack = engine.quizPack {
                    Text(pack.title)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - 3. Question Phase

    @ViewBuilder
    private var questionPhase: some View {
        if let question = engine.currentQuestion {
            VStack(spacing: 0) {
                // Top bar: progress + score + streak
                questionTopBar

                ScrollView {
                    VStack(spacing: 20) {
                        // Timer ring
                        timerRing

                        // Question text
                        questionTextView(question)

                        // Answer grid
                        answerGrid(question)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var questionTopBar: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(
                            width: geometry.size.width * engine.progressFraction,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.3), value: engine.progressFraction)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Score and streak
            HStack {
                if let pack = engine.quizPack {
                    Text("Question \(engine.currentQuestionIndex + 1)/\(pack.questionCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Streak indicator
                if engine.playerResult.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .symbolEffect(.bounce, value: engine.playerResult.streak)
                        Text("\(engine.playerResult.streak)")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.3))
                    )
                }

                // Score
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(engine.playerResult.totalScore)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.3))
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var timerRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 8)

            // Timer ring
            Circle()
                .trim(from: 0, to: engine.timeFraction)
                .stroke(
                    timerColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.timeFraction)

            // Time remaining text
            Text("\(engine.timeRemaining)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: engine.timeRemaining)
        }
        .frame(width: 80, height: 80)
    }

    private var timerColor: Color {
        let fraction = engine.timeFraction
        if fraction > 0.5 {
            return .green
        } else if fraction > 0.25 {
            return .yellow
        } else {
            return .red
        }
    }

    private func questionTextView(_ question: KahootQuestion) -> some View {
        VStack(spacing: 12) {
            if let imageName = question.imageSystemName {
                Image(systemName: imageName)
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(question.questionText)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    private func answerGrid(_ question: KahootQuestion) -> some View {
        let answers = question.answers

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
                let style = index < kahootAnswerStyleOrder.count
                    ? kahootAnswerStyleOrder[index]
                    : kahootAnswerStyleOrder[0]
                answerButton(answer: answer, style: style)
            }
        }
    }

    private func answerButton(answer: KahootAnswer, style: KahootAnswerStyle) -> some View {
        let isSelected = engine.selectedAnswerId == answer.id
        let isDisabled = engine.selectedAnswerId != nil

        return Button {
            guard engine.selectedAnswerId == nil else { return }
            selectedAnswerTrigger.toggle()
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                engine.submitAnswer(answer.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: style.iconName)
                    .font(.title3.bold())
                    .frame(width: 28)

                Text(answer.text)
                    .font(.subheadline.bold())
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.color.opacity(isDisabled && !isSelected ? 0.4 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .white : .clear, lineWidth: 3)
            )
            .scaleEffect(isSelected ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.spring(duration: 0.2), value: isSelected)
    }

    // MARK: - 4. Answer Reveal Phase

    @ViewBuilder
    private var answerRevealPhase: some View {
        if let question = engine.currentQuestion {
            let wasCorrect = engine.selectedAnswerId.flatMap { selectedId in
                question.answers.first(where: { $0.id == selectedId })?.isCorrect
            } ?? false

            VStack(spacing: 0) {
                // Top bar carries over
                questionTopBar

                ScrollView {
                    VStack(spacing: 24) {
                        // Result banner
                        resultBanner(wasCorrect: wasCorrect)

                        // Question text
                        questionTextView(question)

                        // Revealed answers
                        revealedAnswerGrid(question)

                        // Points animation
                        if wasCorrect && showPointsAnimation {
                            pointsPopup
                        }

                        // Next button
                        Button {
                            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                                showPointsAnimation = false
                                if engine.isLastQuestion {
                                    engine.showLeaderboard()
                                } else {
                                    engine.nextQuestion()
                                }
                            }
                        } label: {
                            Text(engine.isLastQuestion ? "See Results" : "Next Question")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Theme.brandBlue)
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .onAppear {
                if wasCorrect {
                    correctAnswerTrigger.toggle()
                    showPointsAnimation = true
                    pointsAnimationOffset = 0
                    pointsAnimationOpacity = 1
                    withAnimation(.easeOut(duration: 1.5)) {
                        pointsAnimationOffset = -60
                    }
                    withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
                        pointsAnimationOpacity = 0
                    }
                } else {
                    wrongAnswerTrigger.toggle()
                }
            }
        }
    }

    private func resultBanner(wasCorrect: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(wasCorrect ? .green : .red)
                .symbolEffect(.bounce, value: wasCorrect)

            Text(wasCorrect ? "Correct!" : "Incorrect")
                .font(.title.bold())
                .foregroundStyle(.white)

            if wasCorrect && engine.playerResult.streak > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(engine.playerResult.streak) streak!")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var pointsPopup: some View {
        let lastPoints = max(100, engine.playerResult.totalScore > 0 ? 100 : 0)
        Text("+\(lastPoints) points!")
            .font(.title2.weight(.heavy))
            .foregroundStyle(.yellow)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .offset(y: pointsAnimationOffset)
            .opacity(pointsAnimationOpacity)
    }

    private func revealedAnswerGrid(_ question: KahootQuestion) -> some View {
        let answers = question.answers

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
                let style = index < kahootAnswerStyleOrder.count
                    ? kahootAnswerStyleOrder[index]
                    : kahootAnswerStyleOrder[0]
                let isSelected = engine.selectedAnswerId == answer.id
                let isCorrectAnswer = answer.isCorrect

                HStack(spacing: 10) {
                    Image(systemName: style.iconName)
                        .font(.title3.bold())
                        .frame(width: 28)

                    Text(answer.text)
                        .font(.subheadline.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if isCorrectAnswer {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    } else if isSelected && !isCorrectAnswer {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(revealColor(isCorrect: isCorrectAnswer, isSelected: isSelected))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .white : .clear, lineWidth: 3)
                )
                .opacity(isCorrectAnswer || isSelected ? 1.0 : 0.4)
            }
        }
    }

    private func revealColor(isCorrect: Bool, isSelected: Bool) -> Color {
        if isCorrect {
            return .green
        } else if isSelected {
            return .red
        } else {
            return .gray
        }
    }

    // MARK: - 5. Leaderboard Phase

    @ViewBuilder
    private var leaderboardPhase: some View {
        VStack(spacing: 32) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: 1)

                Text("Scoreboard")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Stats cards
            VStack(spacing: 16) {
                statRow(icon: "star.fill", label: "Score", value: "\(engine.playerResult.totalScore)", color: .yellow)
                statRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.playerResult.correctCount)", color: .green)
                statRow(icon: "xmark.circle.fill", label: "Incorrect", value: "\(engine.playerResult.incorrectCount)", color: .red)

                if engine.playerResult.streak > 0 {
                    statRow(icon: "flame.fill", label: "Current Streak", value: "\(engine.playerResult.streak)", color: .orange)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    if engine.isLastQuestion {
                        engine.showLeaderboard()
                    } else {
                        engine.nextQuestion()
                    }
                }
            } label: {
                Text("Continue")
                    .font(.headline.bold())
                    .foregroundStyle(kahootPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }

    // MARK: - 6. Results Phase

    @ViewBuilder
    private var resultsPhase: some View {
        let result = engine.playerResult
        let totalQuestions = (engine.quizPack?.questionCount ?? 1)
        let accuracy = totalQuestions > 0
            ? Double(result.correctCount) / Double(totalQuestions) * 100
            : 0
        let starCount = accuracy > 80 ? 3 : (accuracy >= 50 ? 2 : 1)

        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // Trophy / celebration
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.pulse, options: .repeating.speed(0.3))

                    Text("Quiz Complete!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    // Star rating
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { star in
                            Image(systemName: star <= starCount ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundStyle(star <= starCount ? .yellow : .white.opacity(0.3))
                                .symbolEffect(.bounce, value: star <= starCount)
                        }
                    }
                }

                // Score display
                VStack(spacing: 4) {
                    Text("Total Score")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("\(result.totalScore)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                // Stats grid
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        resultStatCard(
                            icon: "checkmark.circle.fill",
                            title: "Correct",
                            value: "\(result.correctCount)/\(totalQuestions)",
                            color: .green
                        )
                        resultStatCard(
                            icon: "percent",
                            title: "Accuracy",
                            value: "\(Int(accuracy))%",
                            color: Theme.brandBlue
                        )
                    }

                    HStack(spacing: 16) {
                        resultStatCard(
                            icon: "flame.fill",
                            title: "Best Streak",
                            value: "\(result.bestStreak)",
                            color: .orange
                        )
                        resultStatCard(
                            icon: "clock.fill",
                            title: "Avg Time",
                            value: String(format: "%.1fs", result.averageTime),
                            color: Theme.brandPurple
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            showPointsAnimation = false
                            engine.reset()
                        }
                    } label: {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                            .font(.headline.bold())
                            .foregroundStyle(kahootPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white)
                            )
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Exit")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(0.2))
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func resultStatCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}

// MARK: - Celebration Particle (for confetti-like effects)

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var rotation: Double
}

// MARK: - Answer Style Ordering

/// Provides the canonical Kahoot answer layout order: triangle, diamond, circle, square.
/// If KahootAnswerStyle already conforms to CaseIterable in the engine, this extension
/// is unused and can be removed.
private let kahootAnswerStyleOrder: [KahootAnswerStyle] = [
    .triangle, .diamond, .circle, .square
]

// MARK: - Preview

#Preview {
    KahootGameView()
}
