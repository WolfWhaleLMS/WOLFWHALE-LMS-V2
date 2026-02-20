import SwiftUI
import SpriteKit

// MARK: - Math Problem Model

struct MathProblem {
    enum Operation: CaseIterable {
        case addition, subtraction, multiplication

        var symbol: String {
            switch self {
            case .addition: return "+"
            case .subtraction: return "-"
            case .multiplication: return "x"
            }
        }
    }

    let operand1: Int
    let operand2: Int
    let operation: Operation
    let correctAnswer: Int
    let choices: [Int]

    static func generate(difficulty: Int) -> MathProblem {
        let operation = Operation.allCases.randomElement()!
        let maxValue = min(12, 5 + difficulty * 2)
        let operand1: Int
        let operand2: Int
        let answer: Int

        switch operation {
        case .addition:
            operand1 = Int.random(in: 1...maxValue)
            operand2 = Int.random(in: 1...maxValue)
            answer = operand1 + operand2
        case .subtraction:
            let a = Int.random(in: 2...maxValue)
            let b = Int.random(in: 1...(a - 1).clamped(to: 1...maxValue))
            operand1 = a
            operand2 = b
            answer = operand1 - operand2
        case .multiplication:
            operand1 = Int.random(in: 1...max(2, maxValue / 2))
            operand2 = Int.random(in: 1...max(2, maxValue / 2))
            answer = operand1 * operand2
        }

        var choicesSet: Set<Int> = [answer]
        while choicesSet.count < 3 {
            let offset = Int.random(in: 1...5) * (Bool.random() ? 1 : -1)
            let wrong = answer + offset
            if wrong != answer && wrong >= 0 {
                choicesSet.insert(wrong)
            }
        }

        return MathProblem(
            operand1: operand1,
            operand2: operand2,
            operation: operation,
            correctAnswer: answer,
            choices: Array(choicesSet).shuffled()
        )
    }

    var questionText: String {
        "\(operand1) \(operation.symbol) \(operand2) = ?"
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - SpriteKit Scene

class MathBlasterScene: SKScene {
    // Game state
    var score: Int = 0
    var lives: Int = 3
    var difficulty: Int = 1
    var problemsSolved: Int = 0
    var isGameOver: Bool = false
    var currentProblem: MathProblem?

    // Callbacks
    var onScoreChanged: ((Int) -> Void)?
    var onLivesChanged: ((Int) -> Void)?
    var onGameOver: ((Int) -> Void)?

    // Nodes
    private var problemNode: SKLabelNode?
    private var choiceNodes: [SKShapeNode] = []
    private var choiceLabelNodes: [SKLabelNode] = []
    private var livesNodes: [SKSpriteNode] = []
    private var scoreLabel: SKLabelNode?
    private var fallingContainer: SKNode?
    private var backgroundStars: [SKShapeNode] = []

    // Timing
    private var fallSpeed: TimeInterval = 6.0
    private var lastSpawnTime: TimeInterval = 0
    private var currentTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.08, blue: 0.18, alpha: 1.0)
        setupBackground()
        setupUI()
        spawnProblem()
    }

    // MARK: - Background

