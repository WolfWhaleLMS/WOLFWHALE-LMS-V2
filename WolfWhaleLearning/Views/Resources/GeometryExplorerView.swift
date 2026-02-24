import SwiftUI

// MARK: - Data Models

private enum GeometryShape: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case rectangle = "Rectangle"
    case triangle = "Triangle"
    case trapezoid = "Trapezoid"
    case parallelogram = "Parallelogram"
    case sphere = "Sphere"
    case cylinder = "Cylinder"
    case cone = "Cone"
    case cube = "Cube"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .circle: return "circle.fill"
        case .rectangle: return "rectangle.fill"
        case .triangle: return "triangle.fill"
        case .trapezoid: return "trapezoid.and.line.vertical.fill"
        case .parallelogram: return "parallelogram.fill"
        case .sphere: return "globe"
        case .cylinder: return "cylinder.fill"
        case .cone: return "cone.fill"
        case .cube: return "cube.fill"
        }
    }

    var is3D: Bool {
        switch self {
        case .sphere, .cylinder, .cone, .cube: return true
        default: return false
        }
    }

    var color: Color {
        switch self {
        case .circle: return .blue
        case .rectangle: return .green
        case .triangle: return .orange
        case .trapezoid: return .purple
        case .parallelogram: return .pink
        case .sphere: return .cyan
        case .cylinder: return .indigo
        case .cone: return .red
        case .cube: return .teal
        }
    }

    var dimensionLabels: [String] {
        switch self {
        case .circle: return ["Radius"]
        case .rectangle: return ["Width", "Height"]
        case .triangle: return ["Base", "Height", "Side A", "Side B", "Side C"]
        case .trapezoid: return ["Top Base", "Bottom Base", "Height", "Side A", "Side B"]
        case .parallelogram: return ["Base", "Height", "Side"]
        case .sphere: return ["Radius"]
        case .cylinder: return ["Radius", "Height"]
        case .cone: return ["Radius", "Height"]
        case .cube: return ["Side Length"]
        }
    }

    var defaultDimensions: [Double] {
        switch self {
        case .circle: return [5]
        case .rectangle: return [8, 5]
        case .triangle: return [6, 4, 5, 5, 6]
        case .trapezoid: return [4, 8, 5, 4, 4]
        case .parallelogram: return [7, 4, 5]
        case .sphere: return [5]
        case .cylinder: return [4, 8]
        case .cone: return [4, 7]
        case .cube: return [5]
        }
    }

    var formulaStrings: [String] {
        switch self {
        case .circle:
            return ["Area = pi * r^2", "Circumference = 2 * pi * r"]
        case .rectangle:
            return ["Area = w * h", "Perimeter = 2(w + h)"]
        case .triangle:
            return ["Area = (1/2) * b * h", "Perimeter = a + b + c"]
        case .trapezoid:
            return ["Area = (1/2)(a + b) * h", "Perimeter = a + b + c + d"]
        case .parallelogram:
            return ["Area = b * h", "Perimeter = 2(b + s)"]
        case .sphere:
            return ["Volume = (4/3) * pi * r^3", "Surface Area = 4 * pi * r^2"]
        case .cylinder:
            return ["Volume = pi * r^2 * h", "Surface Area = 2*pi*r*(r + h)"]
        case .cone:
            return ["Volume = (1/3) * pi * r^2 * h", "Surface Area = pi*r*(r + slant)"]
        case .cube:
            return ["Volume = s^3", "Surface Area = 6 * s^2"]
        }
    }

    func calculate(dimensions: [Double]) -> [(label: String, value: Double)] {
        let d = dimensions
        switch self {
        case .circle:
            let r = d.count > 0 ? d[0] : 5
            return [
                ("Area", Double.pi * r * r),
                ("Circumference", 2 * Double.pi * r)
            ]
        case .rectangle:
            let w = d.count > 0 ? d[0] : 8
            let h = d.count > 1 ? d[1] : 5
            return [
                ("Area", w * h),
                ("Perimeter", 2 * (w + h))
            ]
        case .triangle:
            let b = d.count > 0 ? d[0] : 6
            let h = d.count > 1 ? d[1] : 4
            let a = d.count > 2 ? d[2] : 5
            let sideB = d.count > 3 ? d[3] : 5
            let c = d.count > 4 ? d[4] : 6
            return [
                ("Area", 0.5 * b * h),
                ("Perimeter", a + sideB + c)
            ]
        case .trapezoid:
            let topBase = d.count > 0 ? d[0] : 4
            let bottomBase = d.count > 1 ? d[1] : 8
            let h = d.count > 2 ? d[2] : 5
            let sideA = d.count > 3 ? d[3] : 4
            let sideB = d.count > 4 ? d[4] : 4
            return [
                ("Area", 0.5 * (topBase + bottomBase) * h),
                ("Perimeter", topBase + bottomBase + sideA + sideB)
            ]
        case .parallelogram:
            let b = d.count > 0 ? d[0] : 7
            let h = d.count > 1 ? d[1] : 4
            let s = d.count > 2 ? d[2] : 5
            return [
                ("Area", b * h),
                ("Perimeter", 2 * (b + s))
            ]
        case .sphere:
            let r = d.count > 0 ? d[0] : 5
            return [
                ("Volume", (4.0 / 3.0) * Double.pi * r * r * r),
                ("Surface Area", 4 * Double.pi * r * r)
            ]
        case .cylinder:
            let r = d.count > 0 ? d[0] : 4
            let h = d.count > 1 ? d[1] : 8
            return [
                ("Volume", Double.pi * r * r * h),
                ("Surface Area", 2 * Double.pi * r * (r + h))
            ]
        case .cone:
            let r = d.count > 0 ? d[0] : 4
            let h = d.count > 1 ? d[1] : 7
            let slant = sqrt(r * r + h * h)
            return [
                ("Volume", (1.0 / 3.0) * Double.pi * r * r * h),
                ("Surface Area", Double.pi * r * (r + slant)),
                ("Slant Height", slant)
            ]
        case .cube:
            let s = d.count > 0 ? d[0] : 5
            return [
                ("Volume", s * s * s),
                ("Surface Area", 6 * s * s)
            ]
        }
    }
}

