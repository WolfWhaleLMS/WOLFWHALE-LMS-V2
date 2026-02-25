import SwiftUI

// MARK: - Data Models

private enum FractionActivity: String, CaseIterable, Identifiable {
    case compare = "Compare"
    case simplify = "Simplify"
    case addSubtract = "Add & Subtract"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .compare: return "lessthan.circle.fill"
        case .simplify: return "arrow.down.right.and.arrow.up.left"
        case .addSubtract: return "plus.forwardslash.minus"
        }
    }

    var color: Color {
        switch self {
        case .compare: return .blue
        case .simplify: return .purple
        case .addSubtract: return .orange
        }
    }

    var description: String {
        switch self {
        case .compare: return "Which fraction is larger?"
        case .simplify: return "Reduce to simplest form"
        case .addSubtract: return "Add or subtract fractions"
        }
    }
}

private enum FractionDifficulty: Int, CaseIterable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var maxDenominator: Int {
        switch self {
        case .beginner: return 8
        case .intermediate: return 12
        case .advanced: return 20
        }
    }
}

private struct Fraction: Equatable, Hashable {
    var numerator: Int
    var denominator: Int

    var decimalValue: Double {
        guard denominator != 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    var isSimplified: Bool {
        gcd(abs(numerator), abs(denominator)) == 1
    }

    var simplified: Fraction {
        let g = gcd(abs(numerator), abs(denominator))
        guard g > 0 else { return self }
        return Fraction(numerator: numerator / g, denominator: denominator / g)
    }

    var display: String {
        "\(numerator)/\(denominator)"
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}

private struct FractionProblem: Identifiable {
    let id = UUID()
    let fractionA: Fraction
    let fractionB: Fraction?
    let operation: FractionOperation?
    let correctAnswer: FractionAnswer

    enum FractionOperation: String {
        case add = "+"
        case subtract = "-"
    }

    enum FractionAnswer: Equatable {
        case comparison(ComparisonResult)
        case fraction(Fraction)

        enum ComparisonResult {
            case left, right, equal
        }
    }
}

// MARK: - Problem Generator

private struct FractionProblemGenerator {
    static func generateComparison(difficulty: FractionDifficulty) -> FractionProblem {
        let maxDen = difficulty.maxDenominator
        let denA = Int.random(in: 2...maxDen)
        let numA = Int.random(in: 1..<denA)
        let denB = Int.random(in: 2...maxDen)
        let numB = Int.random(in: 1..<denB)

        let fracA = Fraction(numerator: numA, denominator: denA)
        let fracB = Fraction(numerator: numB, denominator: denB)

        let result: FractionProblem.FractionAnswer.ComparisonResult
        if fracA.decimalValue > fracB.decimalValue {
            result = .left
        } else if fracA.decimalValue < fracB.decimalValue {
            result = .right
        } else {
            result = .equal
        }

        return FractionProblem(
            fractionA: fracA,
            fractionB: fracB,
            operation: nil,
            correctAnswer: .comparison(result)
        )
    }

    static func generateSimplify(difficulty: FractionDifficulty) -> FractionProblem {
        let factors = [2, 3, 4, 5, 6]
        let factor = factors.randomElement() ?? 2
        let maxSimpleDen = max(3, difficulty.maxDenominator / factor)
        let simpleDen = Int.random(in: 2...maxSimpleDen)
        let simpleNum = Int.random(in: 1..<simpleDen)

        let frac = Fraction(numerator: simpleNum * factor, denominator: simpleDen * factor)
        let simplified = frac.simplified

        return FractionProblem(
            fractionA: frac,
            fractionB: nil,
            operation: nil,
            correctAnswer: .fraction(simplified)
        )
    }

    static func generateAddSubtract(difficulty: FractionDifficulty) -> FractionProblem {
        let maxDen = min(difficulty.maxDenominator, 12)
        let denA = Int.random(in: 2...maxDen)
        let denB = Int.random(in: 2...maxDen)
        let numA = Int.random(in: 1..<denA)
        let numB = Int.random(in: 1..<denB)

        let fracA = Fraction(numerator: numA, denominator: denA)
        let fracB = Fraction(numerator: numB, denominator: denB)

        let isAdd = Bool.random()
        let op: FractionProblem.FractionOperation = isAdd ? .add : .subtract

        let commonDen = lcm(denA, denB)
        let adjNumA = numA * (commonDen / denA)
        let adjNumB = numB * (commonDen / denB)

        let resultNum: Int
        if isAdd {
            resultNum = adjNumA + adjNumB
        } else {
            resultNum = adjNumA - adjNumB
        }

        let resultFrac = Fraction(numerator: resultNum, denominator: commonDen).simplified

        // If subtraction yields negative, regenerate as addition
        if resultNum < 0 {
            let addResult = adjNumA + adjNumB
            let addFrac = Fraction(numerator: addResult, denominator: commonDen).simplified
            return FractionProblem(
                fractionA: fracA,
                fractionB: fracB,
                operation: .add,
                correctAnswer: .fraction(addFrac)
            )
        }

        return FractionProblem(
            fractionA: fracA,
            fractionB: fracB,
            operation: op,
            correctAnswer: .fraction(resultFrac)
        )
    }

    private static func lcm(_ a: Int, _ b: Int) -> Int {
        abs(a * b) / gcd(a, b)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}

// MARK: - Main View

struct FractionBuilderView: View {
    @State private var selectedActivity: FractionActivity = .compare
    @State private var difficulty: FractionDifficulty = .beginner
    @State private var isPlaying: Bool = false
    @State private var currentProblem: FractionProblem = FractionProblemGenerator.generateComparison(difficulty: .beginner)
    @State private var score: Int = 0
    @State private var totalAttempted: Int = 0
    @State private var showResult: Bool = false
    @State private var wasCorrect: Bool = false
    @State private var hapticTrigger: Int = 0
    @State private var wrongHapticTrigger: Int = 0

    // Comparison answer
    @State private var selectedComparison: FractionProblem.FractionAnswer.ComparisonResult? = nil

    // Simplify answer
    @State private var simplifyNumerator: Double = 1
    @State private var simplifyDenominator: Double = 2

    // Add/Subtract answer
    @State private var answerNumerator: Double = 1
    @State private var answerDenominator: Double = 2

    // Visual mode
    @State private var showVisual: Bool = true

    var body: some View {
        ZStack {
            backgroundGradient

            if isPlaying {
                playingView
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                menuView
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            }
        }
        .navigationTitle("Fraction Builder")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .sensoryFeedback(.impact(weight: .heavy), trigger: wrongHapticTrigger)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [selectedActivity.color.opacity(0.12), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Menu View

    private var menuView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Fraction Builder")
                        .font(.largeTitle.bold())
                    Text("Master fractions visually")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Score Card
                if totalAttempted > 0 {
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.title.bold().monospacedDigit())
                                .foregroundStyle(.green)
                            Text("Correct")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 40)
                        VStack(spacing: 4) {
                            Text("\(totalAttempted)")
                                .font(.title.bold().monospacedDigit())
                            Text("Attempted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 40)
                        VStack(spacing: 4) {
                            let pct = totalAttempted > 0 ? Int(Double(score) / Double(totalAttempted) * 100) : 0
                            Text("\(pct)%")
                                .font(.title.bold().monospacedDigit())
                                .foregroundStyle(.blue)
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                // Activity Selection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Choose Activity", systemImage: "rectangle.stack.fill")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    ForEach(FractionActivity.allCases) { activity in
                        activityCard(activity)
                    }
                }

                // Difficulty
                VStack(alignment: .leading, spacing: 12) {
                    Label("Difficulty", systemImage: "speedometer")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    HStack(spacing: 10) {
                        ForEach(FractionDifficulty.allCases, id: \.rawValue) { diff in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    difficulty = diff
                                }
                                hapticTrigger += 1
                            } label: {
                                Text(diff.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(difficulty == diff ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        difficulty == diff ?
                                            AnyShapeStyle(LinearGradient(colors: [selectedActivity.color, selectedActivity.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                            AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                                        ,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Visual toggle
                Toggle(isOn: $showVisual) {
                    Label("Show Visual Representations", systemImage: "eye.fill")
                        .font(.subheadline)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Start
                Button {
                    startGame()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Start")
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [selectedActivity.color, selectedActivity.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func activityCard(_ activity: FractionActivity) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedActivity = activity
            }
            hapticTrigger += 1
        } label: {
            HStack(spacing: 14) {
                Image(systemName: activity.icon)
                    .font(.title2)
                    .foregroundStyle(activity.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(activity.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedActivity == activity {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(activity.color)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedActivity == activity ? activity.color.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedActivity == activity ? activity.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playing View

    private var playingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("\(score)/\(totalAttempted)")
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            isPlaying = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("End")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Activity-specific content
                switch selectedActivity {
                case .compare:
                    comparisonView
                case .simplify:
                    simplifyView
                case .addSubtract:
                    addSubtractView
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Comparison View

    private var comparisonView: some View {
        VStack(spacing: 20) {
            Text("Which fraction is larger?")
                .font(.title3.bold())
                .padding(.top, 8)

            if showVisual {
                HStack(spacing: 24) {
                    fractionBarVisual(fraction: currentProblem.fractionA, color: .blue)
                    Text("vs")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    if let fracB = currentProblem.fractionB {
                        fractionBarVisual(fraction: fracB, color: .orange)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            // Fraction display
            HStack(spacing: 40) {
                fractionDisplay(currentProblem.fractionA, label: "A", color: .blue)
                if let fracB = currentProblem.fractionB {
                    fractionDisplay(fracB, label: "B", color: .orange)
                }
            }

            // Answer buttons
            HStack(spacing: 12) {
                comparisonButton(label: "A is larger", icon: "arrow.left.circle.fill", result: .left, color: .blue)
                comparisonButton(label: "Equal", icon: "equal.circle.fill", result: .equal, color: .gray)
                comparisonButton(label: "B is larger", icon: "arrow.right.circle.fill", result: .right, color: .orange)
            }
            .padding(.horizontal)

            if showResult {
                resultFeedback
            }
        }
    }

    private func comparisonButton(label: String, icon: String, result: FractionProblem.FractionAnswer.ComparisonResult, color: Color) -> some View {
        Button {
            guard !showResult else { return }
            selectedComparison = result
            checkComparisonAnswer(result)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(buttonColorForComparison(result, color: color))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buttonBGForComparison(result, color: color), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(showResult)
    }

    private func buttonColorForComparison(_ result: FractionProblem.FractionAnswer.ComparisonResult, color: Color) -> Color {
        guard showResult, let selected = selectedComparison else { return color }
        if case .comparison(let correct) = currentProblem.correctAnswer {
            if result == correct { return .white }
            if result == selected && result != correct { return .white }
        }
        return color.opacity(0.4)
    }

    private func buttonBGForComparison(_ result: FractionProblem.FractionAnswer.ComparisonResult, color: Color) -> some ShapeStyle {
        guard showResult, let selected = selectedComparison else {
            return AnyShapeStyle(color.opacity(0.12))
        }
        if case .comparison(let correct) = currentProblem.correctAnswer {
            if result == correct { return AnyShapeStyle(Color.green) }
            if result == selected && result != correct { return AnyShapeStyle(Color.red) }
        }
        return AnyShapeStyle(color.opacity(0.05))
    }

    // MARK: - Simplify View

    private var simplifyView: some View {
        VStack(spacing: 20) {
            Text("Simplify this fraction")
                .font(.title3.bold())
                .padding(.top, 8)

            // Original fraction
            VStack(spacing: 8) {
                Text("Simplify")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                fractionDisplay(currentProblem.fractionA, label: "", color: .purple)
            }

            if showVisual {
                fractionCircleVisual(fraction: currentProblem.fractionA, color: .purple)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            }

            // Answer sliders
            VStack(spacing: 16) {
                Text("Your Answer")
                    .font(.headline)

                // Live preview
                fractionDisplay(
                    Fraction(numerator: Int(simplifyNumerator), denominator: max(1, Int(simplifyDenominator))),
                    label: "",
                    color: .green
                )

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Numerator: \(Int(simplifyNumerator))")
                            .font(.subheadline.monospacedDigit())
                        Slider(value: $simplifyNumerator, in: 1...Double(currentProblem.fractionA.numerator), step: 1)
                            .tint(.purple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Denominator: \(Int(simplifyDenominator))")
                            .font(.subheadline.monospacedDigit())
                        Slider(value: $simplifyDenominator, in: 1...Double(currentProblem.fractionA.denominator), step: 1)
                            .tint(.purple)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            // Submit
            if !showResult {
                Button {
                    checkSimplifyAnswer()
                } label: {
                    Text("Check Answer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .padding(.horizontal)
            }

            if showResult {
                resultFeedback
            }
        }
    }

    // MARK: - Add/Subtract View

    private var addSubtractView: some View {
        VStack(spacing: 20) {
            if let op = currentProblem.operation, let fracB = currentProblem.fractionB {
                Text("\(op == .add ? "Add" : "Subtract") these fractions")
                    .font(.title3.bold())
                    .padding(.top, 8)

                // Problem display
                HStack(spacing: 16) {
                    fractionDisplay(currentProblem.fractionA, label: "", color: .blue)
                    Text(op.rawValue)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    fractionDisplay(fracB, label: "", color: .orange)
                    Text("=")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                    Text("?")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                }

                if showVisual {
                    HStack(spacing: 20) {
                        fractionBarVisual(fraction: currentProblem.fractionA, color: .blue)
                        Text(op.rawValue)
                            .font(.title2.bold())
                        fractionBarVisual(fraction: fracB, color: .orange)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Answer input
                VStack(spacing: 16) {
                    Text("Your Answer (simplified)")
                        .font(.headline)

                    fractionDisplay(
                        Fraction(numerator: Int(answerNumerator), denominator: max(1, Int(answerDenominator))),
                        label: "",
                        color: .green
                    )

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Numerator: \(Int(answerNumerator))")
                                .font(.subheadline.monospacedDigit())
                            Slider(value: $answerNumerator, in: 0...50, step: 1)
                                .tint(.orange)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Denominator: \(Int(answerDenominator))")
                                .font(.subheadline.monospacedDigit())
                            Slider(value: $answerDenominator, in: 1...50, step: 1)
                                .tint(.orange)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }

                if !showResult {
                    Button {
                        checkAddSubtractAnswer()
                    } label: {
                        Text("Check Answer")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .padding(.horizontal)
                }

                if showResult {
                    resultFeedback
                }
            }
        }
    }

    // MARK: - Visual Components

    private func fractionDisplay(_ fraction: Fraction, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .padding(.bottom, 4)
            }
            Text("\(fraction.numerator)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Rectangle()
                .fill(color)
                .frame(width: 50, height: 3)
                .clipShape(Capsule())
            Text("\(fraction.denominator)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func fractionBarVisual(fraction: Fraction, color: Color) -> some View {
        VStack(spacing: 6) {
            // Bar representation
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(min(fraction.decimalValue, 1.0))))
                }
            }
            .frame(height: 28)

            // Segmented view
            HStack(spacing: 2) {
                ForEach(0..<fraction.denominator, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i < fraction.numerator ? color : color.opacity(0.15))
                        .frame(height: 20)
                }
            }

            Text(fraction.display)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(width: 100)
    }

    private func fractionCircleVisual(fraction: Fraction, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 120, height: 120)

            ForEach(0..<fraction.denominator, id: \.self) { i in
                PieSlice(
                    startAngle: .degrees(Double(i) / Double(fraction.denominator) * 360 - 90),
                    endAngle: .degrees(Double(i + 1) / Double(fraction.denominator) * 360 - 90)
                )
                .fill(i < fraction.numerator ? color : color.opacity(0.15))
                .frame(width: 120, height: 120)

                // Divider lines
                let angle = Double(i) / Double(fraction.denominator) * 360 - 90
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 1.5, height: 60)
                    .offset(y: -30)
                    .rotationEffect(.degrees(angle))
            }

            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: 120, height: 120)

            Text(fraction.display)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color, in: Capsule())
        }
    }

    // MARK: - Result Feedback

    private var resultFeedback: some View {
        VStack(spacing: 12) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(wasCorrect ? .green : .red)
                .symbolEffect(.bounce, value: showResult)

            Text(wasCorrect ? "Correct!" : "Not quite...")
                .font(.title3.bold())
                .foregroundStyle(wasCorrect ? .green : .red)

            if !wasCorrect {
                if case .fraction(let correct) = currentProblem.correctAnswer {
                    Text("The answer is \(correct.numerator)/\(correct.denominator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                nextProblem()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                    Text("Next Question")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [selectedActivity.color, selectedActivity.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Game Logic

    private func startGame() {
        score = 0
        totalAttempted = 0
        generateNewProblem()
        withAnimation(.spring(response: 0.4)) {
            isPlaying = true
        }
    }

    private func generateNewProblem() {
        showResult = false
        selectedComparison = nil
        switch selectedActivity {
        case .compare:
            currentProblem = FractionProblemGenerator.generateComparison(difficulty: difficulty)
        case .simplify:
            currentProblem = FractionProblemGenerator.generateSimplify(difficulty: difficulty)
            simplifyNumerator = Double(currentProblem.fractionA.numerator)
            simplifyDenominator = Double(currentProblem.fractionA.denominator)
        case .addSubtract:
            currentProblem = FractionProblemGenerator.generateAddSubtract(difficulty: difficulty)
            answerNumerator = 1
            answerDenominator = 2
        }
    }

    private func checkComparisonAnswer(_ result: FractionProblem.FractionAnswer.ComparisonResult) {
        totalAttempted += 1
        if case .comparison(let correct) = currentProblem.correctAnswer {
            wasCorrect = result == correct
        } else {
            wasCorrect = false
        }
        if wasCorrect {
            score += 1
            hapticTrigger += 1
        } else {
            wrongHapticTrigger += 1
        }
        withAnimation(.spring(response: 0.3)) {
            showResult = true
        }
    }

    private func checkSimplifyAnswer() {
        totalAttempted += 1
        let userAnswer = Fraction(numerator: Int(simplifyNumerator), denominator: max(1, Int(simplifyDenominator)))

        if case .fraction(let correct) = currentProblem.correctAnswer {
            // Accept if equivalent and simplified
            wasCorrect = userAnswer.numerator == correct.numerator && userAnswer.denominator == correct.denominator
        } else {
            wasCorrect = false
        }

        if wasCorrect {
            score += 1
            hapticTrigger += 1
        } else {
            wrongHapticTrigger += 1
        }
        withAnimation(.spring(response: 0.3)) {
            showResult = true
        }
    }

    private func checkAddSubtractAnswer() {
        totalAttempted += 1
        let userAnswer = Fraction(numerator: Int(answerNumerator), denominator: max(1, Int(answerDenominator)))
        let userSimplified = userAnswer.simplified

        if case .fraction(let correct) = currentProblem.correctAnswer {
            // Accept equivalent fractions (both reduced to simplest form)
            wasCorrect = userSimplified.numerator == correct.numerator && userSimplified.denominator == correct.denominator
        } else {
            wasCorrect = false
        }

        if wasCorrect {
            score += 1
            hapticTrigger += 1
        } else {
            wrongHapticTrigger += 1
        }
        withAnimation(.spring(response: 0.3)) {
            showResult = true
        }
    }

    private func nextProblem() {
        withAnimation(.spring(response: 0.3)) {
            generateNewProblem()
        }
    }
}

// MARK: - Pie Slice Shape

private struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FractionBuilderView()
    }
}