    private func setupBackground() {
        // Create starfield
        for _ in 0..<60 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.2...0.8)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            addChild(star)
            backgroundStars.append(star)

            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.3), duration: Double.random(in: 1.0...3.0)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.9), duration: Double.random(in: 1.0...3.0))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Score label at top-left
        let scoreLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLbl.fontSize = 20
        scoreLbl.fontColor = .white
        scoreLbl.horizontalAlignmentMode = .left
        scoreLbl.position = CGPoint(x: 20, y: size.height - 50)
        scoreLbl.text = "Score: 0"
        scoreLbl.zPosition = 100
        addChild(scoreLbl)
        scoreLabel = scoreLbl

        // Lives at top-right
        updateLivesDisplay()
    }

    private func updateLivesDisplay() {
        livesNodes.forEach { $0.removeFromParent() }
        livesNodes.removeAll()

        for i in 0..<lives {
            let heart = SKSpriteNode(color: .clear, size: CGSize(width: 24, height: 24))
            let label = SKLabelNode(text: "\u{2764}\u{FE0F}")
            label.fontSize = 20
            label.verticalAlignmentMode = .center
            heart.addChild(label)
            heart.position = CGPoint(
                x: size.width - 30 - CGFloat(i) * 30,
                y: size.height - 50
            )
            heart.zPosition = 100
            addChild(heart)
            livesNodes.append(heart)
        }
    }

    // MARK: - Problem Spawning

    private func spawnProblem() {
        guard !isGameOver else { return }

        // Clear old problem
        fallingContainer?.removeFromParent()
        choiceNodes.removeAll()
        choiceLabelNodes.removeAll()

        let problem = MathProblem.generate(difficulty: difficulty)
        currentProblem = problem

        // Create falling container
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height + 60)
        container.zPosition = 50

        // Problem background
        let bgWidth: CGFloat = 260
        let bgHeight: CGFloat = 60
        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight), cornerRadius: 16)
        bg.fillColor = SKColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 0.9)
        bg.strokeColor = SKColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0)
        bg.lineWidth = 2
        bg.glowWidth = 4
        container.addChild(bg)

        // Problem text
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 28
        label.fontColor = .white
        label.text = problem.questionText
        label.verticalAlignmentMode = .center
        container.addChild(label)
        problemNode = label

        addChild(container)
        fallingContainer = container

        // Fall action
        let fallDistance = size.height + 120
        let fallAction = SKAction.moveBy(x: 0, y: -fallDistance, duration: fallSpeed)
        let failAction = SKAction.run { [weak self] in
            self?.problemMissed()
        }
        container.run(SKAction.sequence([fallAction, failAction]))

        // Create choice buttons at the bottom
        spawnChoiceButtons(for: problem)
    }

    private func spawnChoiceButtons(for problem: MathProblem) {
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 50
        let spacing: CGFloat = 16
        let totalWidth = CGFloat(problem.choices.count) * buttonWidth + CGFloat(problem.choices.count - 1) * spacing
        let startX = (size.width - totalWidth) / 2 + buttonWidth / 2

        for (index, choice) in problem.choices.enumerated() {
            let x = startX + CGFloat(index) * (buttonWidth + spacing)
            let y: CGFloat = 60

            let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 14)
            let isCorrect = choice == problem.correctAnswer
            if isCorrect {
                button.fillColor = SKColor(red: 0.15, green: 0.5, blue: 0.3, alpha: 0.9)
                button.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
            } else {
                button.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.35, alpha: 0.9)
                button.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.6, alpha: 1.0)
            }
            button.lineWidth = 2
            button.position = CGPoint(x: x, y: y)
            button.zPosition = 80
            button.name = "choice_\(choice)"
            addChild(button)
            choiceNodes.append(button)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.fontSize = 24
            label.fontColor = .white
            label.text = "\(choice)"
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: x, y: y)
            label.zPosition = 81
            label.name = "choiceLabel_\(choice)"
            addChild(label)
            choiceLabelNodes.append(label)
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !isGameOver else { return }
        let location = touch.location(in: self)

        for node in choiceNodes {
            if node.contains(location) {
                let choiceValue = Int(node.name?.replacingOccurrences(of: "choice_", with: "") ?? "0") ?? 0
                handleChoice(choiceValue)
                return
            }
        }

        // Also check labels
        for node in choiceLabelNodes {
            if node.frame.insetBy(dx: -20, dy: -10).contains(location) {
                let choiceValue = Int(node.name?.replacingOccurrences(of: "choiceLabel_", with: "") ?? "0") ?? 0
                handleChoice(choiceValue)
                return
            }
        }
    }

    private func handleChoice(_ choice: Int) {
        guard let problem = currentProblem else { return }

        if choice == problem.correctAnswer {
            correctAnswer()
        } else {
            wrongAnswer()
        }
    }

    // MARK: - Answer Handling

    private func correctAnswer() {
        guard !isGameOver else { return }

        // Stop falling
        fallingContainer?.removeAllActions()

        // Score
        let pointsEarned = 10 * difficulty
        score += pointsEarned
        problemsSolved += 1
        scoreLabel?.text = "Score: \(score)"
        onScoreChanged?(score)

        // Increase difficulty every 5 problems
        if problemsSolved % 5 == 0 {
            difficulty += 1
            fallSpeed = max(2.5, fallSpeed - 0.3)
        }

        // Particle burst at the problem location
        if let containerPos = fallingContainer?.position {
            spawnCorrectParticles(at: containerPos)
        }

        // Flash effect on the problem
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.fallingContainer?.alpha = 0.3
            },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.fallingContainer?.alpha = 1.0
            },
            SKAction.wait(forDuration: 0.1),
        ])
        fallingContainer?.run(SKAction.sequence([
            SKAction.repeat(flash, count: 3),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.run { [weak self] in
                self?.clearAndSpawnNext()
            }
        ]))

        // Animate score label
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scoreLabel?.run(SKAction.sequence([scaleUp, scaleDown]))

        // Score popup
        if let pos = fallingContainer?.position {
            let popup = SKLabelNode(fontNamed: "AvenirNext-Bold")
            popup.fontSize = 22
            popup.fontColor = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0)
            popup.text = "+\(pointsEarned)"
            popup.position = CGPoint(x: pos.x + 50, y: pos.y)
            popup.zPosition = 90
            addChild(popup)

            let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
            let fadeOut = SKAction.fadeOut(withDuration: 0.8)
            popup.run(SKAction.sequence([
                SKAction.group([moveUp, fadeOut]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnCorrectParticles(at position: CGPoint) {
        let colors: [SKColor] = [
            SKColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1.0),
            SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
            SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0),
            SKColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1.0),
            SKColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0),
        ]

        for _ in 0..<20 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            particle.fillColor = colors.randomElement()!
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 70
            particle.glowWidth = 3
            addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 60...160)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let duration = Double.random(in: 0.4...0.8)

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: duration)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let scaleAction = SKAction.scale(to: 0.1, duration: duration)
            particle.run(SKAction.sequence([
                SKAction.group([moveAction, fadeAction, scaleAction]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func wrongAnswer() {
        guard !isGameOver else { return }

        lives -= 1
        updateLivesDisplay()
        onLivesChanged?(lives)

        // Screen shake
        let shakeRight = SKAction.moveBy(x: 8, y: 0, duration: 0.05)
        let shakeLeft = SKAction.moveBy(x: -16, y: 0, duration: 0.05)
        let shakeBack = SKAction.moveBy(x: 8, y: 0, duration: 0.05)
        let shake = SKAction.sequence([shakeRight, shakeLeft, shakeBack])
        scene?.run(SKAction.repeat(shake, count: 2))

        // Flash red on the falling container
        if let container = fallingContainer {
            for child in container.children {
                if let shape = child as? SKShapeNode {
                    let originalColor = shape.fillColor
                    shape.fillColor = SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.9)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shape.fillColor = originalColor
                    }
                }
            }
        }

        // Red particles
        if let pos = fallingContainer?.position {
            for _ in 0..<10 {
                let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
                particle.fillColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
                particle.strokeColor = .clear
                particle.position = pos
                particle.zPosition = 70
                addChild(particle)

                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 30...80)
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance

                particle.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                        SKAction.fadeOut(withDuration: 0.5)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }
        }

        if lives <= 0 {
            gameOverSequence()
        }
    }

    private func problemMissed() {
        guard !isGameOver else { return }

        lives -= 1
        updateLivesDisplay()
        onLivesChanged?(lives)

        if lives <= 0 {
            gameOverSequence()
        } else {
            clearAndSpawnNext()
        }
    }

    private func clearAndSpawnNext() {
        fallingContainer?.removeFromParent()
        choiceNodes.forEach { $0.removeFromParent() }
        choiceLabelNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
        choiceLabelNodes.removeAll()

        let wait = SKAction.wait(forDuration: 0.5)
        run(SKAction.sequence([wait, SKAction.run { [weak self] in
            self?.spawnProblem()
        }]))
    }

    // MARK: - Game Over

    private func gameOverSequence() {
        isGameOver = true
        fallingContainer?.removeAllActions()
        fallingContainer?.removeFromParent()
        choiceNodes.forEach { $0.removeFromParent() }
        choiceLabelNodes.forEach { $0.removeFromParent() }
        choiceNodes.removeAll()
        choiceLabelNodes.removeAll()

        onGameOver?(score)

        // Game over overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 200
        overlay.alpha = 0
        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))

        // Game over text
        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60)
        gameOverLabel.zPosition = 201
        gameOverLabel.alpha = 0
        addChild(gameOverLabel)
        gameOverLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        // Final score
        let finalScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        finalScoreLabel.fontSize = 28
        finalScoreLabel.fontColor = .white
        finalScoreLabel.text = "Final Score: \(score)"
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        finalScoreLabel.zPosition = 201
        finalScoreLabel.alpha = 0
        addChild(finalScoreLabel)
        finalScoreLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        // Problems solved
        let solvedLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        solvedLabel.fontSize = 18
        solvedLabel.fontColor = SKColor(red: 0.7, green: 0.7, blue: 0.9, alpha: 1.0)
        solvedLabel.text = "Problems Solved: \(problemsSolved)"
        solvedLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35)
        solvedLabel.zPosition = 201
        solvedLabel.alpha = 0
        addChild(solvedLabel)
        solvedLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeIn(withDuration: 0.3)
        ]))

        // Play again button
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 180, height: 50), cornerRadius: 25)
        buttonBg.fillColor = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        buttonBg.strokeColor = SKColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
        buttonBg.lineWidth = 2
        buttonBg.position = CGPoint(x: size.width / 2, y: size.height / 2 - 90)
        buttonBg.zPosition = 201
        buttonBg.name = "playAgain"
        buttonBg.alpha = 0
        addChild(buttonBg)

        let buttonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        buttonLabel.fontSize = 20
        buttonLabel.fontColor = .white
        buttonLabel.text = "Play Again"
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 90)
        buttonLabel.zPosition = 202
        buttonLabel.name = "playAgainLabel"
        buttonLabel.alpha = 0
        addChild(buttonLabel)

        let appear = SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeIn(withDuration: 0.3)
        ])
        buttonBg.run(appear)
        buttonLabel.run(appear)

        // Pulse animation on button
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        buttonBg.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.1),
            SKAction.repeatForever(pulse)
        ]))
    }

    func restartGame() {
        removeAllChildren()
        removeAllActions()
        backgroundStars.removeAll()
        choiceNodes.removeAll()
        choiceLabelNodes.removeAll()
        livesNodes.removeAll()

        score = 0
        lives = 3
        difficulty = 1
        problemsSolved = 0
        isGameOver = false
        currentProblem = nil
        fallSpeed = 6.0

        onScoreChanged?(0)
        onLivesChanged?(3)

        setupBackground()
        setupUI()
        spawnProblem()
    }

    override func update(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }
}