private enum ExplorerMode: String, CaseIterable, Identifiable {
    case explorer = "Explorer"
    case quiz = "Quiz Mode"
    case reference = "Formula Reference"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .explorer: return "ruler.fill"
        case .quiz: return "questionmark.circle.fill"
        case .reference: return "book.fill"
        }
    }
}

private struct GeometryQuizProblem: Identifiable {
    let id = UUID()
    let shape: GeometryShape
    let dimensions: [Double]
    let questionLabel: String
    let correctAnswer: Double
    var choices: [Double]
}

// MARK: - Main View

struct GeometryExplorerView: View {
    @State private var selectedMode: ExplorerMode = .explorer
    @State private var selectedShape: GeometryShape = .circle
    @State private var dimensions: [Double] = GeometryShape.circle.defaultDimensions
    @State private var hapticTrigger: Int = 0
    @State private var wrongHapticTrigger: Int = 0

    // Quiz state
    @State private var quizProblem: GeometryQuizProblem? = nil
    @State private var quizScore: Int = 0
    @State private var quizTotal: Int = 0
    @State private var quizSelectedAnswer: Double? = nil
    @State private var quizShowResult: Bool = false
    @State private var quizWasCorrect: Bool = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Mode Picker
                Picker("Mode", selection: $selectedMode) {
                    ForEach(ExplorerMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedMode {
                case .explorer:
                    explorerView
                case .quiz:
                    quizView
                case .reference:
                    referenceView
                }
            }
        }
        .navigationTitle("Geometry Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .hapticFeedback(.impact(weight: .heavy), trigger: wrongHapticTrigger)
        .onChange(of: selectedShape) { _, newShape in
            dimensions = newShape.defaultDimensions
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [selectedShape.color.opacity(0.1), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Explorer View

    private var explorerView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Shape selector
                shapeSelector

                // Visual preview
                shapePreview(shape: selectedShape, dims: dimensions)
                    .frame(height: 200)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                // Dimension inputs
                dimensionInputs

                // Calculated results
                calculatedResults

                // Formula display
                formulaCard
            }
            .padding(.bottom, 32)
        }
    }

