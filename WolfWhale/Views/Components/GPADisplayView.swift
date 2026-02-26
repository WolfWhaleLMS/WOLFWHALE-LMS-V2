import SwiftUI

struct GPADisplayView: View, Equatable {
    let gpa: Double
    let size: CGFloat

    static func == (lhs: GPADisplayView, rhs: GPADisplayView) -> Bool {
        lhs.gpa == rhs.gpa && lhs.size == rhs.size
    }

    init(gpa: Double, size: CGFloat = 120) {
        self.gpa = gpa
        self.size = size
    }

    private var gpaColor: Color {
        switch gpa {
        case 3.5...: return .green
        case 3.0..<3.5: return .blue
        case 2.5..<3.0: return .yellow
        case 2.0..<2.5: return .orange
        default: return .red
        }
    }

    private var letterGrade: String {
        let percentage = (gpa / 4.0) * 100
        switch percentage {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }

    private var standingText: String {
        switch gpa {
        case 3.5...: return "Dean's List"
        case 3.0..<3.5: return "Good Standing"
        case 2.5..<3.0: return "Satisfactory"
        case 2.0..<2.5: return "Fair"
        default: return "Needs Improvement"
        }
    }

    private var progress: Double {
        min(gpa / 4.0, 1.0)
    }

    private let ringLineWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(gpaColor.opacity(0.15), lineWidth: ringLineWidth)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        gpaColor.gradient,
                        style: StrokeStyle(
                            lineWidth: ringLineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text(letterGrade)
                        .font(.system(size: size * 0.12, weight: .semibold, design: .rounded))
                        .foregroundStyle(gpaColor)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: size, height: size)

            Text(standingText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GPA \(String(format: "%.2f", gpa)), \(letterGrade), \(standingText)")
        .accessibilityValue("\(Int(progress * 100)) percent of 4.0")
    }
}

// MARK: - Compact Variant

struct GPADisplayCompactView: View, Equatable {
    let gpa: Double

    static func == (lhs: GPADisplayCompactView, rhs: GPADisplayCompactView) -> Bool {
        lhs.gpa == rhs.gpa
    }

    private var gpaColor: Color {
        switch gpa {
        case 3.5...: return .green
        case 3.0..<3.5: return .blue
        case 2.5..<3.0: return .yellow
        case 2.0..<2.5: return .orange
        default: return .red
        }
    }

    private var progress: Double {
        min(gpa / 4.0, 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(gpaColor.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        gpaColor.gradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.1f", gpa))
                    .font(.caption.bold())
                    .contentTransition(.numericText())
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("GPA")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", gpa))
                    .font(.subheadline.bold())
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GPA \(String(format: "%.2f", gpa))")
        .accessibilityValue("\(Int(progress * 100)) percent of 4.0")
    }
}