// MARK: - SwiftUI Wrapper

struct MathBlasterGame: View {
    @Environment(\.dismiss) private var dismiss
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var isGameOver: Bool = false
    @State private var finalScore: Int = 0
    @State private var hapticTrigger = false
    @AppStorage("mathBlasterHighScore") private var highScore: Int = 0

    @State private var scene: MathBlasterScene = {
        let scene = MathBlasterScene()
        scene.size = CGSize(width: 390, height: 600)
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    hapticTrigger.toggle()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Spacer()

                HStack(spacing: 16) {
                    Label("\(score)", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < lives ? "heart.fill" : "heart")
                                .foregroundStyle(index < lives ? .red : .gray)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.08, green: 0.08, blue: 0.18))

            // SpriteKit scene
            SpriteView(scene: scene)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.18))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            scene.onScoreChanged = { newScore in
                score = newScore
            }
            scene.onLivesChanged = { newLives in
                lives = newLives
            }
            scene.onGameOver = { final in
                finalScore = final
                isGameOver = true
                if final > highScore {
                    highScore = final
                }
            }
        }
        .overlay {
            if isGameOver {
                gameOverOverlay
            }
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 20) {
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(finalScore)")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(.white)
            }

            if finalScore >= highScore && finalScore > 0 {
                Text("New High Score!")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Best: \(highScore)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                hapticTrigger.toggle()
                isGameOver = false
                score = 0
                lives = 3
                scene.restartGame()
            } label: {
                Text("Play Again")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .rect(cornerRadius: 14)
                    )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .padding(.horizontal, 40)

            Button {
                hapticTrigger.toggle()
                dismiss()
            } label: {
                Text("Exit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(30)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 30)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

#Preview {
    NavigationStack {
        MathBlasterGame()
    }
}