    private var shapeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(GeometryShape.allCases) { shape in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedShape = shape
                        }
                        hapticTrigger += 1
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: shape.icon)
                                .font(.title3)
                                .foregroundStyle(selectedShape == shape ? .white : shape.color)
                            Text(shape.rawValue)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(selectedShape == shape ? .white : .primary)
                            if shape.is3D {
                                Text("3D")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(selectedShape == shape ? .white.opacity(0.8) : shape.color.opacity(0.7))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .background(
                            selectedShape == shape ?
                                AnyShapeStyle(LinearGradient(colors: [shape.color, shape.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                            ,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Shape Preview

    @ViewBuilder
    private func shapePreview(shape: GeometryShape, dims: [Double]) -> some View {
        let color = shape.color
        switch shape {
        case .circle:
            let r = dims.count > 0 ? dims[0] : 5
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.4), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Circle()
                    .stroke(color, lineWidth: 3)
                // Radius line
                Rectangle()
                    .fill(color.opacity(0.6))
                    .frame(width: 60, height: 2)
                    .offset(x: 30)
                Text("r=\(formatNum(r))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: 30, y: -12)
            }
            .frame(width: 140, height: 140)

        case .rectangle:
            let w = dims.count > 0 ? dims[0] : 8
            let h = dims.count > 1 ? dims[1] : 5
            let ratio = w / max(h, 0.1)
            let drawW: CGFloat = min(180, 100 * CGFloat(ratio))
            let drawH: CGFloat = min(140, drawW / CGFloat(ratio))
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.4), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 3)
                // Width label
                Text("w=\(formatNum(w))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: drawH / 2 + 14)
                // Height label
                Text("h=\(formatNum(h))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: drawW / 2 + 20)
            }
            .frame(width: drawW, height: drawH)

        case .triangle:
            let b = dims.count > 0 ? dims[0] : 6
            let h = dims.count > 1 ? dims[1] : 4
            ZStack {
                TriangleShape()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.4), color.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    )
                TriangleShape()
                    .stroke(color, lineWidth: 3)
                Text("b=\(formatNum(b))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: 80)
                Text("h=\(formatNum(h))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: -70, y: 20)
            }
            .frame(width: 160, height: 140)

        case .trapezoid:
            let top = dims.count > 0 ? dims[0] : 4
            let bottom = dims.count > 1 ? dims[1] : 8
            let ht = dims.count > 2 ? dims[2] : 5
            ZStack {
                TrapezoidShape(topRatio: CGFloat(top / max(bottom, 0.1)))
                    .fill(
                        LinearGradient(colors: [color.opacity(0.4), color.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    )
                TrapezoidShape(topRatio: CGFloat(top / max(bottom, 0.1)))
                    .stroke(color, lineWidth: 3)
                Text("a=\(formatNum(top))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: -70)
                Text("b=\(formatNum(bottom))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: 70)
                Text("h=\(formatNum(ht))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: -85)
            }
            .frame(width: 180, height: 130)

        case .parallelogram:
            let b = dims.count > 0 ? dims[0] : 7
            let h = dims.count > 1 ? dims[1] : 4
            ZStack {
                ParallelogramShape()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.4), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                ParallelogramShape()
                    .stroke(color, lineWidth: 3)
                Text("b=\(formatNum(b))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: 70)
                Text("h=\(formatNum(h))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: -80)
            }
            .frame(width: 180, height: 120)

        case .sphere:
            let r = dims.count > 0 ? dims[0] : 5
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [color.opacity(0.1), color.opacity(0.4)], center: .init(x: 0.35, y: 0.35), startRadius: 10, endRadius: 80)
                    )
                Circle()
                    .stroke(color, lineWidth: 3)
                // Equator ellipse
                Ellipse()
                    .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .frame(width: 140, height: 40)
                Text("r=\(formatNum(r))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: 40, y: -10)
            }
            .frame(width: 140, height: 140)

        case .cylinder:
            let r = dims.count > 0 ? dims[0] : 4
            let h = dims.count > 1 ? dims[1] : 8
            ZStack {
                CylinderShape()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    )
                CylinderShape()
                    .stroke(color, lineWidth: 3)
                Text("r=\(formatNum(r))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: -75)
                Text("h=\(formatNum(h))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: 55)
            }
            .frame(width: 120, height: 160)

        case .cone:
            let r = dims.count > 0 ? dims[0] : 4
            let h = dims.count > 1 ? dims[1] : 7
            ZStack {
                ConeShape()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.1), color.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    )
                ConeShape()
                    .stroke(color, lineWidth: 3)
                Text("r=\(formatNum(r))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: 75)
                Text("h=\(formatNum(h))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(x: -60, y: 10)
            }
            .frame(width: 140, height: 160)

        case .cube:
            let s = dims.count > 0 ? dims[0] : 5
            ZStack {
                CubeShape()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                CubeShape()
                    .stroke(color, lineWidth: 3)
                Text("s=\(formatNum(s))")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .offset(y: 70)
            }
            .frame(width: 150, height: 150)
        }
    }

    // MARK: - Dimension Inputs

    private var dimensionInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Dimensions", systemImage: "ruler")
                .font(.headline)

            ForEach(Array(selectedShape.dimensionLabels.enumerated()), id: \.offset) { index, label in
                if index < dimensions.count {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatNum(dimensions[index]))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(selectedShape.color)
                        }
                        Slider(value: binding(for: index), in: 0.5...30, step: 0.5)
                            .tint(selectedShape.color)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func binding(for index: Int) -> Binding<Double> {
        Binding(
            get: { index < dimensions.count ? dimensions[index] : 1.0 },
            set: { newValue in
                while dimensions.count <= index {
                    dimensions.append(1.0)
                }
                dimensions[index] = newValue
            }
        )
    }

    // MARK: - Calculated Results

    private var calculatedResults: some View {
        let results = selectedShape.calculate(dimensions: dimensions)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Results", systemImage: "function")
                .font(.headline)

            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                HStack {
                    Text(result.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatNum(result.value))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(selectedShape.color)
                    if result.label == "Area" || result.label == "Surface Area" {
                        Text("sq units")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if result.label == "Volume" {
                        Text("cu units")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("units")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedShape.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Formulas", systemImage: "textformat.abc")
                .font(.headline)

            ForEach(Array(selectedShape.formulaStrings.enumerated()), id: \.offset) { _, formula in
                Text(formula)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(selectedShape.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Quiz View

    private var quizView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Score
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("\(quizScore)/\(quizTotal)")
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    Button {
                        generateQuizProblem()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("New Question")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedShape.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedShape.color.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                if let problem = quizProblem {
                    // Shape visual
                    shapePreview(shape: problem.shape, dims: problem.dimensions)
                        .frame(height: 180)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)

                    // Question
                    VStack(spacing: 8) {
                        Text("What is the \(problem.questionLabel)")
                            .font(.title3.bold())
                        Text("of this \(problem.shape.rawValue)?")
                            .font(.title3.bold())

                        // Show dimensions
                        HStack(spacing: 12) {
                            ForEach(Array(zip(problem.shape.dimensionLabels.prefix(problem.dimensions.count), problem.dimensions).enumerated()), id: \.offset) { _, pair in
                                Text("\(pair.0): \(formatNum(pair.1))")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(problem.shape.color.opacity(0.1), in: Capsule())
                            }
                        }
                    }

                    // Choices
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(problem.choices, id: \.self) { choice in
                            Button {
                                guard !quizShowResult else { return }
                                selectQuizAnswer(choice, correct: problem.correctAnswer)
                            } label: {
                                Text(formatNum(choice))
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundStyle(quizChoiceTextColor(choice, correct: problem.correctAnswer))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(quizChoiceBG(choice, correct: problem.correctAnswer), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .disabled(quizShowResult)
                        }
                    }
                    .padding(.horizontal)

                    if quizShowResult {
                        VStack(spacing: 10) {
                            Image(systemName: quizWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(quizWasCorrect ? .green : .red)
                                .symbolEffect(.bounce, value: quizShowResult)

                            Text(quizWasCorrect ? "Correct!" : "The answer is \(formatNum(problem.correctAnswer))")
                                .font(.headline)
                                .foregroundStyle(quizWasCorrect ? .green : .red)

                            Button {
                                generateQuizProblem()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right")
                                    Text("Next Question")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [problem.shape.color, problem.shape.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    // Initial state
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Geometry Quiz")
                            .font(.title2.bold())
                        Text("Test your knowledge of area, perimeter, and volume calculations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            generateQuizProblem()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Quiz")
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                        }
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.top, 32)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Reference View

    private var referenceView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 2D Shapes
                VStack(alignment: .leading, spacing: 12) {
                    Label("2D Shapes", systemImage: "square.on.circle")
                        .font(.title3.bold())
                        .padding(.horizontal)
                        .padding(.top, 16)

                    ForEach(GeometryShape.allCases.filter { !$0.is3D }) { shape in
                        referenceCard(shape: shape)
                    }
                }

                // 3D Shapes
                VStack(alignment: .leading, spacing: 12) {
                    Label("3D Shapes", systemImage: "cube")
                        .font(.title3.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ForEach(GeometryShape.allCases.filter { $0.is3D }) { shape in
                        referenceCard(shape: shape)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func referenceCard(shape: GeometryShape) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: shape.icon)
                    .font(.title2)
                    .foregroundStyle(shape.color)
                    .frame(width: 36)
                Text(shape.rawValue)
                    .font(.headline)
                Spacer()
                if shape.is3D {
                    Text("3D")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(shape.color, in: Capsule())
                }
            }

            ForEach(Array(shape.formulaStrings.enumerated()), id: \.offset) { _, formula in
                Text(formula)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.8))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(shape.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 4) {
                Text("Dimensions:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(shape.dimensionLabels.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Quiz Logic

    private func generateQuizProblem() {
        quizShowResult = false
        quizSelectedAnswer = nil

        guard let shape = GeometryShape.allCases.randomElement() else { return }
        let dims = shape.defaultDimensions.map { base in
            let variation = Double.random(in: 0.5...2.0)
            return (base * variation * 2).rounded() / 2 // round to 0.5
        }

        let results = shape.calculate(dimensions: dims)
        guard let result = results.first else { return }

        let correct = (result.value * 100).rounded() / 100

        var choices = Set<Double>()
        choices.insert(correct)
        var attempts = 0
        while choices.count < 4 && attempts < 100 {
            attempts += 1
            let offset = Double.random(in: -max(10, correct * 0.4)...max(10, correct * 0.4))
            let wrong = ((correct + offset) * 100).rounded() / 100
            if wrong > 0 && wrong != correct {
                choices.insert(wrong)
            }
        }
        // Fallback: fill remaining choices with simple offsets if loop exhausted
        var fallback = 1.0
        while choices.count < 4 {
            let candidate = ((correct + fallback) * 100).rounded() / 100
            if candidate > 0 && !choices.contains(candidate) {
                choices.insert(candidate)
            }
            fallback += 1.0
        }

        withAnimation(.spring(response: 0.3)) {
            quizProblem = GeometryQuizProblem(
                shape: shape,
                dimensions: dims,
                questionLabel: result.label,
                correctAnswer: correct,
                choices: Array(choices).sorted().shuffled()
            )
        }
    }

    private func selectQuizAnswer(_ choice: Double, correct: Double) {
        quizSelectedAnswer = choice
        quizTotal += 1
        quizWasCorrect = abs(choice - correct) < 0.01

        if quizWasCorrect {
            quizScore += 1
            hapticTrigger += 1
        } else {
            wrongHapticTrigger += 1
        }

        withAnimation(.spring(response: 0.3)) {
            quizShowResult = true
        }
    }

    private func quizChoiceTextColor(_ choice: Double, correct: Double) -> Color {
        guard quizShowResult else { return .primary }
        if abs(choice - correct) < 0.01 { return .white }
        if let selected = quizSelectedAnswer, abs(choice - selected) < 0.01 { return .white }
        return .primary.opacity(0.4)
    }

    private func quizChoiceBG(_ choice: Double, correct: Double) -> some ShapeStyle {
        guard quizShowResult else {
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        }
        if abs(choice - correct) < 0.01 {
            return AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if let selected = quizSelectedAnswer, abs(choice - selected) < 0.01, abs(choice - correct) > 0.01 {
            return AnyShapeStyle(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.4))
    }

    // MARK: - Helpers

    private func formatNum(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 100_000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Custom Shapes

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: rect.minX + 10, y: rect.maxY - 10))
        path.closeSubpath()
        return path
    }
}

private struct TrapezoidShape: Shape {
    var topRatio: CGFloat = 0.5

    var animatableData: CGFloat {
        get { topRatio }
        set { topRatio = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 10
        let topWidth = (rect.width - 2 * inset) * min(topRatio, 0.95)
        let topOffset = (rect.width - topWidth) / 2

        var path = Path()
        path.move(to: CGPoint(x: topOffset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: topOffset + topWidth, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.closeSubpath()
        return path
    }
}

private struct ParallelogramShape: Shape {
    func path(in rect: CGRect) -> Path {
        let offset: CGFloat = rect.width * 0.2
        let inset: CGFloat = 10

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + offset + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - offset - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.closeSubpath()
        return path
    }
}

private struct CylinderShape: Shape {
    func path(in rect: CGRect) -> Path {
        let ellipseH: CGFloat = rect.height * 0.12
        let bodyTop = rect.minY + ellipseH / 2
        let bodyBottom = rect.maxY - ellipseH / 2
        let insetX: CGFloat = 10

        var path = Path()
        // Top ellipse
        path.addEllipse(in: CGRect(x: rect.minX + insetX, y: rect.minY, width: rect.width - 2 * insetX, height: ellipseH))
        // Body
        path.move(to: CGPoint(x: rect.minX + insetX, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.minX + insetX, y: bodyBottom))
        // Bottom ellipse
        path.addArc(
            center: CGPoint(x: rect.midX, y: bodyBottom),
            radius: (rect.width - 2 * insetX) / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - insetX, y: bodyTop))
        return path
    }
}

private struct ConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let ellipseH: CGFloat = rect.height * 0.1
        let insetX: CGFloat = 15

        var path = Path()
        // Tip
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        // Right side
        path.addLine(to: CGPoint(x: rect.maxX - insetX, y: rect.maxY - ellipseH / 2))
        // Bottom ellipse
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY - ellipseH / 2),
            radius: (rect.width - 2 * insetX) / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct CubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height) * 0.55
        let offset: CGFloat = size * 0.35
        let cx = rect.midX
        let cy = rect.midY

        // Front face
        let frontBL = CGPoint(x: cx - size / 2, y: cy + size / 2)
        let frontBR = CGPoint(x: cx + size / 2, y: cy + size / 2)
        let frontTR = CGPoint(x: cx + size / 2, y: cy - size / 2)
        let frontTL = CGPoint(x: cx - size / 2, y: cy - size / 2)

        // Back face (offset)
        let backBR = CGPoint(x: frontBR.x + offset, y: frontBR.y - offset)
        let backTR = CGPoint(x: frontTR.x + offset, y: frontTR.y - offset)
        let backTL = CGPoint(x: frontTL.x + offset, y: frontTL.y - offset)

        var path = Path()
        // Front face
        path.move(to: frontBL)
        path.addLine(to: frontBR)
        path.addLine(to: frontTR)
        path.addLine(to: frontTL)
        path.closeSubpath()
        // Top face
        path.move(to: frontTL)
        path.addLine(to: frontTR)
        path.addLine(to: backTR)
        path.addLine(to: backTL)
        path.closeSubpath()
        // Right face
        path.move(to: frontBR)
        path.addLine(to: backBR)
        path.addLine(to: backTR)
        path.addLine(to: frontTR)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeometryExplorerView()
    }
}
